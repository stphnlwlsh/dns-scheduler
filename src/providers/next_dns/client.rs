use crate::domain::{DnsAction, DnsCategory, DnsError, DnsProvider};
use crate::providers::next_dns::config::NEXT_DNS_API_URL;
use crate::providers::next_dns::parental_control_settings::{NextDNSEntry, NextDNSListResponse};
use std::collections::HashSet;

pub struct NextDNSClient {
    api_key: String,
    profile_ids: Vec<String>,
    client: reqwest::blocking::Client,
}

impl NextDNSClient {
    pub fn new() -> Result<Self, DnsError> {
        let api_key = parse_api_key()?;

        let profile_ids = match parse_profile_ids() {
            Ok(value) => value,
            Err(value) => return value,
        };

        let client = reqwest::blocking::Client::new();

        Ok(Self {
            api_key,
            profile_ids,
            client,
        })
    }

    fn get_current_domain_list(
        &self,
        profile_id: &String,
        list_path: &str,
    ) -> Result<(String, Vec<NextDNSEntry>), DnsError> {
        let url = format!("{}/profiles/{}/{}", NEXT_DNS_API_URL, profile_id, list_path);
        let current_domain_list: NextDNSListResponse = self
            .client
            .get(&url)
            .header("x-api-key", &self.api_key)
            .send()?
            .error_for_status()?
            .json()?;

        Ok((url, current_domain_list.data))
    }
}

fn parse_profile_ids() -> Result<Vec<String>, Result<NextDNSClient, DnsError>> {
    let profile_ids: Vec<String> = (0..2)
        .filter_map(|i| std::env::var(format!("NEXTDNS_PROFILE_ID_{}", i)).ok())
        .filter(|id| !id.trim().is_empty())
        .collect();

    if profile_ids.is_empty() {
        return Err(Err(DnsError::Config(
            "Must have at least one profile id".to_string(),
            String::from("NEXTDNS_PROFILE_ID_{}"),
        )));
    }
    Ok(profile_ids)
}

fn parse_api_key() -> Result<String, DnsError> {
    let api_key = std::env::var("NEXTDNS_API_KEY")
        .map_err(|e| DnsError::Config(e.to_string(), String::from("NEXTDNS_API_KEY")))?
        .trim()
        .to_string();
    Ok(api_key)
}

impl DnsProvider for NextDNSClient {
    fn update_setting(&self, category: &DnsCategory, action: &DnsAction) -> Result<(), DnsError> {
        self.profile_ids.first().ok_or_else(|| {
            DnsError::Config(
                "Must have at least one profile id".into(),
                String::from("NEXT_DNS_PROFILE_ID_"),
            )
        })?;

        for profile_id in &self.profile_ids {
            match category {
                DnsCategory::Toggle(setting) => {
                    let active = matches!(action, DnsAction::Enable);
                    let id = setting.to_id();
                    let (url, body) = if setting.is_category() {
                        (
                            format!(
                                "{}/profiles/{}/parentalControl/categories/{}",
                                NEXT_DNS_API_URL, profile_id, id
                            ),
                            serde_json::json!({ "active": active}),
                        )
                    } else {
                        (
                            format!(
                                "{}/profiles/{}/parentalControl",
                                NEXT_DNS_API_URL, profile_id
                            ),
                            serde_json::json!({ id: active}),
                        )
                    };

                    self.client
                        .patch(url)
                        .header("x-api-key", &self.api_key)
                        .json(&body)
                        .send()?
                        .error_for_status()?;
                }
                DnsCategory::List(setting) => {
                    let list_path = setting.to_id();

                    let (url, current_domains) =
                        self.get_current_domain_list(profile_id, list_path)?;

                    let local_domains_csv = setting.domains();

                    let new_entries = extract_domains(true, local_domains_csv);
                    let local_ids: HashSet<String> =
                        new_entries.iter().map(|e| e.id.clone()).collect();

                    let mut final_list: Vec<NextDNSEntry> = current_domains
                        .into_iter()
                        .filter(|e| !local_ids.contains(&e.id))
                        .collect();

                    if matches!(action, DnsAction::Add) {
                        final_list.extend(new_entries);
                    }

                    let body = serde_json::json!(final_list);

                    self.client
                        .put(url)
                        .header("x-api-key", &self.api_key)
                        .json(&body)
                        .send()?
                        .error_for_status()?;
                }
            }
        }
        Ok(())
    }

    fn get_status(&self, category: &DnsCategory) -> Result<bool, DnsError> {
        let url = format!(
            "{}/profiles/{}/parentalControl",
            NEXT_DNS_API_URL,
            self.profile_ids.first().ok_or_else(|| DnsError::Config(
                "Must have at least one profile id".into(),
                String::from("NEXT_DNS_PROFILE_ID_")
            ))?
        );

        let response = self
            .client
            .get(url)
            .header("x-api-key", &self.api_key)
            .send()?
            .error_for_status()?;

        let text = response.text()?;

        let response: super::parental_control_settings::NextDNSResponse =
            serde_json::from_str(&text).map_err(|e| DnsError::Parse(e.to_string(), text))?;

        let settings = response.data;

        match category {
            DnsCategory::Toggle(setting) => Ok(settings.is_active(*setting)),
            DnsCategory::List(_) => Err(DnsError::NotImplemented(
                "Status check for List settings (Deny/Allow) not implemented yet".to_string(),
            )),
        }
    }
}

fn extract_domains(active: bool, domains: &str) -> Vec<NextDNSEntry> {
    domains
        .split(',')
        .map(|d| d.trim())
        .filter(|d| !d.is_empty())
        .map(|d| NextDNSEntry {
            id: d.to_string(),
            active,
            recreation: None,
        })
        .collect()
}
