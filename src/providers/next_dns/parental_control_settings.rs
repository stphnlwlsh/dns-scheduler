use serde::Deserialize;

use crate::domain::ToggleableSetting;

#[derive(Deserialize)]
pub struct NextDNSResponse {
    pub data: ParentalControlSettings,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ParentalControlSettings {
    pub services: Vec<NextDNSEntry>,
    pub categories: Vec<NextDNSEntry>,
    pub safe_search: bool,
    pub youtube_restricted_mode: bool,
    pub block_bypass: bool,
}

#[derive(Deserialize)]
pub struct NextDNSEntry {
    pub id: String,
    pub active: bool,
    pub recreation: Option<bool>,
}

impl ParentalControlSettings {
    pub fn is_active(&self, setting: ToggleableSetting) -> bool {
        match setting {
            ToggleableSetting::AdultContent | ToggleableSetting::SocialNetworks => {
                let target_id = setting.to_id();
                self.categories
                    .iter()
                    .find(|entry| entry.id == target_id)
                    .map(|entry| entry.active)
                    .unwrap_or(false)
            }
            ToggleableSetting::BlockByPass => self.block_bypass,
            ToggleableSetting::SafeSearch => self.safe_search,
            ToggleableSetting::PanicMode => todo!(),
            ToggleableSetting::Youtube => self.youtube_restricted_mode,
        }
    }
}
