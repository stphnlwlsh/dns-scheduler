use async_trait::async_trait;

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

#[async_trait]
pub trait DnsProvider {
    async fn update_setting(
        &self,
        category: &DnsCategory,
        action: &DnsAction,
    ) -> Result<(), String>;

    async fn get_status(&self, category: &DnsCategory) -> Result<bool, String>;
}
