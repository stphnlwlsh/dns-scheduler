pub mod config;
pub mod domain;
pub mod handlers;
pub mod providers;

pub struct HeaderExtractor<'a>(pub &'a tiny_http::Request);

impl<'a> opentelemetry::propagation::Extractor for HeaderExtractor<'a> {
    fn get(&self, key: &str) -> Option<&str> {
        self.0
            .headers()
            .iter()
            .find(|h| {
                let field: &str = h.field.as_str().as_ref();
                field.eq_ignore_ascii_case(key)
            })
            .map(|h| h.value.as_ref())
    }

    fn keys(&self) -> Vec<&str> {
        self.0
            .headers()
            .iter()
            .map(|h| h.field.as_str().as_ref())
            .collect()
    }
}
