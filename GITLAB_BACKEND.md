# GitLab Terraform Backend Setup

This project is configured to use GitLab-managed Terraform state for secure, collaborative infrastructure management.

## Prerequisites

1. **GitLab Project**: Ensure your project is hosted on GitLab
2. **Infrastructure Menu**: Enable the Infrastructure menu in your GitLab project:
   - Go to **Settings > General**
   - Expand **Visibility, project features, permissions**
   - Under **Infrastructure**, turn on the toggle
3. **Personal Access Token**: Create a GitLab personal access token with `api` scope for local development

## Setup for GitLab CI/CD

The project includes a `.gitlab-ci.yml` file that automatically configures the GitLab backend for CI/CD pipelines. When you push to GitLab:

1. The pipeline will run `terraform validate`
2. Generate a `terraform plan`
3. Provide a manual deployment step for `terraform apply`

The state will be automatically stored in GitLab at:
```
https://gitlab.com/api/v4/projects/{PROJECT_ID}/terraform/state/dns-scheduler
```

## Setup for Local Development

### Option 1: Using the Initialization Script

1. Find your GitLab project ID:
   - Go to your GitLab project
   - The project ID is shown below the project name

2. Update the `PROJECT_ID` in `init-gitlab-backend.sh`

3. Set your environment variables:
   ```bash
   export GITLAB_USERNAME="your_gitlab_username"
   export GITLAB_TOKEN="your_personal_access_token"
   ```

4. Run the initialization script:
   ```bash
   ./init-gitlab-backend.sh
   ```

### Option 2: Manual Initialization

```bash
cd terraform

PROJECT_ID="your_gitlab_project_id"
TF_USERNAME="your_gitlab_username"
TF_PASSWORD="your_gitlab_personal_access_token"
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/dns-scheduler"

terraform init \
  -backend-config="address=${TF_ADDRESS}" \
  -backend-config="lock_address=${TF_ADDRESS}/lock" \
  -backend-config="unlock_address=${TF_ADDRESS}/lock" \
  -backend-config="username=${TF_USERNAME}" \
  -backend-config="password=${TF_PASSWORD}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

### Option 3: Using GitLab CLI (glab)

If you have the GitLab CLI installed:

```bash
cd terraform
glab opentofu init dns-scheduler
```

## Migrating Existing State

If you have existing Terraform state from another backend:

1. Initialize with your current backend first
2. Then run the initialization script with the `-migrate-state` flag
3. Confirm the migration when prompted

## Managing State

### View State Files
- In GitLab: **Operate > Terraform states**
- CLI: `glab opentofu state download dns-scheduler`

### Lock/Unlock State
- UI: **Operate > Terraform states > Actions**
- CLI: `glab opentofu state lock dns-scheduler`

### Remove State (Maintainer role required)
- UI: **Operate > Terraform states > Actions > Remove state file**
- CLI: `glab opentofu state delete dns-scheduler`

## Security Notes

- State files are encrypted at rest by GitLab
- Access is controlled by GitLab project permissions
- Personal access tokens should have minimal required scopes
- Never commit personal access tokens to version control

## Troubleshooting

- Ensure you have at least Developer role for `terraform plan`
- Ensure you have at least Maintainer role for `terraform apply`
- Check that the Infrastructure menu is enabled in project settings
- Verify your personal access token has the `api` scope