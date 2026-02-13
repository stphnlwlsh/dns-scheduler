use crate::domain::ToggleableSetting;

pub const NEXT_DNS_API_URL: &str = "https://api.nextdns.io";

impl ToggleableSetting {
    pub fn to_id(&self) -> &str {
        match self {
            Self::AdultContent => "porn",
            Self::SocialNetworks => "social-networks",
            _ => "",
        }
    }
}
