use crate::domain::{
    DnsAction, DnsCategory, DnsError, DnsProvider, ListSetting, ToggleableSetting,
};
use crate::providers::next_dns::config::YOU_TUBE_DOMAINS;

pub fn set_dns_settings(
    provider: &dyn DnsProvider,
    dns_action: DnsAction,
    allow_list: String,
    deny_list: String,
) -> Result<String, DnsError> {
    let mut summary = Vec::new();

    for setting in ToggleableSetting::ALL {
        let category = DnsCategory::Toggle(setting);

        let effective_action = match setting {
            ToggleableSetting::AdultContent
            | ToggleableSetting::BlockByPass
            | ToggleableSetting::SafeSearch => DnsAction::Enable,
            _ => dns_action,
        };

        match provider.update_setting(&category, &effective_action) {
            Ok(_) => summary.push(format!(
                "Successfully applied {:?} to {:?}",
                effective_action, category
            )),
            Err(e) => summary.push(format!(
                "Failed to apply {:?} to {:?}: {}",
                effective_action, category, e
            )),
        }
    }

    let lists = [
        ListSetting::AllowList(allow_list),
        ListSetting::DenyList(deny_list),
        ListSetting::YoutubeDomains(YOU_TUBE_DOMAINS.to_string()),
    ];

    for list in &lists {
        let category = DnsCategory::List(list.clone());

        let effective_action = match list {
            ListSetting::AllowList(_) | ListSetting::DenyList(_) => DnsAction::Add,
            ListSetting::YoutubeDomains(_) => match dns_action {
                DnsAction::Enable => DnsAction::Add,
                DnsAction::Disable => DnsAction::Remove,
                _ => dns_action,
            },
        };

        match provider.update_setting(&category, &effective_action) {
            Ok(_) => summary.push(format!(
                "Successfully applied {:?} to {:?}",
                effective_action, category
            )),
            Err(e) => summary.push(format!(
                "Failed to apply {:?} to {:?}: {}",
                effective_action, category, e
            )),
        }
    }

    Ok(summary.join("\n"))
}

