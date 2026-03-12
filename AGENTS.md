# Agent Guidelines for dns-scheduler

This document provides guidance for AI agents working on this codebase.

## Project Overview

- **Language:** Rust (2024 edition)
- **Framework:** tiny_http (minimal HTTP server)
- **Purpose:** DNS scheduling service for managing NextDNS settings
- **Deployment:** Google Cloud Run

## Build, Lint, and Test Commands

### Running the Application

```bash
# Development mode (uses .env_local.env)
cargo run

# With OTel collector
just up

# With specific environment
ENVIRONMENT=prod cargo run
```

### Code Quality

```bash
# Check code without building
cargo check

# Build the project
cargo build

# Run clippy for linting
cargo clippy -- -D warnings

# Format code
cargo fmt
```

### Testing

```bash
# Run all tests
cargo test

# Run a specific test
cargo test test_name

# Run tests with output
cargo test -- --nocapture
```

### Development Environment

```bash
# Enter Nix shell (local/dev)
nix develop

# Enter Nix shell (prod)
nix develop .#prod

# Using just (loads env files)
just run
just check
just up
just down
```

## Code Style Guidelines

### General Principles

- Use Rust 2024 edition
- Prefer async/await with tokio
- Use `thiserror` for error handling
- Use `tracing` for logging with OpenTelemetry
- Add `#[instrument]` attribute to all async functions in handlers and providers

### Imports and Organization

```rust
// Standard library imports first
use std::sync::Arc;

// External crate imports (alphabetically within group)
use opentelemetry::global::{self};
use opentelemetry::trace::TracerProvider as _;
use tokio::signal;

// Module imports
use dns_scheduler::domain::{DnsAction, DnsResponse};
```

### Naming Conventions

- **Types (structs, enums, traits):** PascalCase (`NextDNSClient`, `DnsAction`)
- **Variables and functions:** snake_case (`get_current_domain_list`, `profile_ids`)
- **Constants:** SCREAMING_SNAKE_CASE (`NEXT_DNS_API_URL`)
- **Files:** snake_case (`next_dns.rs`, `client.rs`)

### Error Handling

Use the `DnsError` enum from `domain.rs`:

```rust
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
```

- Return `Result<T, DnsError>` from public async functions
- Use the `?` operator for error propagation
- Use `map_err` or `Context` pattern for custom error messages

### Traits and Abstractions

Follow the `DnsProvider` trait pattern:

```rust
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
```

### Logging and Tracing

Always add instrumentation to async functions:

```rust
#[tracing::instrument(skip(provider), err)]
pub async fn set_dns_settings(
    provider: &impl DnsProvider,
    // ... other params
) -> Result<DnsResponse, DnsError> {
    // Function body
}
```

Use structured logging:

```rust
tracing::info!(successes = success_count, "SUCCESS - all DNS settings applied");
tracing::error!(error = %err, "FAILED - request");
tracing::warn!(successes = success_count, failures = failure_count, "PARTIAL SUCCESS");
```

Add span events for detailed tracking:

```rust
Span::current().add_event(
    "setting_update_success",
    vec![
        opentelemetry::KeyValue::new("category", format!("{:?}", category)),
    ],
);
```

### Enums

Use `#[derive(Clone, Debug)]` or `#[derive(Debug, Clone, Copy)]` as appropriate:

```rust
#[derive(Clone, Copy, Debug)]
pub enum DnsAction {
    Add,
    Disable,
    Enable,
}

#[derive(Debug, Clone)]
pub enum ToggleableSetting {
    AdultContent,
    SafeSearch,
}
```

### HTTP Client Usage

Use reqwest with timeouts:

```rust
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(10))
    .build()?;
```

Handle HTTP errors properly:

```rust
self.client
    .get(&url)
    .header("x-api-key", &self.api_key)
    .send()
    await?
    .error_for_status()?
    .json()
    .await?;
```

### Configuration

- Environment variables for configuration
- Constants in `config.rs` for API URLs and default values
- Use `std::env::var()` with `unwrap_or_else` for defaults

### Testing Guidelines

- Place tests in `tests/` directory or use `#[cfg(test)]` modules
- Use `#[tokio::test]` for async tests
- Use `#[instrument]` in test functions if needed
- Mock external dependencies via traits

### Common Patterns

**HTTP Handlers (main.rs):**
- Use pattern matching on request method and URL path
- Clone Arc references for spawned tasks
- Always respond to requests (even errors)

**Provider Implementations:**
- Implement trait `DnsProvider` for DNS operations
- Support profile ID overrides for multi-profile support
- Use proper error types for different failure modes

### Dependencies

Key dependencies to understand:
- `tiny_http` - HTTP server
- `reqwest` - HTTP client
- `tokio` - Async runtime
- `tracing` - Structured logging
- `opentelemetry-*` - Observability
- `serde` - Serialization
- `thiserror` - Error handling

### File Structure

```
src/
├── main.rs           # Application entry point
├── lib.rs            # Library root, exports
├── config.rs         # Configuration constants
├── domain.rs         # Core types, errors, traits
├── handlers.rs       # Handler module
│   ├── set.rs       # DNS setting operations
│   └── toggle.rs    # DNS toggle operations
└── providers.rs      # Provider module
    └── next_dns/
        ├── client.rs                    # NextDNS client
        ├── config.rs                    # Provider config
        └── parental_control_settings.rs # API types
```

### Git Conventions

- Use conventional commit messages (e.g., `feat:`, `fix:`, `chore:`, `infra:`):
  - `feat:` - New feature
  - `fix:` - Bug fix
  - `chore:` - Maintenance, dependency updates
  - `infra:` - Infrastructure changes
  - `docs:` - Documentation changes
- Run `cargo check` and `cargo clippy` before committing
- Ensure code is formatted with `cargo fmt`
