resource "google_secret_manager_secret" "otel_config" {
  secret_id = "OTEL_COLLECTOR_CONFIG"
  project   = var.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "otel_config" {
  secret      = google_secret_manager_secret.otel_config.id
  secret_data = file("${path.module}/../otel-config.yaml")
}

resource "google_cloud_run_v2_service" "default" {
  name     = var.app_name
  location = var.location
  project  = var.project_id

  template {
    timeout         = "300s"
    service_account = google_service_account.app.email
    containers {
      image = "${var.location}-docker.pkg.dev/${var.project_id}/${var.app_name}-repo/${var.app_name}:${var.image_tag}"
      ports {
        container_port = 8080
      }
      env {
        name = "NEXTDNS_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "NEXTDNS_API_KEY"
            version = "latest"
          }
        }
      }
      env {
        name = "NEXTDNS_PROFILE_ID_0"
        value_source {
          secret_key_ref {
            secret  = "NEXTDNS_PROFILE_ID_0"
            version = "latest"
          }
        }
      }
      env {
        name = "NEXTDNS_PROFILE_ID_1"
        value_source {
          secret_key_ref {
            secret  = "NEXTDNS_PROFILE_ID_1"
            version = "latest"
          }
        }
      }
      env {
        name  = "DOMAIN_DENY_LIST"
        value = var.domain_deny_list
      }
      env {
        name  = "DOMAIN_ALLOW_LIST"
        value = var.domain_allow_list
      }
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
    }
    containers {
      name  = "otel-collector"
      image = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:0.143.0"
      args  = ["--config=/etc/otelcol-google/config.yaml"]
      volume_mounts {
        name       = "otel-config"
        mount_path = "/etc/otelcol-google"
      }
    }
    volumes {
      name = "otel-config"
      secret {
        secret = google_secret_manager_secret.otel_config.secret_id
        items {
          version = "latest"
          path    = "config.yaml"
        }
      }
    }
  }
}

resource "google_cloud_scheduler_job" "enable_social_networks" {
  name             = "${var.app_name}-enable-schedule"
  description      = "Enable social networks blocking at 8:30 PM Central Time"
  schedule         = "30 20 * * *" # 8:30 PM daily
  time_zone        = "America/Chicago"
  attempt_deadline = "60s"

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_v2_service.default.uri}/enable"

    oidc_token {
      service_account_email = google_service_account.invoker.email
    }
  }
}

# Cloud Scheduler job to disable social networks blocking at 8:00 AM CT
resource "google_cloud_scheduler_job" "disable_social_networks" {
  name             = "${var.app_name}-disable-schedule"
  description      = "Disable social networks blocking at 8:00 AM Central Time"
  schedule         = "0 8 * * *" # 8:00 AM daily
  time_zone        = "America/Chicago"
  attempt_deadline = "60s"

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_v2_service.default.uri}/disable"

    oidc_token {
      service_account_email = google_service_account.invoker.email
    }
  }
}
