terraform {
  backend "gcs" {
    bucket = "soufianesys-terraform-state" # Update with your GCS bucket name
    prefix = "pairreader/staging"
  }
}
