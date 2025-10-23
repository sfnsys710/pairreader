terraform {
  required_version = ">= 1.10"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# Note: Provider configuration is passed from the environment-level configuration
# No provider block needed here - inherited from root module
