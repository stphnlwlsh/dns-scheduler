use crate::domain::ToggleableSetting;

pub const NEXT_DNS_API_URL: &str = "https://api.nextdns.io";

impl ToggleableSetting {
    pub fn to_id(&self) -> &str {
        match self {
            Self::AdultContent => "porn",
            Self::BlockByPass => "blockBypass",
            Self::PanicMode => "panic",
            Self::SafeSearch => "safeSearch",
            Self::SocialNetworks => "social-networks",
            Self::Youtube => "youtubeRestrictedMode",
        }
    }

    pub fn is_category(&self) -> bool {
        matches!(self, Self::AdultContent | Self::SocialNetworks)
    }
}
