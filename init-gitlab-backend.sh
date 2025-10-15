#!/bin/bash

# GitLab Terraform Backend Initialization Script
# This script initializes Terraform to use GitLab-managed state

# Configuration variables - update these for your project
PROJECT_ID="75343136"
STATE_NAME="dns-scheduler"
GITLAB_URL="https://gitlab.com"

# Check if required environment variables are set
if [ -z "$GITLAB_TOKEN" ]; then
  echo "Error: GITLAB_TOKEN environment variable is required"
  echo "Create a personal access token with 'api' scope and set it:"
  echo "export GITLAB_TOKEN=your_token_here"
  exit 1
fi

if [ -z "$GITLAB_USERNAME" ]; then
  echo "Error: GITLAB_USERNAME environment variable is required"
  echo "Set your GitLab username:"
  echo "export GITLAB_USERNAME=your_username_here"
  exit 1
fi

# Construct the backend configuration
TF_ADDRESS="${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE_NAME}"

echo "Initializing Terraform with GitLab backend..."
echo "Project ID: ${PROJECT_ID}"
echo "State Name: ${STATE_NAME}"
echo "Address: ${TF_ADDRESS}"

# Change to terraform directory
cd terraform

# Initialize Terraform with GitLab backend
terraform init \
  -backend-config="address=${TF_ADDRESS}" \
  -backend-config="lock_address=${TF_ADDRESS}/lock" \
  -backend-config="unlock_address=${TF_ADDRESS}/lock" \
  -backend-config="username=${GITLAB_USERNAME}" \
  -backend-config="password=${GITLAB_TOKEN}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"

echo "Terraform initialization complete!"
echo ""
echo "You can now run:"
echo "  terraform plan"
echo "  terraform apply"

