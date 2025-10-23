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
          cpu    = var.cpu
          memory = var.memory
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  lifecycle {
    ignore_changes = [
      # Allow CI/CD to update the image without Terraform reverting it
      template[0].containers[0].image,
    ]
  }
}
