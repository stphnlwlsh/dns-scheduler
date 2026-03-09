use crate::{
    config::{PANIC_DOMAINS, YOU_TUBE_DOMAINS},
    domain::{
        DnsAction, DnsCategory, DnsError, DnsProvider, DnsResponse, ListSetting, ToggleableSetting,
    },
};
use tracing::{Span, instrument};
use tracing_opentelemetry::OpenTelemetrySpanExt;

#[instrument(skip(provider))]
pub async fn set_dns_settings(
    provider: &impl DnsProvider,
    dns_action: DnsAction,
    allow_list: String,
    deny_list: String,
    profile_id_override: Option<String>,
) -> Result<DnsResponse, DnsError> {
    let mut summary = Vec::new();
    let profile_ref = profile_id_override.as_deref();

    for setting in ToggleableSetting::ALL {
        let category = DnsCategory::Toggle(setting);

        let effective_action = match dns_action {
            DnsAction::Panic => DnsAction::Enable,
            _ => match setting {
                ToggleableSetting::AdultContent
                | ToggleableSetting::BlockByPass
                | ToggleableSetting::SafeSearch => DnsAction::Enable,
                _ => dns_action,
            },
        };

        match provider
            .update_setting(&category, &effective_action, profile_ref)
            .await
        {
            Ok(_) => {
                Span::current().add_event(
                    "setting_update_success",
                    vec![
                        opentelemetry::KeyValue::new("category", format!("{:?}", category)),
                        opentelemetry::KeyValue::new("action", format!("{:?}", effective_action)),
                    ],
                );
                summary.push(format!(
                    "Successfully applied {:?} to {:?}",
                    effective_action, category
                ))
            }
            Err(e) => {
                tracing::error!(
                    category = ?category,
                    action = ?effective_action,
                    error = %e,
                    "FAILED - setting update"
                );

                summary.push(format!(
                    "Failed to apply {:?} to {:?}: {}",
                    effective_action, category, e
                ))
            }
        }
    }

    let lists = [
        ListSetting::AllowList(allow_list),
        ListSetting::DenyList(deny_list),
        ListSetting::YoutubeDomains(YOU_TUBE_DOMAINS.to_string()),
        ListSetting::PanicDomains(PANIC_DOMAINS.to_string()),
    ];

    for list in &lists {
        let category = DnsCategory::List(list.clone());

        let effective_action = match list {
            ListSetting::AllowList(_) | ListSetting::DenyList(_) => DnsAction::Add,
            ListSetting::YoutubeDomains(_) => match dns_action {
                DnsAction::Enable | DnsAction::Panic => DnsAction::Add,
                DnsAction::Disable => DnsAction::Remove,
                _ => dns_action,
            },
            ListSetting::PanicDomains(_) => match dns_action {
                DnsAction::Panic => DnsAction::Add,
                _ => DnsAction::Remove,
            },
        };

        match provider
            .update_setting(&category, &effective_action, profile_ref)
            .await
        {
            Ok(_) => {
                Span::current().add_event(
                    "setting_update_success",
                    vec![
                        opentelemetry::KeyValue::new("category", format!("{:?}", category)),
                        opentelemetry::KeyValue::new("action", format!("{:?}", effective_action)),
                    ],
                );
                summary.push(format!(
                    "Successfully applied {:?} to {:?}",
                    effective_action, category
                ))
            }
            Err(e) => {
                tracing::error!(
                    category = ?category,
                    action = ?effective_action,
                    error = %e,
                    "FAILED - setting update"
                );

                summary.push(format!(
                    "Failed to apply {:?} to {:?}: {}",
                    effective_action, category, e
                ))
            }
        }
    }

    let success_count = summary
        .iter()
        .filter(|s| s.to_uppercase().starts_with("SUCCESS"))
        .count();

    let failure_count = summary
        .iter()
        .filter(|s| s.to_uppercase().starts_with("FAILED"))
        .count();

    if failure_count == 0 {
        tracing::info!(
            successes = success_count,
            "SUCCESS - all DNS settings applied"
        );
    } else {
        tracing::warn!(
            successes = success_count,
            failures = failure_count,
            "PARTIAL SUCCESS - some DNS settings failed"
        );
    }

    Ok(DnsResponse {
        message: summary.join("\n"),
        success_count,
        failure_count,
    })
}
