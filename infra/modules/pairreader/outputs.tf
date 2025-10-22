output "artifact_registry_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.pairreader.name
}

output "artifact_registry_repository_url" {
  description = "Full URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.pairreader.name}"
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.pairreader_runtime.email
}

output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.pairreader.name
}

output "cloud_run_service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.pairreader.uri
}

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    anthropic_api_key     = google_secret_manager_secret.anthropic_api_key.secret_id
    chainlit_auth_secret  = google_secret_manager_secret.chainlit_auth_secret.secret_id
    langsmith_api_key     = google_secret_manager_secret.langsmith_api_key.secret_id
  }
}
