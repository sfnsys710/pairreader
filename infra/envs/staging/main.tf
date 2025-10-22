terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "soufianesys"
  region  = "europe-southwest1"
}

module "pairreader" {
  source = "../../modules/pairreader"

  project_id  = "soufianesys"
  region      = "europe-southwest1"
  environment = "staging"

  # Secrets from shared terraform.tfvars (at infra/ root)
  anthropic_api_key    = var.anthropic_api_key
  chainlit_auth_secret = var.chainlit_auth_secret
  langsmith_api_key    = var.langsmith_api_key

  # Cloud Run configuration
  memory                = var.memory
  port                  = var.port
  allow_unauthenticated = var.allow_unauthenticated
}

# Variables for secrets (populated from infra/terraform.tfvars)
variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
}

variable "chainlit_auth_secret" {
  description = "Chainlit auth secret"
  type        = string
  sensitive   = true
}

variable "langsmith_api_key" {
  description = "LangSmith API key"
  type        = string
  sensitive   = true
}

# Cloud Run configuration variables
variable "memory" {
  description = "Cloud Run memory allocation"
  type        = string
  default     = "4Gi"
}

variable "port" {
  description = "Cloud Run container port"
  type        = number
  default     = 8000
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access"
  type        = bool
  default     = true
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
