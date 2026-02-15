use crate::domain::{DnsAction, DnsCategory, DnsError, DnsProvider};

pub fn toggle_dns_settings(provider: &dyn DnsProvider) -> Result<String, DnsError> {
    let category = DnsCategory::Toggle(crate::domain::ToggleableSetting::SafeSearch);

    let is_active = provider.get_status(&category)?;

    let action = if is_active {
        DnsAction::Disable
    } else {
        DnsAction::Enable
    };

    provider.update_setting(&category, &action)?;

    Ok(format!(
        "Successfully toggled {:?} to {:?}",
        category, action
    ))
}
