resource "google_artifact_registry_repository" "pairreader" {
  location      = var.region
  repository_id = "pairreader-${var.environment}"
  description   = "Docker repository for PairReader application (${var.environment} environment)"
  format        = "DOCKER"
}
