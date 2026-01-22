#!/bin/bash
# ==============================================================================
# Bootstrap Script for dns-scheduler CI/CD
#
# This script performs the one-time setup required to handle the
# "chicken-and-egg" problem where required infrastructure is not available to
# Terraform the infrastructure.
#
# USAGE:
# ./bootstrap-gcp.sh
# ==============================================================================
set -e

# Configuration
GCP_PROJECT_ID=${GCP_PROJECT_ID:?GCP_PROJECT_ID environment variable not set}
GCP_PROJECT_NAME=${GCP_PROJECT_NAME:?GCP_PROJECT_NAME environment variable not set}

echo "Bootstrapping project environment for project: ${GCP_PROJECT_ID}"

# 1. Enable GCP APIs
echo "Enabling required GCP APIs..."
gcloud services enable config.googleapis.com
gcloud services enable clouddeploy.googleapis.com

# 2. Create a dedicated service account for Cloud Build (if it doesn't exist)
GCP_BUILDER_SA_NAME="${GCP_PROJECT_NAME}-builder"
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

# 3. Grant the new service account necessary IAM roles
echo "Granting IAM roles to Cloud Build service account: ${GCP_BUILDER_SA_EMAIL}"
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/artifactregistry.repoAdmin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/artifactregistry.writer" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/config.agent" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/clouddeploy.operator" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/cloudscheduler.admin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/iam.serviceAccountAdmin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/logging.logWriter" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/privilegedaccessmanager.projectServiceAgent" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/resourcemanager.projectIamAdmin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/run.developer" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/run.serviceAgent" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/secretmanager.admin" --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_BUILDER_SA_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator" --condition=None

gcloud builds connections create gitlab GitLab \
  --region=us-central1 \
  --project=${GCP_PROJECT_ID} \
  --host-uri=https://gitlab.com \
  --authorizer-token-secret-version=projects/209433922082/locations/us-central1/secrets/cloudbuild-gitlab-1764712029569-api-access-token/versions/latest \
  --read-authorizer-token-secret-version=projects/209433922082/locations/us-central1/secrets/cloudbuild-gitlab-1764712029569-read-api-access-token/versions/latest \
  --webhook-secret-secret-version=projects/209433922082/locations/us-central1/secrets/cloudbuild-gitlab-1764712029569-webhook-secret/versions/latest

gcloud builds repositories create connectwithawalsh-${GCP_PROJECT_NAME} \
  --remote-uri=https://gitlab.com/connectwithawalsh/${GCP_PROJECT_NAME}.git \
  --connection=GitLab \
  --region=us-central1 \
  --project=${GCP_PROJECT_ID}

echo "Bootstraping secrets"
if ! gcloud secrets describe NEXTDNS_API_KEY --project=${GCP_PROJECT_ID} &>/dev/null; then
  gcloud secrets create NEXTDNS_API_KEY
else
  echo "Secret NEXTDNS_API_KEY already exists."
fi

if ! gcloud secrets describe NEXTDNS_PROFILE_ID --project=${GCP_PROJECT_ID} &>/dev/null; then
  gcloud secrets create NEXTDNS_PROFILE_ID
else
  echo "Secret NEXTDNS_PROFILE_ID already exists."
fi

if ! gcloud secrets describe NEXTDNS_PROFILE_ID_2 --project=${GCP_PROJECT_ID} &>/dev/null; then
  gcloud secrets create NEXTDNS_PROFILE_ID_2
else
  echo "Secret NEXTDNS_PROFILE_ID_2 already exists."
fi

echo "Bootstrap complete!"

echo ""
echo "================================================================================"
echo "  IMPORTANT: MANUAL STEP REQUIRED"
echo ""
echo "  Secret Manager Secrets are now bootstrapped."
echo "  Run the below commands with production values from local to set verison 1."
echo "  echo -n \"placeholder\" | gcloud secrets create NEXTDNS_API_KEY --data-file=-"
echo "  echo -n \"placeholder\" | gcloud secrets create NEXTDNS_PROFILE_ID --data-file=-"
echo "  echo -n \"placeholder\" | gcloud secrets create NEXTDNS_PROFILE_ID_2 --data-file=-"
echo ""
echo "================================================================================"
