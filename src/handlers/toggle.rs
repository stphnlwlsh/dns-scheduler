use crate::domain::{
    DnsAction, DnsCategory, DnsError, DnsProvider, DnsResponse, ToggleableSetting,
};
use tracing::{Span, instrument};
use tracing_opentelemetry::OpenTelemetrySpanExt;

#[instrument(skip(provider))]
pub fn toggle_dns_settings(provider: &dyn DnsProvider) -> Result<DnsResponse, DnsError> {
    let mut summary = Vec::new();

    for setting in ToggleableSetting::ALL {
        let category = DnsCategory::Toggle(setting);

        let is_active = provider.get_status(&category)?;

        let effective_action = if is_active {
            DnsAction::Disable
        } else {
            DnsAction::Enable
        };

        match provider.update_setting(&category, &effective_action) {
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
            "SUCCESS - all DNS settings toggled"
        );
    } else {
        tracing::warn!(
            successes = success_count,
            failures = failure_count,
            "PARTIAL SUCCESS - some DNS toggles failed"
        );
    }

    Ok(crate::domain::DnsResponse {
        message: summary.join("\n"),
        success_count,
        failure_count,
    })
}
