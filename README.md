# DNS Scheduler

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Rust Version](https://img.shields.io/badge/rust-2024-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A Rust-based service for scheduling DNS-related tasks on Google Cloud Platform, specifically focused on managing NextDNS settings. This application is designed to be deployed as a Cloud Run service, typically triggered by Cloud Scheduler to automate DNS toggles (e.g., enabling/disabling parental controls).

## Overview

The DNS Scheduler provides a lightweight HTTP interface to automate NextDNS operations. It currently supports:
- **Enable/Disable**: Set DNS settings based on a predefined allow/deny list.
- **Toggle**: Switch between enabled and disabled states.

## Architecture

- **Service**: A Rust application using `tiny_http` for low-overhead HTTP handling.
- **Cloud Run**: The application is containerized and deployed to Google Cloud Run, providing a serverless, scalable execution environment.
- **Secret Manager**: Sensitive configuration (like NextDNS API keys) is managed via GCP Secret Manager and injected into the environment.
- **Infrastructure as Code**: All GCP resources are managed via Terraform.
- **CI/CD**: Automated build and deployment pipelines using Google Cloud Build.
- **Nix**: Project dependencies and development environment are managed using Nix Flakes.

## Technology Stack

- **Language:** Rust (2024 edition)
- **Framework:** `tiny_http` (minimal HTTP server)
- **Cloud Provider:** Google Cloud Platform (GCP)
- **Infrastructure:** Terraform, GCP Cloud Run, GCP Secret Manager
- **CI/CD:** Google Cloud Build, Skaffold
- **Environment:** Nix (Flakes), Docker/Podman

## Prerequisites

- [Nix](https://nixos.org/download.html) (with flakes enabled)
- [Google Cloud SDK](https://cloud.google.com/sdk/install)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)

## Getting Started

### 1. Development Environment

This project uses Nix for a consistent development environment. To enter the shell with all dependencies:

```bash
nix develop
```

### 2. Configure Environment Variables

The application expects several environment variables:

- `NEXT_DNS_API_KEY`: Your NextDNS API key.
- `NEXT_DNS_PROFILE_ID_0`: The target NextDNS profile ID (0 based indexing, up to N)
- `DOMAIN_DENY_LIST`: (Optional) Comma-separated list of domains to block when enabled.
- `DOMAIN_ALLOW_LIST`: (Optional) Comma-separated list of domains to allow when enabled.
- `PORT`: (Optional) Port to listen on (defaults to 3003).

### 3. Run Locally

```bash
cargo run
```

The server will be available at `http://localhost:3003`. Available endpoints:
- `GET /enable`: Enable specified DNS settings.
- `GET /disable`: Disable specified DNS settings.
- `GET /toggle`: Toggle between states.

## Infrastructure & Deployment

### GCP Bootstrapping

Before first deployment, run the bootstrap script to prepare the GCP environment. This script requires several environment variables for GitLab integration and project identification:

- `GCP_PROJECT_ID`: The target GCP project ID.
- `GCP_PROJECT_NAME`: The name for the application (e.g., `dns-scheduler`).
- `GCP_GITLAB_API_TOKEN_SECRET`: Full resource path to the GitLab API token secret version.
- `GCP_GITLAB_READ_API_TOKEN_SECRET`: Full resource path to the GitLab read-only API token secret version.
- `GCP_GITLAB_WEBHOOK_SECRET`: Full resource path to the GitLab webhook secret version.

```bash
./bootstrap-gcp.sh
```

### Terraform

Provision the core infrastructure using Terraform:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Cloud Build

Deploy the application to Cloud Run:

```bash
gcloud builds submit . --config=cloudbuild-app.yaml
```

## Contributing

Please follow the guidelines in `GEMINI.md` for AI-assisted development.
