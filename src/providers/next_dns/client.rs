use crate::domain::{DnsAction, DnsCategory, DnsError, DnsProvider};
use crate::providers::next_dns::config::NEXT_DNS_API_URL;
use crate::providers::next_dns::parental_control_settings::{NextDNSEntry, NextDNSListResponse};
use std::collections::HashSet;

pub struct NextDNSClient {
    api_key: String,
    profile_ids: Vec<String>,
    client: reqwest::Client,
}

impl NextDNSClient {
    pub fn new() -> Result<Self, DnsError> {
        let api_key = parse_api_key()?;
        let profile_ids = parse_profile_ids()?;

        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()?;

        Ok(Self {
            api_key,
            profile_ids,
            client,
        })
    }

    #[tracing::instrument(skip(self), err)]
    async fn get_current_domain_list(
        &self,
        profile_id: &str,
        list_path: &str,
    ) -> Result<(String, Vec<NextDNSEntry>), DnsError> {
        let url = format!("{}/profiles/{}/{}", NEXT_DNS_API_URL, profile_id, list_path);
        let current_domain_list: NextDNSListResponse = self
            .client
            .get(&url)
            .header("x-api-key", &self.api_key)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        Ok((url, current_domain_list.data))
    }
}

fn parse_profile_ids() -> Result<Vec<String>, DnsError> {
    let profile_ids: Vec<String> = (0..2)
        .filter_map(|i| std::env::var(format!("NEXTDNS_PROFILE_ID_{}", i)).ok())
        .filter(|id| !id.trim().is_empty())
        .collect();

    if profile_ids.is_empty() {
        return Err(DnsError::Config(
            "Must have at least one profile id".to_string(),
            String::from("NEXTDNS_PROFILE_ID_{}"),
        ));
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
    #[tracing::instrument(skip(self), err)]
    async fn update_setting(
        &self,
        category: &DnsCategory,
        action: &DnsAction,
        profile_id_override: Option<&str>,
    ) -> Result<(), DnsError> {
        let profiles_to_update = if let Some(id) = profile_id_override {
            vec![id.to_string()]
        } else {
            self.profile_ids.clone()
        };

        if profiles_to_update.is_empty() {
            return Err(DnsError::Config(
                "No profile ids found to update".into(),
                String::from("NEXT_DNS_PROFILE_ID_"),
            ));
        }

        for profile_id in &profiles_to_update {
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
                        .send()
                        .await?
                        .error_for_status()?;
                }
                DnsCategory::List(setting) => {
                    let list_path = setting.to_id();

                    let (url, current_domains) =
                        self.get_current_domain_list(profile_id, list_path).await?;

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
                        .send()
                        .await?
                        .error_for_status()?;
                }
            }
        }
        Ok(())
    }

    #[tracing::instrument(skip(self), err)]
    async fn get_status(
        &self,
        category: &DnsCategory,
        profile_id_override: Option<&str>,
    ) -> Result<bool, DnsError> {
        let target_profile_id = if let Some(id) = profile_id_override {
            id
        } else {
            self.profile_ids.first().ok_or_else(|| {
                DnsError::Config(
                    "Must have at least one profile id".into(),
                    String::from("NEXT_DNS_PROFILE_ID_"),
                )
            })?
        };

        let url = format!(
            "{}/profiles/{}/parentalControl",
            NEXT_DNS_API_URL, target_profile_id
        );

        let response = self
            .client
            .get(url)
            .header("x-api-key", &self.api_key)
            .send()
            .await?
            .error_for_status()?;

        let text = response.text().await?;

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
