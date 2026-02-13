use crate::domain::{DnsAction, DnsCategory, DnsProvider};
use async_trait::async_trait;

pub struct NextDNSClient {
    api_key: String,
    pub profile_id: String,
    client: reqwest::Client,
}

impl NextDNSClient {
    pub fn new(profile_id: impl Into<String>) -> Result<Self, String> {
        let api_key = std::env::var("NEXTDNS_API_KEY").unwrap_or_else(|_| "".to_string());
        let profile_id = profile_id.into();
        let client = reqwest::Client::new();

        if api_key.trim().is_empty() {
            return Err("API Key cannot be empty".to_string());
        }
        if profile_id.trim().is_empty() {
            return Err("Profile ID cannot be empty".to_string());
        }
        Ok(Self {
            api_key,
            profile_id,
            client,
        })
    }
}

#[async_trait]
impl DnsProvider for NextDNSClient {
    async fn update_setting(
        &self,
        category: &DnsCategory,
        action: &DnsAction,
    ) -> Result<(), String> {
        todo!();
    }

    async fn get_status(&self, category: &DnsCategory) -> Result<bool, String> {
        // url := fmt.Sprintf("%s/profiles/%s/parentalControl", nextDNSAPIURL, c.profileID)
        let url = format!(
            "{}/profiles/{}/parentalControl",
            crate::providers::next_dns::config::NEXT_DNS_API_URL,
            self.profile_id
        );

        let response = self
            .client
            .get(url)
            .header("x-api-key", &self.api_key)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let text = response.text().await.map_err(|e| e.to_string())?;

        let response: super::parental_control_settings::NextDNSResponse =
            serde_json::from_str(&text).map_err(|e| format!("JSON error: {} at {}", e, text))?;

        let settings = response.data;

        match category {
            DnsCategory::Toggle(setting) => Ok(settings.is_active(*setting)),
            DnsCategory::List(_, _) => {
                Err("Status check for List settings (Deny/Allow) not implemented yet".to_string())
            }
        }
    }
}
