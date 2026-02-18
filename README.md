# DNS Scheduler

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Rust Version](https://img.shields.io/badge/rust-1.x-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A Rust-based service for scheduling DNS-related tasks on Google Cloud Platform, deployed via Cloud Build and managed with Terraform.

## Overview

The DNS Scheduler provides a framework for automating DNS operations within a GCP environment. It is designed to be deployed as a Cloud Run service, triggered by events or schedules to perform its tasks.

## Technology Stack

- **Language:** Rust
- **Cloud Provider:** Google Cloud Platform (GCP)
- **Infrastructure as Code:** Terraform
- **CI/CD & Deployment:** Google Cloud Build, Skaffold, Cloud Deploy
- **Containerization:** Docker

## Prerequisites

Before you begin, ensure you have the following installed:

- [Go](https://go.dev/doc/install) (latest version recommended)
- [Google Cloud SDK](https://cloud.google.com/sdk/install)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [direnv](https://direnv.net/) (for managing environment variables locally)

## Getting Started

Follow these steps to get your development environment set up.

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd dns-scheduler
```

### 2. Configure Environment Variables

This project uses `direnv` to manage environment variables.

1.  **Create/Edit `.envrc`:** Edit the `.envrc` file in the project root and fill in your specific values for `GCP_PROJECT_ID` and any local development secrets.
2.  **Allow direnv:** Navigate to the project root directory and allow `direnv` to load the environment variables.
    ```bash
    direnv allow
    ```
    This will load the variables defined in `.envrc` into your shell environment.

### 3. Configure GCP Authentication

Log in to the gcloud CLI and set your project.

```bash
gcloud auth login
gcloud config set project <your-gcp-project-id>
```

### 4. Bootstrap the GCP Environment

Before deploying the infrastructure, you must run a one-time bootstrap script. This script prepares the GCP project with the necessary permissions, APIs, and secrets required for the CI/CD pipeline to function. The `GCP_PROJECT_ID` used by this script is sourced from your environment variables (e.g., via `direnv`).

Specifically, the script performs the following actions:
- Enables the Cloud Deploy and Infrastructure Manager APIs.
- Creates a dedicated service account for the Cloud Build pipeline.
- Grants the service account the broad set of IAM permissions it needs to manage resources.
- Establishes a connection to the project's GitLab repository.
- Creates placeholder secrets in Google Secret Manager.

Run the script from the root of the repository:
```bash
./bootstrap-gcp.sh
```
**IMPORTANT**: After the script completes, you must manually populate the created secrets (`NEXTDNS_API_KEY`, `NEXTDNS_PROFILE_ID_0`, etc.) with their actual values using the gcloud CLI as instructed in the script's output.

### 5. Provision Infrastructure

Once the environment is bootstrapped, you can provision the core GCP resources using Terraform.

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 6. Run the Application

_(Instructions on how to run the Go application locally. You may need to fill this in with more specific details, such as required environment variables.)_

```bash
# From the root directory
go run function.go
```

## Deployment

This project is configured for automated deployments using Google Cloud Build.

- `cloudbuild-app.yaml`\*\*: Builds the Docker image for the Go application and deploys it to Cloud Run.
- `skaffold.yaml`\*\*: Enables continuous development workflows.

To trigger an application build and deployment, you can run:

```bash
# Example command (update substitutions as needed)
gcloud builds submit . \
  --config=cloudbuild-app.yaml \
  --substitutions=_REPO="dns-scheduler-repo",_IMAGE_NAME="dns-scheduler",_LOCATION="us-central1"
```

## Contributing

Contributions are welcome! Please refer to the `GEMINI.md` file in this repository for guidelines on how the AI assistant can help you with development tasks.
