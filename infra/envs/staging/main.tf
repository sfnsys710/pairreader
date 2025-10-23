# IMPORTANT: When updating Terraform or provider versions, also update:
# - infra/envs/dev/main.tf (Terraform required_version & provider version)
# - infra/envs/prod/main.tf (Terraform required_version & provider version)
# - infra/.terraform-version (CI/CD reads this for terraform CLI version)
terraform {
  required_version = ">= 1.10"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  backend "gcs" {
    bucket = "sfn-terraform-state-staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "pairreader" {
  source = "../../modules/pairreader"

  project_id  = var.project_id
  region      = var.region
  environment = "staging"

  # Cloud Run configuration (hardcoded for staging environment)
  memory                = "4Gi"
  cpu                   = "2"
  port                  = 8000
  allow_unauthenticated = true
}

# Variables from shared terraform.tfvars (at infra/ root)
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

# Outputs
output "artifact_registry_repository_url" {
  description = "Artifact Registry repository URL"
  value       = module.pairreader.artifact_registry_repository_url
}

output "service_account_email" {
  description = "Service account email"
  value       = module.pairreader.service_account_email
}

output "cloud_run_service_url" {
  description = "Cloud Run service URL"
  value       = module.pairreader.cloud_run_service_url
}
