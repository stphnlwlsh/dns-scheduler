#!/bin/bash
# ==============================================================================
# Bootstrap Script for dns-scheduler CI/CD
#
# This script performs the one-time setup required to allow Google Cloud Build
# to deploy the application. It handles the "chicken-and-egg" problem where
# the CI/CD service account needs permissions *before* it can run Terraform.
#
# Why are these permissions here and not in Terraform?
# The Cloud Build service account's own permissions cannot be managed by a
# Terraform configuration that it is responsible for applying. Therefore, its
# core permissions must be granted here, "out-of-band."
#
# All other application-specific IAM roles (e.g., for the Cloud Scheduler)
# are correctly defined and managed within the Terraform configuration.
#
# USAGE:
# ./bootstrap-gcp.sh
# ==============================================================================
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
gcloud services enable clouddeploy.googleapis.com \
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

# 3. Create a dedicated service account for Cloud Build (if it doesn't exist)
GCP_BUILDER_SA_NAME="dns-scheduler-builder"
GCP_BUILDER_SA_EMAIL="${GCP_BUILDER_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

echo "Checking for Cloud Build service account..."
if ! gcloud iam service-accounts describe ${GCP_BUILDER_SA_EMAIL} --project=${GCP_PROJECT_ID} &>/dev/null; then
  echo "Creating dedicated service account for Cloud Build: ${GCP_BUILDER_SA_NAME}"
  gcloud iam service-accounts create ${GCP_BUILDER_SA_NAME} \
    --project=${GCP_PROJECT_ID} \
    --display-name="DNS Scheduler Builder"
else
  echo "Cloud Build service account already exists."
fi

# 4. Grant the new service account necessary IAM roles
echo "Granting IAM roles to Cloud Build service account: ${GCP_BUILDER_SA_EMAIL}"

# Roles for deploying Cloud Run, managing Artifact Registry, and Cloud Scheduler
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/run.admin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/artifactregistry.admin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/cloudscheduler.admin" --condition=None

# Roles for managing service accounts (for the scheduler) and their permissions
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/iam.serviceAccountAdmin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" --condition=None

# Role for managing Terraform state in the GCS bucket
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/storage.admin" --condition=None

# Role for accessing secrets
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" --condition=None

# Role for writing logs
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/logging.logWriter" --condition=None

# Role for creating Cloud Deploy releases
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/clouddeploy.releaser" --condition=None

# Role for accessing the Cloud Deploy pipeline
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/clouddeploy.developer" --condition=None

echo "Bootstrap complete!"

echo ""
echo "================================================================================"
echo "  IMPORTANT: MANUAL STEP REQUIRED"
echo ""
echo "  The Cloud Run service needs permission to access secrets at runtime."
echo "  Run the following command once to grant this permission:"
echo ""
echo "  gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \\"
echo "    --member=\"serviceAccount:dns-scheduler@${GCP_PROJECT_ID}.iam.gserviceaccount.com\" \\"
echo "    --role=\"roles/secretmanager.secretAccessor\" \\"
echo "    --condition=None"
echo "================================================================================"
