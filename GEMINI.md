# Gemini Assistant Project Guide

This document provides instructions and guidelines for the Gemini AI assistant to ensure it can effectively and consistently contribute to this project.

## 1. Project Overview

This project, `dns-scheduler`, is a personal application designed to run on Google Cloud. It uses Terraform for infrastructure management and Cloud Build for CI/CD. The primary goal is to be schedul DNS-related tasks.

## 2. Key Technologies

- **Language:** Rust
- **Cloud Provider:** Google Cloud Platform (GCP)
- **Infrastructure as Code:** Terraform
- **CI/CD:** Google Cloud Build
- **Containerization:** Docker/Podman

## Architectural Principles

This project aims to adhere to the [Twelve-Factor App](https://12factor.net/) methodology. Specifically:

-   **III. Config:** Configuration is strictly separated from code and stored in the environment. For local development, nix is used to manage environment variables via the `.env` file(s). For deployment on GCP, configuration (including secrets) is sourced from environment variables, GCP Secret Manager, or other secure external services, rather than being hard-coded.
-   **IX. Disposability:** The application is designed to be stateless and disposable.
-   **XI. Logs:** The application uses structured logging and tracing (via the `tracing` crate) to provide visibility into its operation. In production, these are exported to Google Cloud Trace.

## 3. Important Commands

Please fill in or modify these commands as needed.

### Rust

This project uses Rust (2024 edition).

- **Build:** `cargo build`
- **Run:** `cargo run` (Use `RUST_LOG=info cargo run` to see tracing spans)
- **Format:** `cargo fmt`
- **Lint:** `cargo clippy`
- **Test:** `cargo test`
- **Check:** `cargo check` (Preferred for quick verification)

### Terraform

Terraform is managed by Google Cloud Infrastructure Manager. For local testing:

- **Initialize:** `cd terraform && terraform init`
- **Plan:** `terraform plan -var="project_id=YOUR_PROJECT_ID"`
- **Apply:** `terraform apply -var="project_id=YOUR_PROJECT_ID"`

### Cloud Build

- **Submit a build (example):**
  ```bash
  gcloud builds submit . \
    --config=cloudbuild-app.yaml \
    --substitutions=_REPO_NAME="your-repo",_IMAGE_NAME="your-image",_PIPELINE_NAME="your-pipeline",_LOCATION="us-central1"
  ```

## 4. Code Style & Conventions

- **Git Commits:** ALWAYS use Conventional Commits (e.g., `feat:`, `fix:`, `infra:`, `chore:`).
- **Observability:** 
    - Use the `tracing` ecosystem (`tracing`, `tracing-subscriber`, `tracing-opentelemetry`).
    - Prefer `#[instrument]` macros for automated span management.
    - Use `DnsResponse` to track partial successes/failures in handlers and set OTel span status accordingly.
- **Error Handling:** Use `thiserror` for descriptive domain errors.

## 5. Environment & Secrets

- Secrets are managed in GCP Secret Manager and referenced in Terraform and Cloud Run templates.
- The `ENVIRONMENT` variable should be used to distinguish between environments (e.g., `prod`, `dev`).
- **Sampling:** Use a `TraceIdRatioBased` sampler to manage tracing costs in production.

**Note to Assistant:** Never commit secret values or sensitive information to the repository.

## 6. Gemini Role to the Developer
- **Pair Programmer:** Function as a guide and collaborator. Do not just "do the work." 
- **Explain the "Why":** Before suggesting a change, explain the architectural principle or logic behind it.
- **"Check Me":** Proactively use `cargo check` to verify your suggestions.
- **Cognizance:** Always flag potential side effects (e.g., costs, timing, security, PII).
- **Incrementalism:** Take complex tasks one step at a time to enable learning.
