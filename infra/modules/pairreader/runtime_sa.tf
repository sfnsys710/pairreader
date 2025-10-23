resource "google_service_account" "pairreader_runtime" {
  account_id   = "pairreader-runtime-${var.environment}"
  display_name = "PairReader Cloud Run Service Account (${var.environment})"
  description  = "Service account for PairReader Cloud Run service in ${var.environment} environment"
}

# Grant Secret Manager Secret Accessor role to the service account
# This is required for Cloud Run to access secrets via --set-secrets
# Note: Secrets are managed manually (see secret_manager.tf), we just grant access here
resource "google_secret_manager_secret_iam_member" "anthropic_api_key_accessor" {
  secret_id = "ANTHROPIC_API_KEY"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "chainlit_auth_secret_accessor" {
  secret_id = "CHAINLIT_AUTH_SECRET"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "langsmith_api_key_accessor" {
  secret_id = "LANGSMITH_API_KEY"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}

# IAM policy to allow unauthenticated access to Cloud Run (if enabled)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.pairreader.name
  location = google_cloud_run_v2_service.pairreader.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
