use dns_scheduler::domain::{DnsAction, DnsResponse};
use opentelemetry::KeyValue;
use opentelemetry::global::{self};
use opentelemetry::trace::TracerProvider as _;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::Resource;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tokio::signal;
use tracing_opentelemetry::OpenTelemetrySpanExt;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

#[tokio::main]
async fn main() {
    init_tracing().await;

    let port = std::env::var("PORT").unwrap_or_else(|_| "3003".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let server = Arc::new(tiny_http::Server::http(addr).unwrap());

    let provider = match dns_scheduler::providers::next_dns::client::NextDNSClient::new() {
        Ok(p) => Arc::new(p),
        Err(e) => {
            eprintln!("CRITICAL ERROR: Failed to create DNS client: {}", e);
            std::process::exit(1);
        }
    };

    let deny_list = std::env::var("DOMAIN_DENY_LIST").unwrap_or_default();
    let allow_list = std::env::var("DOMAIN_ALLOW_LIST").unwrap_or_default();

    let shutdown = Arc::new(AtomicBool::new(false));
    let shutdown_clone = shutdown.clone();

    println!("Server listening on port {}", port);

    tokio::spawn(async move {
        signal::ctrl_c().await.expect("Failed to listen for ctrl-c");
        tracing::info!("Shutdown signal received, stopping server...");
        shutdown_clone.store(true, Ordering::SeqCst);
    });

    loop {
        if shutdown.load(Ordering::SeqCst) {
            break;
        }

        let request = match server.recv_timeout(std::time::Duration::from_millis(500)) {
            Ok(Some(rq)) => rq,
            Ok(None) => continue,
            Err(e) => {
                tracing::debug!("Server recv: {}", e);
                if shutdown.load(Ordering::SeqCst) {
                    break;
                }
                continue;
            }
        };

        let provider = Arc::clone(&provider);
        let allow_list = allow_list.clone();
        let deny_list = deny_list.clone();

        tokio::spawn(async move {
            let url = request.url().to_string();
            let path_parts: Vec<&str> = url.split('/').filter(|s| !s.is_empty()).collect();

            if path_parts.is_empty() {
                handle_request(request, async {
                    Err(dns_scheduler::domain::DnsError::NotImplemented(
                        "Root not implemented".to_string(),
                    ))
                })
                .await;
                return;
            }

            let action_path = path_parts[0];
            let profile_id = path_parts.get(1).map(|s| s.to_string());

            match (request.method(), action_path) {
                (&tiny_http::Method::Get, "health") => {
                    request
                        .respond(
                            tiny_http::Response::from_string("OK")
                                .with_status_code(200),
                        )
                        .unwrap();
                }
                (&tiny_http::Method::Get, "enable") => {
                    handle_request(request, async {
                        dns_scheduler::handlers::set::set_dns_settings(
                            provider.as_ref(),
                            DnsAction::Enable,
                            allow_list,
                            deny_list,
                            profile_id,
                        )
                        .await
                    })
                    .await
                }
                (&tiny_http::Method::Get, "disable") => {
                    handle_request(request, async {
                        dns_scheduler::handlers::set::set_dns_settings(
                            provider.as_ref(),
                            DnsAction::Disable,
                            allow_list,
                            deny_list,
                            profile_id,
                        )
                        .await
                    })
                    .await
                }
                (&tiny_http::Method::Get, "panic") => {
                    handle_request(request, async {
                        dns_scheduler::handlers::set::set_dns_settings(
                            provider.as_ref(),
                            DnsAction::Panic,
                            allow_list,
                            deny_list,
                            profile_id,
                        )
                        .await
                    })
                    .await
                }
                (&tiny_http::Method::Get, "toggle") => {
                    handle_request(request, async {
                        dns_scheduler::handlers::toggle::toggle_dns_settings(
                            provider.as_ref(),
                            profile_id,
                        )
                        .await
                    })
                    .await
                }
                _ => {
                    handle_request(request, async {
                        Err(dns_scheduler::domain::DnsError::NotImplemented(format!(
                            "Endpoint '{}' not implemented",
                            action_path
                        )))
                    })
                    .await
                }
            }
        });
    }

    tracing::info!("Server shutdown complete");
}

async fn handle_request<F>(request: tiny_http::Request, logic: F)
where
    F: std::future::Future<Output = Result<DnsResponse, dns_scheduler::domain::DnsError>>,
{
    let parent_cx = global::get_text_map_propagator(|propagator| {
        propagator.extract(&dns_scheduler::HeaderExtractor(&request))
    });

    let span = tracing::info_span!(
        "http_request",
        method = %request.method(),
        url = %request.url()
    );

    if let Err(e) = span.set_parent(parent_cx) {
        tracing::warn!(error = %e, "Failed to link to parent trace context; starting fresh trace");
    }

    let result = {
        let _guard = span.enter();
        logic.await
    };

    let response = match result {
        Ok(dns_response) => {
            if dns_response.failure_count > 0 {
                tracing::error!(
                    failures = dns_response.failure_count,
                    "PARTIAL FAILURE - request completed"
                );
                OpenTelemetrySpanExt::set_status(
                    &tracing::Span::current(),
                    opentelemetry::trace::Status::error("Partial failure detected"),
                );
            }
            tiny_http::Response::from_string(dns_response.message).with_status_code(200)
        }
        Err(err) => {
            tracing::error!(error = %err, "FAILED - request");
            let err_status_code = match err {
                dns_scheduler::domain::DnsError::NotImplemented(_) => 501,
                _ => 500,
            };
            tiny_http::Response::from_string(err.to_string()).with_status_code(err_status_code)
        }
    };

    request.respond(response).unwrap();
}

async fn init_tracing() {
    let env = std::env::var("ENVIRONMENT").unwrap_or_else(|_| "dev".to_string());

    let resource = Resource::builder()
        .with_attributes(vec![
            KeyValue::new("service.name", "dns-scheduler"),
            KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
            KeyValue::new("service.environment", env.clone()),
        ])
        .build();

    let sampler = opentelemetry_sdk::trace::Sampler::ParentBased(Box::new(
        opentelemetry_sdk::trace::Sampler::TraceIdRatioBased(0.50),
    ));

    let tracer_provider = if env == "prod" {
        let exporter = opentelemetry_otlp::SpanExporter::builder()
            .with_tonic()
            .with_endpoint("http://localhost:4317")
            .with_timeout(std::time::Duration::from_secs(2))
            .build()
            .expect("Failed to create trace exporter");

        opentelemetry_sdk::trace::SdkTracerProvider::builder()
            .with_resource(resource.clone())
            .with_sampler(sampler)
            .with_batch_exporter(exporter)
            .build()
    } else {
        let exporter = opentelemetry_stdout::SpanExporter::default();
        opentelemetry_sdk::trace::SdkTracerProvider::builder()
            .with_resource(resource.clone())
            .with_sampler(sampler)
            .with_simple_exporter(exporter)
            .build()
    };

    let logger_provider = if env == "prod" {
        let exporter = opentelemetry_otlp::LogExporter::builder()
            .with_tonic()
            .with_endpoint("http://localhost:4317")
            .with_timeout(std::time::Duration::from_secs(2))
            .build()
            .expect("Failed to create log exporter");

        opentelemetry_sdk::logs::SdkLoggerProvider::builder()
            .with_resource(resource.clone())
            .with_batch_exporter(exporter)
            .build()
    } else {
        opentelemetry_sdk::logs::SdkLoggerProvider::builder()
            .with_resource(resource.clone())
            .with_simple_exporter(opentelemetry_stdout::LogExporter::default())
            .build()
    };

    let tracer = tracer_provider.tracer("dns-scheduler");

    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));

    tracing_subscriber::registry()
        .with(filter)
        .with(
            opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge::new(
                &logger_provider,
            ),
        )
        .with(tracing_opentelemetry::layer().with_tracer(tracer))
        .init();

    global::set_text_map_propagator(opentelemetry_sdk::propagation::TraceContextPropagator::new());
    global::set_tracer_provider(tracer_provider);
}
