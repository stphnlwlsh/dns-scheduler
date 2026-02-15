#[derive(Debug)]
pub enum DnsAction {
    Enable,
    Disable,
    Toggle,
    Add,
    Remove,
}

#[derive(Debug)]
pub enum DnsCategory {
    Toggle(ToggleableSetting),
    List(ListSetting, String),
}

#[derive(Debug, Clone, Copy)]
pub enum ToggleableSetting {
    AdultContent,
    BlockByPass,
    SafeSearch,
    SocialNetworks,
    PanicMode,
    Youtube,
}

#[derive(Debug)]
pub enum ListSetting {
    AllowList,
    DenyList,
}

#[derive(thiserror::Error, Debug)]
pub enum DnsError {
    #[error("API error: {0}")]
    Api(String),

    #[error("Config error: {0}")]
    Config(String),

    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Feature not implemented: {0}")]
    NotImplemented(String),

    #[error("Failed to parse response: {0}, {1}")]
    Parse(String, String),
}

pub trait DnsProvider {
    fn update_setting(&self, category: &DnsCategory, action: &DnsAction) -> Result<(), DnsError>;

    fn get_status(&self, category: &DnsCategory) -> Result<bool, DnsError>;
}
