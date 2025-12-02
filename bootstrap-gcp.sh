#!/bin/bash
set -e

# Configuration
GCP_PROJECT_ID="cwaw-prod-67f8c561"
GCP_REGION="us-central1"
TF_STATE_BUCKET="${GCP_PROJECT_ID}-tfstate"

echo "Bootstrapping CI/CD environment for project: ${GCP_PROJECT_ID}"

# 1. Enable GCP APIs
echo "Enabling required GCP APIs..."
gcloud services enable iam.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable iamcredentials.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable artifactregistry.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable run.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable cloudscheduler.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable cloudbuild.googleapis.com \
  --project=${GCP_PROJECT_ID}
gcloud services enable secretmanager.googleapis.com \
  --project=${GCP_PROJECT_ID}

# 2. Create GCS bucket for Terraform state (if it doesn't exist)
echo "Checking for Terraform state bucket..."
if ! gcloud storage buckets describe gs://${TF_STATE_BUCKET} --project=${GCP_PROJECT_ID} &>/dev/null; then
  echo "Creating GCS bucket for Terraform state: ${TF_STATE_BUCKET}"
  gcloud storage buckets create gs://${TF_STATE_BUCKET} \
    --project=${GCP_PROJECT_ID} \
    --location=${GCP_REGION} \
    --uniform-bucket-level-access
else
  echo "Terraform state bucket already exists."
fi

# 3. Grant Cloud Build service account necessary IAM roles
GCP_PROJECT_NUMBER=$(gcloud projects describe ${GCP_PROJECT_ID} --format='value(projectNumber)')
GCP_CLOUD_BUILD_SA="${GCP_PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo "Granting IAM roles to Cloud Build service account: ${GCP_CLOUD_BUILD_SA}"

# Roles for deploying Cloud Run, managing Artifact Registry, and Cloud Scheduler
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/cloudscheduler.admin"

# Roles for managing service accounts (for the scheduler) and their permissions
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/iam.serviceAccountUser"

# Role for managing Terraform state in the GCS bucket
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/storage.admin"

# Role for accessing secrets
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_CLOUD_BUILD_SA}" \
  --role="roles/secretmanager.secretAccessor"

echo "Bootstrap complete!"
