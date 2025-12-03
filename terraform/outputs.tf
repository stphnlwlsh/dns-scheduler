output "delivery_pipeline_id" {
  description = "The ID of the Cloud Deploy delivery pipeline"
  value       = google_clouddeploy_delivery_pipeline.pipeline.uid
}

output "service_url" {
  description = "The Google Cloud Run Service URL"
  value       = google_cloud_run_v2_service.default.uri
}

output "deployer_sa_email" {
  value = google_service_account.deployer.email
}
