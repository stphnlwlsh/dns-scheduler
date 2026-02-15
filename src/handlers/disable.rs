use crate::domain::{DnsAction, DnsCategory, DnsError, DnsProvider};

pub fn disable_dns_settings(provider: &dyn DnsProvider) -> Result<String, DnsError> {
    let category = DnsCategory::Toggle(crate::domain::ToggleableSetting::SafeSearch);

    provider.update_setting(&category, &DnsAction::Disable)?;

    Ok(format!(
        "Successfully applied {:?} to {:?}",
        DnsAction::Disable,
        category
    ))
}
