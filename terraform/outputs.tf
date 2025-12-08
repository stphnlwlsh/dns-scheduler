output "service_url" {
  description = "The Google Cloud Run Service URL"
  value       = google_cloud_run_v2_service.default.uri
}
