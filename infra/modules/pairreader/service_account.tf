resource "google_service_account" "pairreader_runtime" {
  account_id   = "pairreader-runtime-${var.environment}"
  display_name = "PairReader Cloud Run Service Account (${var.environment})"
  description  = "Service account for PairReader Cloud Run service in ${var.environment} environment"
}

# Grant Secret Manager Secret Accessor role to the service account
# This is required for Cloud Run to access secrets via --set-secrets
resource "google_secret_manager_secret_iam_member" "anthropic_api_key_accessor" {
  secret_id = google_secret_manager_secret.anthropic_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "chainlit_auth_secret_accessor" {
  secret_id = google_secret_manager_secret.chainlit_auth_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "langsmith_api_key_accessor" {
  secret_id = google_secret_manager_secret.langsmith_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pairreader_runtime.email}"
}
