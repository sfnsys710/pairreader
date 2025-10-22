# Secret Manager secrets for PairReader application

resource "google_secret_manager_secret" "anthropic_api_key" {
  secret_id = "ANTHROPIC_API_KEY"

  replication {
    auto {}
  }

  labels = {
    app        = "pairreader"
    managed_by = "terraform"
  }
}

resource "google_secret_manager_secret_version" "anthropic_api_key" {
  secret      = google_secret_manager_secret.anthropic_api_key.id
  secret_data = var.anthropic_api_key
}

resource "google_secret_manager_secret" "chainlit_auth_secret" {
  secret_id = "CHAINLIT_AUTH_SECRET"

  replication {
    auto {}
  }

  labels = {
    app        = "pairreader"
    managed_by = "terraform"
  }
}

resource "google_secret_manager_secret_version" "chainlit_auth_secret" {
  secret      = google_secret_manager_secret.chainlit_auth_secret.id
  secret_data = var.chainlit_auth_secret
}

resource "google_secret_manager_secret" "langsmith_api_key" {
  secret_id = "LANGSMITH_API_KEY"

  replication {
    auto {}
  }

  labels = {
    app        = "pairreader"
    managed_by = "terraform"
  }
}

resource "google_secret_manager_secret_version" "langsmith_api_key" {
  secret      = google_secret_manager_secret.langsmith_api_key.id
  secret_data = var.langsmith_api_key
}
