#!/bin/bash
set -e

# Configuration
GCP_POOL_ID="gitlab-pool"
GCP_PROJECT_ID="cwaw-prod-67f8c561"
GCP_PROVIDER_ID="gitlab-provider"
GCP_REGION="us-central1"
GCP_SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
GCP_SERVICE_ACCOUNT_NAME="gitlab-ci"
GITLAB_PROJECT_PATH="connectwithawalsh/dns-scheduler" # Update this to your GitLab project path

echo "Setting up Workload Identity Federation for project: ${GCP_PROJECT_ID}"

# 1. Create Workload Identity Pool
echo "Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create ${GCP_POOL_ID} \
  --project=${GCP_PROJECT_ID} \
  --location=global \
  --display-name="GitLab Pool" \
  --description="Workload Identity Pool for GitLab CI/CD" ||
  echo "Pool already exists, continuing..."

# 2. Create Workload Identity Pool Provider
echo "Creating Workload Identity Pool Provider..."
gcloud iam workload-identity-pools providers create-oidc ${GCP_PROVIDER_ID} \
  --project=${GCP_PROJECT_ID} \
  --location=global \
  --workload-identity-pool=${GCP_POOL_ID} \
  --display-name="GitLab Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.project_path=assertion.project_path,attribute.ref=assertion.ref,attribute.ref_type=assertion.ref_type" \
  --attribute-condition="assertion.project_path == '${GITLAB_PROJECT_PATH}'" \
  --issuer-uri="https://gitlab.com" ||
  echo "Provider already exists, continuing..."

# 3. Create Service Account (if it doesn't exist)
echo "Creating Service Account..."
gcloud iam service-accounts create ${GCP_SERVICE_ACCOUNT_NAME} \
  --project=${GCP_PROJECT_ID} \
  --display-name="GitLab CI Service Account" \
  --description="Service account for GitLab CI/CD deployments" ||
  echo "Service account already exists, continuing..."

# 4. Grant IAM permissions to the service account
echo "Granting IAM permissions..."

# Artifact Registry Writer
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/artifactregistry.writer"

# Cloud Run Admin
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin"

# Service Account User (to deploy Cloud Run services)
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# 5. Allow the Workload Identity Pool to impersonate the service account
echo "Binding Workload Identity Pool to Service Account..."
gcloud iam service-accounts add-iam-policy-binding ${GCP_SERVICE_ACCOUNT_EMAIL} \
  --project=${GCP_PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${GCP_PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${GCP_POOL_ID}/attribute.project_path/${GITLAB_PROJECT_PATH}"

# 6. Display the configuration for GitLab CI/CD variables
echo ""
echo "======================================"
echo "Setup complete! Add these variables to your GitLab CI/CD settings:"
echo "======================================"
echo ""
GCP_PROJECT_NUMBER=$(gcloud projects describe ${GCP_PROJECT_ID} --format='value(projectNumber)')
echo "GCP_WORKLOAD_IDENTITY_PROVIDER:"
echo "projects/${GCP_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${GCP_POOL_ID}/providers/${GCP_PROVIDER_ID}"
echo ""
echo "GCP_SERVICE_ACCOUNT_EMAIL:"
echo "${GCP_SERVICE_ACCOUNT_EMAIL}"
echo ""
echo "GCP_GCP_PROJECT_ID:"
echo "${GCP_PROJECT_ID}"
echo ""
echo "GCP_GCP_REGION:"
echo "${GCP_REGION}"
echo ""
echo "======================================"
