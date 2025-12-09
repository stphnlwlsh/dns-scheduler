# Gemini Assistant Project Guide

This document provides instructions and guidelines for the Gemini AI assistant to ensure it can effectively and consistently contribute to this project.

## 1. Project Overview

This project, `dns-scheduler`, appears to be a Go-based application designed to run on Google Cloud. It uses Terraform for infrastructure management and Cloud Build for CI/CD. The primary goal seems to be scheduling DNS-related tasks.

## 2. Key Technologies

- **Language:** Go
- **Cloud Provider:** Google Cloud Platform (GCP)
- **Infrastructure as Code:** Terraform
- **CI/CD:** Google Cloud Build
- **Containerization:** Docker

## Architectural Principles

This project aims to adhere to the [Twelve-Factor App](https://12factor.net/) methodology. Specifically:

-   **III. Config:** Configuration is strictly separated from code and stored in the environment. For local development, `direnv` is used to manage environment variables via the `.envrc` file. For deployment on GCP, configuration (including secrets) is sourced from environment variables, GCP Secret Manager, or other secure external services, rather than being hardcoded.

## 3. Important Commands

Please fill in or modify these commands as needed.

### Go

- **Run tests:** `go test ./...`
- **Format code:** `go fmt ./...`
- **Lint code:** _(Please provide the linting command, e.g., `golangci-lint run`)_
- **Tidy modules:** `go mod tidy`

### Terraform

Terraform is managed by Google Cloud Infrastructure Manager. For local testing:

- **Initialize:** `cd terraform && terraform init`
- **Plan:** `terraform plan`

### Cloud Build

- **Submit a build (example):**
  ```bash
  gcloud builds submit . \
    --config=cloudbuild-app.yaml \
    --substitutions=_REPO="your-repo",_IMAGE_NAME="your-image",_LOCATION="us-central1"
  ```

## 4. Code Style & Conventions

_Please add any specific coding style preferences, naming conventions, or architectural patterns to follow._

- ...
- ...

## 5. Environment & Secrets

_Secrets are managed in GCP Secret Manager and referenced in Terraform files._

**Note to Assistant:** Never commit secret values or sensitive information to the repository.
