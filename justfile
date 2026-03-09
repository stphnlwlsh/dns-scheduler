# Set just's behavior - use sh for cross-shell compatibility
set shell := ["sh", "-c"]

# Default to 'local' unless 'ENVIRONMENT' is passed as 'prod'
env_mode := env_var_or_default("ENVIRONMENT", "dev")

# Build the env file path
env_file := if env_mode == "prod" { ".env_prod.env" } else { ".env_local.env" }
common_file := ".env_common.env"

# --- TASKS ---

# Build and run with OTel collector (defaults to local/dev)
up:
    @echo "🚀 Starting OTel Collector ({{env_mode}})..."
    @set -a; \
    [ -f "{{common_file}}" ] && . ./{{common_file}} || true; \
    [ -f "{{env_file}}" ] && . ./{{env_file}} || true; \
    set +a; \
    podman-compose up -d
    @echo "🏃 Running Rust Application (dns-scheduler)..."
    @set -a; \
    [ -f "{{common_file}}" ] && . ./{{common_file}} || true; \
    [ -f "{{env_file}}" ] && . ./{{env_file}} || true; \
    set +a; \
    ENVIRONMENT=prod RUST_LOG=debug cargo run

# Run only the Rust application (standalone)
run:
    @echo "🏃 Running Rust Application (dns-scheduler) [{{env_mode}}]..."
    @set -a; \
    [ -f "{{common_file}}" ] && . ./{{common_file}} || true; \
    [ -f "{{env_file}}" ] && . ./{{env_file}} || true; \
    set +a; \
    ENVIRONMENT=dev RUST_LOG=debug cargo run

# Shut down the containers
down:
    @echo "🛑 Stopping containers ({{env_mode}})..."
    @set -a; \
    [ -f "{{common_file}}" ] && . ./{{common_file}} || true; \
    [ -f "{{env_file}}" ] && . ./{{env_file}} || true; \
    set +a; \
    podman-compose down

# Check the application
check:
    @echo "🔍 Checking application ({{env_mode}})..."
    @set -a; \
    [ -f "{{common_file}}" ] && . ./{{common_file}} || true; \
    [ -f "{{env_file}}" ] && . ./{{env_file}} || true; \
    set +a; \
    cargo check

# Show which environment is being used
info:
    @echo "Environment mode: {{env_mode}}"
    @echo "Common file: {{common_file}}"
    @echo "Env file: {{env_file}}"
