use crate::domain::{DnsAction, DnsCategory, DnsError, DnsProvider};
use crate::providers::next_dns::config::NEXT_DNS_API_URL;

pub struct NextDNSClient {
    api_key: String,
    profile_ids: Vec<String>,
    client: reqwest::blocking::Client,
}

impl NextDNSClient {
    pub fn new() -> Result<Self, String> {
        let api_key = std::env::var("NEXTDNS_API_KEY").unwrap_or_else(|_| "".to_string());

        let mut profile_ids: Vec<String> = Vec::new();

        for i in 0..2 {
            let profile_id = std::env::var(format!("NEXTDNS_PROFILE_ID_{}", i))
                .unwrap_or_else(|_| "".to_string());

            profile_ids.push(profile_id);
        }

        let client = reqwest::blocking::Client::new();

        if api_key.trim().is_empty() {
            return Err("API Key cannot be empty".to_string());
        }
        if profile_ids.is_empty() {
            return Err("Must have at least one profile id".to_string());
        }
        Ok(Self {
            api_key,
            profile_ids,
            client,
        })
    }
}

impl DnsProvider for NextDNSClient {
    fn update_setting(&self, category: &DnsCategory, action: &DnsAction) -> Result<(), DnsError> {
        let profile_id = self
            .profile_ids
            .first()
            .expect("Must have at least one profile id");
        let active = matches!(action, DnsAction::Enable);

        match category {
            DnsCategory::Toggle(setting) => {
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
                    .send()?;
            }
            _ => {
                return Err(DnsError::NotImplemented(
                    "Setting type not supported".to_string(),
                ));
            }
        }
        Ok(())
    }

    fn get_status(&self, category: &DnsCategory) -> Result<bool, DnsError> {
        let url = format!(
            "{}/profiles/{}/parentalControl",
            NEXT_DNS_API_URL,
            self.profile_ids.first().expect("Profile ID should exist")
        );

        let response = self
            .client
            .get(url)
            .header("x-api-key", &self.api_key)
            .send()?;

        let text = response.text()?;

        let response: super::parental_control_settings::NextDNSResponse =
            serde_json::from_str(&text).map_err(|e| DnsError::Parse(e.to_string(), text))?;

        let settings = response.data;

        match category {
            DnsCategory::Toggle(setting) => Ok(settings.is_active(*setting)),
            DnsCategory::List(_, _) => Err(DnsError::NotImplemented(
                "Status check for List settings (Deny/Allow) not implemented yet".to_string(),
            )),
        }
    }
}
