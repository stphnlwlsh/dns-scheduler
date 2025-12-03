# DNS Scheduler - NextDNS Social Networks Scheduler

Automatically enables/disables NextDNS social networks blocking on a schedule using a containerized Go application deployed to Google Cloud Run.

## Schedule

- **Block social networks**: 8:30 PM Central Time
- **Unblock social networks**: 8:00 AM Central Time

This creates an 11.5-hour social media block period from evening to morning.

## Prerequisites

1.  **NextDNS Account**: Get your Profile ID and API Key from [my.nextdns.io](https://my.nextdns.io).
2.  **Google Cloud Platform Account**: With billing enabled.
3.  **gcloud CLI**: Authenticated with your GCP account.
4.  **GitLab Account**: To host the repository.

## Architecture

- **Go HTTP Server**: A single containerized application that exposes `/enable`, `/disable`, and `/toggle` endpoints.
- **Google Cloud Run**: Hosts the container and makes it accessible via a secure URL.
- **Google Cloud Scheduler**: Two jobs that trigger the `/enable` and `/disable` endpoints on schedule.
- **Google Cloud Build**: A CI/CD pipeline that builds the container, runs Terraform, and deploys the application.
- **Google Secret Manager**: Securely stores the NextDNS credentials.
- **Terraform**: Manages all the application infrastructure as code.

## One-Time Setup

Before the CI/CD pipeline can run, a few one-time bootstrap steps are required.

### 1. Configure the Project

Clone the repository and `cd` into the directory. The `bootstrap-gcp.sh` script is configured with your project ID.

### 2. Run the Bootstrap Script

This script performs the following actions:
- Enables all required GCP APIs.
- Creates a GCS bucket to store Terraform state.
- Creates a dedicated service account for the Cloud Build pipeline.
- Grants the Cloud Build service account all the necessary permissions to deploy the application.

```bash
./bootstrap-gcp.sh
```

### 3. Create Secrets

Store your NextDNS credentials securely in Google Secret Manager.

```bash
# Replace with your actual credentials
echo -n "YOUR_NEXTDNS_API_KEY" | gcloud secrets create NEXTDNS_API_KEY --data-file=-
echo -n "YOUR_NEXTDNS_PROFILE_ID" | gcloud secrets create NEXTDNS_PROFILE_ID --data-file=-

# Optional: If you have a second profile, create this secret
echo -n "YOUR_NEXTDNS_PROFILE_ID_2" | gcloud secrets create NEXTDNS_PROFILE_ID_2 --data-file=-
```

### 4. Grant Runtime Secret Access

The Cloud Run service needs permission to access the secrets at runtime. Grant this permission manually one time.

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:dns-scheduler@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --condition=None
```

### 5. Connect GitLab to Cloud Build

The final step is to create a Cloud Build Trigger that connects your GitLab repository to the pipeline.

1.  **Navigate to Cloud Build Triggers** in the Google Cloud Console.
2.  **Connect Repository**: Follow the prompts to link your GitLab account and select the `dns-scheduler` repository.
3.  **Create Trigger**: Create a new trigger with the following settings:
    - **Name**: `dns-scheduler-main`
    - **Event**: "Push to a branch"
    - **Branch**: `^main$`
    - **Configuration**: "Cloud Build configuration file (yaml or json)"
    - **Location**: `/cloudbuild.yaml`
    - **Service account**: Select the `dns-scheduler-builder@...` account.
    - **Approval**: Check "Require approval before executing."
    - **Substitution Variables**:
        - `_REGION`: `us-central1`

## Deployment

Once the one-time setup is complete, deployment is fully automated. Every `git push` to the `main` branch will:
1.  Trigger the Cloud Build pipeline.
2.  Build and push the application container to Artifact Registry.
3.  Run `terraform plan` to calculate infrastructure changes.
4.  **Pause and wait for manual approval** in the Google Cloud Console.
5.  After approval, run `terraform apply` to deploy the application.

## Cleanup

To remove all deployed resources:
1.  Navigate to the Cloud Build history in the Google Cloud Console.
2.  Find the last successful build for your `main` branch.
3.  Click the "Approve" button to proceed with the `destroy` plan.

To remove the bootstrap resources, you can run:
```bash
./bootstrap-gcp.sh destroy
```

## Local Development

```bash
# Install dependencies
go mod tidy

# Run the server (requires credentials as env vars)
export NEXTDNS_PROFILE_ID="your-profile-id"
export NEXTDNS_API_KEY="your-api-key"
go run .

# Test endpoints
curl "http://localhost:8080/enable"
curl "http://localhost:8080/disable"
```
