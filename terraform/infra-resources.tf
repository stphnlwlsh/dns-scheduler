
resource "google_artifact_registry_repository" "repo" {
  project                = var.project_id
  location               = var.location
  repository_id          = "${var.app_name}-repo"
  format                 = "DOCKER"
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state = "UNTAGGED"
    }
  }
  cleanup_policies {
    id     = "keep-new-untagged"
    action = "KEEP"
    condition {
      tag_state  = "UNTAGGED"
      newer_than = "604800s"
    }
  }
  cleanup_policies {
    id     = "keep-5"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

resource "google_cloudbuild_trigger" "main_trigger" {
  location        = var.location
  name            = "${var.app_name}-main-app"
  description     = "application changes only"
  service_account = google_service_account.builder.id
  filename        = "cloudbuild-app.yaml"
  substitutions = {
    _IMAGE_NAME        = var.app_name
    _PIPELINE_NAME     = google_clouddeploy_delivery_pipeline.pipeline.name
    _REPO_NAME         = google_artifact_registry_repository.repo.name
    _DOMAIN_DENY_LIST  = var.domain_deny_list
    _DOMAIN_ALLOW_LIST = var.domain_allow_list
  }

  repository_event_config {
    repository = "projects/${var.project_id}/locations/${var.location}/connections/GitLab/repositories/connectwithawalsh-${var.app_name}"
    push {
      branch = "^main$"
    }
  }
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  project  = var.project_id
  location = var.location
  name     = "${var.app_name}-pipeline"

  serial_pipeline {
    stages {
      target_id = "prod"
    }
  }
}

resource "google_clouddeploy_target" "prod" {
  project  = var.project_id
  location = var.location
  name     = "prod"

  run {
    location = "projects/${var.project_id}/locations/${var.location}"
  }

  require_approval = true

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = google_service_account.deployer.email
    artifact_storage = "gs://${google_clouddeploy_delivery_pipeline.pipeline.uid}_clouddeploy"
  }
}

#TODO cloud build triggers
