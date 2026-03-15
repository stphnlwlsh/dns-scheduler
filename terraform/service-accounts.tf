resource "google_service_account" "app" {
  account_id   = "${var.app_name}-app"
  display_name = "${var.app_name_friendly} Application Service Account"
  description  = "Service account for the Cloud Run Application itself"
  project      = var.project_id
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "cloud_run_agent_art_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_service_account" "builder" {
  account_id                   = "${var.app_name}-builder"
  display_name                 = "${var.app_name_friendly} Builder"
  description                  = "Service account for the cloud build function"
  project                      = var.project_id
  create_ignore_already_exists = true
}

resource "google_service_account" "deployer" {
  account_id   = "${var.app_name}-deployer"
  display_name = "${var.app_name_friendly} Deployer"
  description  = "Service account for the cloud deploy function"
  project      = var.project_id
}

resource "google_service_account" "invoker" {
  account_id   = "${var.app_name}-invoker"
  display_name = "${var.app_name_friendly} Job Invoker"
  description  = "Service account for the cloud scheduler function"
  project      = var.project_id
}

resource "google_project_iam_member" "app_roles" {
  for_each = toset(local.app_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "builder_roles" {
  for_each = toset(local.builder_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.builder.email}"
}

resource "google_project_iam_member" "deployer_roles" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "invoker_roles" {
  for_each = toset(local.invoker_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.invoker.email}"
}

locals {
  app_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudtrace.agent",
    "roles/monitoring.metricWriter",
  ]
}

locals {
  builder_roles = [
    "roles/artifactregistry.repoAdmin",
    "roles/artifactregistry.writer",
    "roles/clouddeploy.operator",
    "roles/config.agent",
    "roles/run.admin",
    "roles/run.developer",
    "roles/run.serviceAgent",
    "roles/cloudscheduler.admin",
    "roles/logging.logWriter",
    "roles/privilegedaccessmanager.projectServiceAgent",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
  ]
}

locals {
  deployer_roles = [
    "roles/artifactregistry.reader",
    "roles/iam.serviceAccountUser",
    "roles/clouddeploy.jobRunner",
    "roles/clouddeploy.releaser",
    "roles/run.developer"
  ]
}

locals {
  invoker_roles = [
    "roles/run.invoker"
  ]
}
