variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude"
  type        = string
  sensitive   = true
}

variable "chainlit_auth_secret" {
  description = "Chainlit authentication secret"
  type        = string
  sensitive   = true
}

variable "langsmith_api_key" {
  description = "LangSmith API key for tracing"
  type        = string
  sensitive   = true
}

variable "memory" {
  description = "Memory allocation for Cloud Run service"
  type        = string
  default     = "4Gi"
}

variable "port" {
  description = "Container port for Cloud Run service"
  type        = number
  default     = 8000
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to Cloud Run service"
  type        = bool
  default     = true
}
