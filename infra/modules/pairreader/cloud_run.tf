resource "google_cloud_run_v2_service" "pairreader" {
  name     = "pairreader-service-${var.environment}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.pairreader_runtime.email

    containers {
      # Initial placeholder image - will be updated by CI/CD
      image = "gcr.io/cloudrun/hello"

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          memory = var.memory
        }
      }

      # Environment variables for LangSmith
      env {
        name  = "LANGSMITH_TRACING"
        value = "true"
      }

      env {
        name  = "LANGSMITH_ENDPOINT"
        value = "https://api.smith.langchain.com"
      }

      env {
        name  = "LANGSMITH_PROJECT"
        value = "pairreader"
      }

      # Secrets mounted as environment variables
      # These reference the secrets created in secrets.tf
      env {
        name = "ANTHROPIC_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.anthropic_api_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CHAINLIT_AUTH_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.chainlit_auth_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "LANGSMITH_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.langsmith_api_key.secret_id
            version = "latest"
          }
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  labels = {
    environment = var.environment
    app         = "pairreader"
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [
      # Allow CI/CD to update the image without Terraform reverting it
      template[0].containers[0].image,
    ]
  }
}

# IAM policy to allow unauthenticated access (if enabled)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.pairreader.name
  location = google_cloud_run_v2_service.pairreader.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
