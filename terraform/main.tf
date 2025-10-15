provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "nextdns_profile_id" {
  description = "NextDNS Profile ID"
  type        = string
  sensitive   = true
}

variable "nextdns_api_key" {
  description = "NextDNS API Key"
  type        = string
  sensitive   = true
}

# Create a ZIP file of the source code
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "../"
  output_path = "./dns-scheduler.zip"
  excludes = [
    "terraform/",
    ".git/",
    "README.md",
    ".gitignore",
    "credential-config.json",
    ".gitlab-ci.yml"
  ]
}

# Debug resource to check directory structure and create archive manually
resource "null_resource" "debug_archive" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Current directory: $(pwd)"
      echo "Contents of current directory:"
      ls -la
      echo "Contents of parent directory:"
      ls -la ../
      echo "Creating zip manually:"
      cd .. && zip -r terraform/dns-scheduler.zip . -x 'terraform/*' '.git/*' 'README.md' '.gitignore' 'credential-config.json' '.gitlab-ci.yml'
      echo "Checking created zip:"
      ls -la terraform/dns-scheduler.zip
    EOT
  }
}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-dns-scheduler-source"
  location = var.region

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Upload the source code to the bucket
resource "google_storage_bucket_object" "source" {
  name   = "dns-scheduler-${filemd5("./dns-scheduler.zip")}.zip"
  bucket = google_storage_bucket.function_source.name
  source = "./dns-scheduler.zip"
  depends_on = [null_resource.debug_archive]
}

# Cloud Function for enabling social networks blocking
resource "google_cloudfunctions2_function" "enable_social_networks" {
  name     = "dns-scheduler-enable"
  location = var.region

  build_config {
    runtime     = "go122"
    entry_point = "EnableSocialNetworks"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "128Mi"
    timeout_seconds    = 60

    environment_variables = {
      NEXTDNS_PROFILE_ID = var.nextdns_profile_id
      NEXTDNS_API_KEY    = var.nextdns_api_key
    }
  }
}

# Cloud Function for disabling social networks blocking
resource "google_cloudfunctions2_function" "disable_social_networks" {
  name     = "dns-scheduler-disable"
  location = var.region

  build_config {
    runtime     = "go122"
    entry_point = "DisableSocialNetworks"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "128Mi"
    timeout_seconds    = 60

    environment_variables = {
      NEXTDNS_PROFILE_ID = var.nextdns_profile_id
      NEXTDNS_API_KEY    = var.nextdns_api_key
    }
  }
}

# Cloud Scheduler job to enable social networks blocking at 8:30 PM CT
resource "google_cloud_scheduler_job" "enable_social_networks" {
  name             = "dns-scheduler-enable-schedule"
  description      = "Enable social networks blocking at 8:30 PM Central Time"
  schedule         = "30 20 * * *" # 8:30 PM daily
  time_zone        = "America/Chicago"
  attempt_deadline = "60s"

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions2_function.enable_social_networks.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# Cloud Scheduler job to disable social networks blocking at 8:00 AM CT
resource "google_cloud_scheduler_job" "disable_social_networks" {
  name             = "dns-scheduler-disable-schedule"
  description      = "Disable social networks blocking at 8:00 AM Central Time"
  schedule         = "0 8 * * *" # 8:00 AM daily
  time_zone        = "America/Chicago"
  attempt_deadline = "60s"

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions2_function.disable_social_networks.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# Service account for Cloud Scheduler
resource "google_service_account" "scheduler" {
  account_id   = "dns-scheduler"
  display_name = "DNS Scheduler Service Account"
}

# IAM policy to allow scheduler to invoke Cloud Functions
resource "google_cloud_run_service_iam_member" "enable_invoker" {
  service  = google_cloudfunctions2_function.enable_social_networks.name
  location = google_cloudfunctions2_function.enable_social_networks.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_run_service_iam_member" "disable_invoker" {
  service  = google_cloudfunctions2_function.disable_social_networks.name
  location = google_cloudfunctions2_function.disable_social_networks.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# Enable required APIs
resource "google_project_service" "cloudfunctions" {
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "cloudrun" {
  service = "run.googleapis.com"
}

resource "google_project_service" "cloudscheduler" {
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
}

# Outputs
output "enable_function_url" {
  description = "URL of the enable function"
  value       = google_cloudfunctions2_function.enable_social_networks.service_config[0].uri
}

output "disable_function_url" {
  description = "URL of the disable function"
  value       = google_cloudfunctions2_function.disable_social_networks.service_config[0].uri
}

output "schedule_summary" {
  description = "Summary of the blocking schedule"
  value       = "Social networks blocked from 8:30 PM to 8:00 AM Central Time"
}