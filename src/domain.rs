use std::future::Future;

#[derive(Clone, Copy, Debug)]
pub enum DnsAction {
    Add,
    Disable,
    Enable,
    Panic,
    Remove,
    Toggle,
}

#[derive(Clone, Debug)]
pub enum DnsCategory {
    Toggle(ToggleableSetting),
    List(ListSetting),
}

#[derive(Debug, Clone, Copy)]
pub enum ToggleableSetting {
    AdultContent,
    BlockByPass,
    SafeSearch,
    SocialNetworks,
    PanicMode,
    YoutubeRestrictedMode,
}

impl ToggleableSetting {
    pub const ALL: [Self; 5] = [
        Self::AdultContent,
        Self::BlockByPass,
        Self::SafeSearch,
        Self::SocialNetworks,
        Self::YoutubeRestrictedMode,
    ];
}

#[derive(Clone, Debug)]
pub enum ListSetting {
    AllowList(String),
    DenyList(String),
    PanicDomains(String),
    YoutubeDomains(String),
}

impl ListSetting {
    pub fn domains(&self) -> &str {
        match &self {
            Self::AllowList(d)
            | Self::DenyList(d)
            | Self::PanicDomains(d)
            | Self::YoutubeDomains(d) => d,
        }
    }
}

#[derive(thiserror::Error, Debug)]
pub enum DnsError {
    #[error("API error: {0}")]
    Api(String),

    #[error("Config error: {0}; {1}")]
    Config(String, String),

    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Feature not implemented: {0}")]
    NotImplemented(String),

    #[error("Failed to parse response: {0}, {1}")]
    Parse(String, String),
}

#[derive(Debug, Clone)]
pub struct DnsResponse {
    pub message: String,
    pub success_count: usize,
    pub failure_count: usize,
}

pub trait DnsProvider {
    fn update_setting(
        &self,
        category: &DnsCategory,
        action: &DnsAction,
        profile_id_override: Option<&str>,
    ) -> impl Future<Output = Result<(), DnsError>> + Send;

    fn get_status(
        &self,
        category: &DnsCategory,
        profile_id_override: Option<&str>,
    ) -> impl Future<Output = Result<bool, DnsError>> + Send;
}
