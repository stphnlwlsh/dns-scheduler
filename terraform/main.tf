
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

variable "image_tag" {
  description = "The tag for the Docker image"
  type        = string
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

variable "nextdns_profile_id_2" {
  description = "NextDNS Profile ID for second profile (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# Look up the Artifact Registry repository to see if it exists
data "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "dns-scheduler-repo"
}

# This resource will only be created if the repository does not exist
resource "time_sleep" "wait_for_repo_creation" {
  create_duration = "1s"

  triggers = {
    repo_id = data.google_artifact_registry_repository.repo.id
  }

  # This is a trick to run a command only when the data source is not found
  provisioner "local-exec" {
    command = <<EOT
      if [ -z "${data.google_artifact_registry_repository.repo.id}" ]; then
        gcloud artifacts repositories create dns-scheduler-repo \
          --project=${var.project_id} \
          --location=${var.region} \
          --repository-format=docker
      fi
    EOT
  }
}


# Cloud Deploy Delivery Pipeline
resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  project  = var.project_id
  location = var.region
  name     = "dns-scheduler-pipeline"

  serial_pipeline {
    stages {
      target_id = "prod"
    }
  }
}

# Cloud Deploy Target for Production
resource "google_clouddeploy_target" "prod" {
  project  = var.project_id
  location = var.region
  name     = "prod"

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  require_approval = true
}

# Grant the Cloud Build service account permission to create Cloud Deploy releases
resource "google_project_iam_member" "clouddeploy_releaser" {
  project = var.project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant the Cloud Deploy service account permission to deploy to Cloud Run
resource "google_project_iam_member" "clouddeploy_runner" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

data "google_project" "project" {}

resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Service account for Cloud Scheduler
resource "google_service_account" "scheduler" {
  account_id   = "dns-scheduler-invoker"
  display_name = "DNS Scheduler Invoker"
}

# IAM policy to allow scheduler to invoke Cloud Run
resource "google_cloud_run_service_iam_member" "scheduler_invoker" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
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
    uri         = "${google_cloud_run_v2_service.default.uri}/enable"

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
    uri         = "${google_cloud_run_v2_service.default.uri}/disable"

    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# Enable required APIs
resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "cloudscheduler" {
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "clouddeploy" {
  service = "clouddeploy.googleapis.com"
}

output "delivery_pipeline_id" {
  description = "The ID of the Cloud Deploy delivery pipeline"
  value       = google_clouddeploy_delivery_pipeline.pipeline.uid
}
