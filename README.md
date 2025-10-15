# DNS Scheduler - NextDNS Social Networks Scheduler

Automatically enables/disables NextDNS social networks blocking on a schedule using Google Cloud Functions and Cloud Scheduler.

## Schedule

- **Block social networks**: 8:30 PM Central Time
- **Unblock social networks**: 8:00 AM Central Time

This creates an 11.5-hour social media block period from evening to morning.

## Prerequisites

1. **NextDNS Account**: Get your Profile ID and API Key from [NextDNS](https://my.nextdns.io)
2. **Google Cloud Platform Account**: With billing enabled
3. **Terraform**: For infrastructure deployment
4. **gcloud CLI**: Configured with your GCP project

## NextDNS Setup

1. Log in to [NextDNS](https://my.nextdns.io)
2. Go to your profile settings
3. Note your **Profile ID** (in the URL: `my.nextdns.io/PROFILE_ID/setup`)
4. Generate an **API Key** in the account settings

## Deployment

### 1. Clone and Configure

```bash
git clone <this-repo>
cd dns-scheduler
```

### 2. Set up Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_id         = "your-gcp-project-id"
region            = "us-central1"
nextdns_profile_id = "your-nextdns-profile-id"
nextdns_api_key   = "your-nextdns-api-key"
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

After deployment completes, you'll see the function URLs in the output. You can manually test them:

```bash
# Test enabling social networks blocking
curl "ENABLE_FUNCTION_URL"

# Test disabling social networks blocking  
curl "DISABLE_FUNCTION_URL"
```

## Architecture

- **2 Cloud Functions**: Enable/disable social networks blocking
- **2 Cloud Scheduler jobs**: Trigger functions at scheduled times
- **1 Service Account**: For scheduler to invoke functions
- **1 Storage bucket**: For function source code

## Manual Control

You can manually trigger the functions:

1. **Via gcloud**:
   ```bash
   gcloud functions call dns-scheduler-enable --region=us-central1
   gcloud functions call dns-scheduler-disable --region=us-central1
   ```

2. **Via Cloud Console**: Navigate to Cloud Functions and test directly

3. **Via URL**: Use the function URLs (requires authentication)

## Cost Estimate

This setup should cost less than $1/month:
- Cloud Functions: ~$0.10/month (minimal invocations)
- Cloud Scheduler: Free tier (3 jobs/month)
- Cloud Storage: ~$0.01/month for source code

## Troubleshooting

### Function fails with authentication error
- Verify NextDNS Profile ID and API Key are correct
- Check if your NextDNS account has API access enabled

### Scheduler jobs not triggering
- Verify timezone is set to "America/Chicago"
- Check Cloud Scheduler logs in GCP Console

### Functions timing out
- Check if NextDNS API is responding
- Review function logs in Cloud Console

## Security Notes

- API credentials are stored as environment variables in Cloud Functions
- Functions are not publicly accessible (authentication required)
- Scheduler uses a dedicated service account with minimal permissions

## Customization

### Change Schedule Times

Edit the cron expressions in `terraform/main.tf`:

```hcl
# Enable at 8:30 PM CT
schedule = "30 20 * * *"

# Disable at 8:00 AM CT  
schedule = "0 8 * * *"
```

### Change Timezone

Update the `time_zone` in the scheduler jobs:

```hcl
time_zone = "America/Chicago"  # Central Time
```

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy
```

## Development

### Local Testing

```bash
# Install dependencies
go mod tidy

# Run locally (requires NextDNS credentials as env vars)
export NEXTDNS_PROFILE_ID="your-profile-id"
export NEXTDNS_API_KEY="your-api-key"
go run .

# Test endpoints
curl "http://localhost:8080/EnableSocialNetworks"
curl "http://localhost:8080/DisableSocialNetworks"
```