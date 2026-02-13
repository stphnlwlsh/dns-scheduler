// use axum::{Router, routing::get, serve};

use dns_scheduler::domain::{DnsCategory, DnsProvider, ToggleableSetting};

#[tokio::main]
async fn main() {
    // let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    // let addr = format!("0.0.0.0:{}", port);
    // let app = Router::new().route("/enable", get());
    // .route("/disable", get(handlers::disable::disable_dns_settings))
    // .route("/toggle", get(handlers::toggle::toggle_dns_settings));

    // let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    // println!("listening on {}", listener.local_addr().unwrap());

    // serve(listener, app).await.unwrap();

    let profile_id = std::env::var("NEXTDNS_PROFILE_ID").unwrap();

    let provider = dns_scheduler::providers::next_dns::client::NextDNSClient::new(profile_id)
        .expect("Failed to create DNS client");

    let category = DnsCategory::Toggle(ToggleableSetting::AdultContent);

    println!("Checking status for {category:?}...");

    match provider.get_status(&category).await {
        Ok(is_active) => println!("{category:?} active? {}", is_active),
        Err(e) => println!("Error: {e:?}"),
    }
}
