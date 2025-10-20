# PairReader Terraform Infrastructure Guide

## Executive Summary

This guide documents PairReader's Infrastructure-as-Code (IaC) implementation using Terraform. It provides a production-ready approach to managing GCP resources with:

- **DRY Principles**: Reusable modules eliminate code duplication
- **Environment Separation**: Dev/Prod isolation with shared module definitions
- **Automated Dev Deployment**: CI applies infrastructure changes automatically
- **Controlled Prod Deployment**: Manual approval gates with two-button promotion
- **State Management**: GCS backend with locking prevents concurrent modifications
- **GitOps Workflow**: All changes tracked in version control

**Key Insight**: Both dev and prod configurations live on `main` branch. CI automatically applies to dev on merge, while prod waits for manual trigger. This eliminates copy-paste and reduces drift.

---

## Table of Contents

1. [Terraform Folder Structure](#terraform-folder-structure)
2. [Critical Best Practices](#critical-best-practices)
3. [Development Workflow](#development-workflow)
4. [Backend Configuration](#backend-configuration)
5. [Module Examples](#module-examples)
6. [CI/CD Implementation](#cicd-implementation)
7. [GitHub Environment Setup](#github-environment-setup)
8. [Step-by-Step Implementation Plan](#step-by-step-implementation-plan)
9. [Two-Button Prod Deployment](#two-button-prod-deployment)
10. [Common Pitfalls](#common-pitfalls)
11. [Troubleshooting](#troubleshooting)

---

## Terraform Folder Structure

```
infra/
├── .gitignore                    # Ignore .terraform/, *.tfstate, sensitive *.tfvars
├── .terraform.lock.hcl           # Version controlled (dependency pinning)
├── README.md                     # Infra documentation
├── TERRAFORM_GUIDE.md            # This file
│
├── scripts/                      # Helper scripts
│   ├── init-dev.sh              # Initialize dev environment
│   ├── init-prod.sh             # Initialize prod environment
│   ├── plan-dev.sh              # Run terraform plan for dev
│   ├── plan-prod.sh             # Run terraform plan for prod
│   └── create-state-bucket.sh   # Create GCS state bucket
│
├── modules/                      # Reusable infrastructure modules (DRY)
│   ├── artifact-registry/
│   │   ├── main.tf              # GAR repository resource
│   │   ├── variables.tf         # Input variables
│   │   ├── outputs.tf           # Outputs (repository_id, etc.)
│   │   └── README.md            # Module documentation
│   │
│   ├── cloud-run/
│   │   ├── main.tf              # Cloud Run service resource
│   │   ├── variables.tf         # Input variables (memory, cpu, etc.)
│   │   ├── outputs.tf           # Outputs (service_url, etc.)
│   │   └── README.md
│   │
│   ├── gcs-bucket/
│   │   ├── main.tf              # GCS bucket resource
│   │   ├── variables.tf         # Input variables
│   │   ├── outputs.tf           # Outputs (bucket_name, url)
│   │   └── README.md
│   │
│   ├── service-account/
│   │   ├── main.tf              # Service account + IAM
│   │   ├── variables.tf         # Input variables
│   │   ├── outputs.tf           # Outputs (email, member)
│   │   └── README.md
│   │
│   └── secret-manager/
│       ├── main.tf              # Secret references (not values)
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
│
└── environments/                 # Environment-specific configurations
    ├── dev/
    │   ├── backend.tf           # GCS backend config (dev state bucket)
    │   ├── provider.tf          # GCP provider configuration
    │   ├── versions.tf          # Terraform version constraints
    │   ├── variables.tf         # Variable definitions
    │   ├── dev.auto.tfvars      # Dev-specific values (committed)
    │   ├── secrets.tfvars       # Sensitive values (NOT committed, CI provides)
    │   ├── outputs.tf           # Environment outputs
    │   └── main.tf              # Main orchestration (calls modules)
    │
    └── prod/
        ├── backend.tf           # GCS backend config (prod state bucket)
        ├── provider.tf          # GCP provider configuration
        ├── versions.tf          # Terraform version constraints
        ├── variables.tf         # Variable definitions (same as dev)
        ├── prod.auto.tfvars     # Prod-specific values (committed)
        ├── secrets.tfvars       # Sensitive values (NOT committed, CI provides)
        ├── outputs.tf           # Environment outputs
        └── main.tf              # Main orchestration (same structure as dev)
```

### Key Design Decisions

1. **Modules Directory**: Single source of truth for resource definitions
   - Each module is self-contained and reusable
   - Changes to modules automatically affect both environments

2. **Environments Directory**: Configuration, not code
   - `main.tf` files are nearly identical (both call same modules)
   - Only `.tfvars` files differ (environment-specific values)
   - This pattern eliminates copy-paste

3. **`.auto.tfvars` Naming**: Automatically loaded by Terraform
   - `dev.auto.tfvars` / `prod.auto.tfvars`: Non-sensitive defaults (committed)
   - `secrets.tfvars`: Sensitive values (gitignored, passed via CI)

4. **Separate Backend Configs**: Each environment has its own state bucket
   - Prevents accidental cross-environment changes
   - Enables parallel operations (no state locking conflicts)

---

## Critical Best Practices

### State Management ✅

- [ ] **GCS backend configured** with state locking enabled
- [ ] **Separate state buckets** for dev and prod
- [ ] **State bucket versioning** enabled (rollback capability)
- [ ] **`.terraform.lock.hcl` committed** to version control
- [ ] **Never commit `.tfstate` files** to git

### Security ✅

- [ ] **Sensitive `.tfvars` in `.gitignore`** (API keys, passwords)
- [ ] **Use Secret Manager** for runtime secrets (not Terraform variables)
- [ ] **Separate service accounts** for dev and prod
- [ ] **Least-privilege IAM** (only grant necessary permissions)
- [ ] **Never hardcode** project IDs or service account emails in workflows

### Development Workflow ✅

- [ ] **Plan before apply** (always review changes)
- [ ] **Terraform validate** in CI (catch syntax errors)
- [ ] **terraform fmt -check** enforced in CI
- [ ] **Never auto-apply to prod** (manual trigger only)
- [ ] **GitHub Environment protection** for prod (manual approval)

### Code Organization ✅

- [ ] **Use modules** for all reusable resources
- [ ] **DRY principle**: Update both dev and prod in same PR
- [ ] **Version constraints** in `versions.tf` (pin Terraform version)
- [ ] **Clear variable names** (use `description` field)
- [ ] **Document modules** with README.md

### CI/CD Integration ✅

- [ ] **Separate infra and app workflows** (different concerns)
- [ ] **Use Terraform outputs** to pass values to app deployment
- [ ] **Plan output visible** in PR comments
- [ ] **State locking prevents** concurrent CI runs
- [ ] **Fail fast**: Validation runs before tests/builds

---

## Development Workflow

### The Three-Phase Cycle

Every feature requiring infrastructure changes follows this pattern:

#### **PHASE 1: Infrastructure Development** 🏗️

```
Branch: feature/add-gcs-storage

├─ 1. Create or update module (if new resource type)
│     infra/modules/gcs-bucket/
│     ├── main.tf
│     ├── variables.tf
│     └── outputs.tf
│
├─ 2. Update BOTH environments in SAME PR
│     infra/environments/dev/main.tf      (add module call)
│     infra/environments/prod/main.tf     (add module call - same structure)
│
├─ 3. Configure environment-specific values
│     infra/environments/dev/dev.auto.tfvars    (dev settings)
│     infra/environments/prod/prod.auto.tfvars  (prod settings)
│
├─ 4. Test locally (dev only)
│     cd infra/environments/dev
│     terraform init
│     terraform plan  # ← Experiment here, iterate
│
├─ 5. Push → PR to main
│     CI runs:
│     ├─ terraform fmt -check
│     ├─ terraform validate
│     └─ terraform plan (dev) → Output appears in PR comment
│
├─ 6. Review plan → Merge to main
│     CI automatically runs:
│     └─ terraform apply (dev)
│     ✅ Dev infrastructure updated
│
└─ 7. Verify dev infra works
      gcloud storage ls gs://pairreader-*-dev
      gcloud run services list --filter="pairreader-service-dev"
```

**Key Insight**: You edit prod files in the SAME PR, but CI only applies to dev. Prod changes sit dormant on `main` until manually triggered.

#### **PHASE 2: Application Development** 🚀

```
Branch: feature/use-gcs-storage

├─ 1. Update app code to use new infrastructure
│     src/pairreader/vectorestore.py  (use GCS bucket)
│     compose.yml                      (add GCS credentials)
│
├─ 2. Test locally with Docker
│     docker compose build
│     docker compose up
│     # Test: Upload document → Verify stored in GCS bucket
│
├─ 3. Push → PR to main
│     CI runs:
│     ├─ pre-commit hooks
│     ├─ pytest (unit tests)
│     └─ docker build (validate Dockerfile)
│
├─ 4. Review → Merge to main
│     CI automatically:
│     ├─ Builds Docker image (with GCS integration)
│     ├─ Pushes to Artifact Registry
│     └─ Deploys to Cloud Run (dev)
│
└─ 5. Verify dev app works end-to-end
      curl https://pairreader-service-dev-xxx.run.app
      # Upload docs via UI, verify data in GCS bucket
```

#### **PHASE 3: Production Promotion** 🎯

```
No new branches. No new PRs. No copy-paste. Just two clicks.

├─ 1. Navigate to GitHub Actions
│     https://github.com/your-org/pairreader/actions
│
├─ 2. Click "Terraform Apply to Prod" workflow
│     └─ Select "Run workflow" dropdown
│         ├─ Branch: main
│         ├─ Environment: prod
│         └─ Click "Run workflow" button
│
│     Workflow executes:
│     ├─ terraform init (prod)
│     ├─ terraform plan (prod) → Shows diff in logs
│     ├─ ⏸️  Pauses for manual approval (GitHub Environment protection)
│     ├─ Review plan output → Click "Approve deployment"
│     └─ terraform apply (prod)
│     ✅ Prod infrastructure updated
│
├─ 3. Click "Deploy App to Prod" workflow
│     └─ Select "Run workflow" dropdown
│         ├─ Branch: main
│         ├─ Environment: prod
│         ├─ Image tag: latest (or specific SHA)
│         └─ Click "Run workflow" button
│
│     Workflow executes:
│     ├─ Builds Docker image (from main branch)
│     ├─ Pushes to Artifact Registry (prod tag)
│     ├─ ⏸️  Pauses for manual approval
│     ├─ Click "Approve deployment"
│     └─ gcloud run deploy (prod)
│     ✅ Prod app deployed
│
└─ 4. Verify prod works
      curl https://pairreader-service-prod-xxx.run.app
      # Smoke test: Upload doc, ask question, verify response
```

**Total: 2 branches, 2 PRs, 2 merges, 2 clicks.** ✅

### Why This Works

1. **No Copy-Paste**: Both environments updated in Phase 1 PR
2. **Dormant Changes**: Prod config on `main` waits for manual trigger
3. **Clear Separation**: Infra changes separate from app changes
4. **Fast Iteration**: Dev auto-applies for rapid feedback
5. **Prod Safety**: Manual approval gates prevent accidents

---

## Backend Configuration

### GCS State Bucket Setup

**Prerequisites**: Create state buckets BEFORE running `terraform init`

#### Create Dev State Bucket

```bash
# Run this ONCE per environment (manual setup)
gcloud storage buckets create gs://pairreader-terraform-state-dev \
  --project=YOUR_PROJECT_ID \
  --location=us-central1 \
  --uniform-bucket-level-access

# Enable versioning (rollback capability)
gcloud storage buckets update gs://pairreader-terraform-state-dev \
  --versioning
```

#### Create Prod State Bucket

```bash
gcloud storage buckets create gs://pairreader-terraform-state-prod \
  --project=YOUR_PROJECT_ID \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://pairreader-terraform-state-prod \
  --versioning
```

### Backend Configuration Files

#### `infra/environments/dev/backend.tf`

```hcl
terraform {
  backend "gcs" {
    bucket  = "pairreader-terraform-state-dev"
    prefix  = "terraform/state"

    # Note: GCS automatically provides state locking via object metadata
    # No additional configuration needed (unlike AWS which requires DynamoDB)
  }
}
```

#### `infra/environments/prod/backend.tf`

```hcl
terraform {
  backend "gcs" {
    bucket  = "pairreader-terraform-state-prod"
    prefix  = "terraform/state"
  }
}
```

### State Locking Behavior

GCS backend uses **object metadata** for locking:
- Lock acquired: Creates `.tflock` metadata on state object
- Lock released: Removes metadata after operation completes
- Lock conflict: Terraform waits or fails (depending on `-lock-timeout`)

**Important**: This prevents two CI jobs from applying simultaneously.

---

## Module Examples

### Module 1: GCS Bucket

#### `infra/modules/gcs-bucket/main.tf`

```hcl
resource "google_storage_bucket" "this" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.location
  force_destroy = var.force_destroy

  uniform_bucket_level_access {
    enabled = true
  }

  versioning {
    enabled = var.versioning_enabled
  }

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "service_account_access" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = var.service_account_member
}
```

#### `infra/modules/gcs-bucket/variables.tf`

```hcl
variable "bucket_name" {
  description = "Name of the GCS bucket (must be globally unique)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GCS bucket location (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

variable "force_destroy" {
  description = "Allow deletion of non-empty bucket (use true for dev, false for prod)"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Number of days to retain objects before deletion"
  type        = number
  default     = 30
}

variable "service_account_member" {
  description = "Service account member (e.g., serviceAccount:sa@project.iam.gserviceaccount.com)"
  type        = string
}
```

#### `infra/modules/gcs-bucket/outputs.tf`

```hcl
output "bucket_name" {
  description = "Name of the created bucket"
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "GCS URL of the bucket"
  value       = google_storage_bucket.this.url
}

output "bucket_self_link" {
  description = "Self-link of the bucket"
  value       = google_storage_bucket.this.self_link
}
```

### Module 2: Cloud Run Service

#### `infra/modules/cloud-run/main.tf`

```hcl
resource "google_cloud_run_v2_service" "this" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    service_account = var.service_account_email

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      ports {
        container_port = var.port
      }

      # Environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables from Secret Manager
      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Allow unauthenticated access (modify for production)
resource "google_cloud_run_v2_service_iam_member" "noauth" {
  count = var.allow_unauthenticated ? 1 : 0

  location = google_cloud_run_v2_service.this.location
  project  = google_cloud_run_v2_service.this.project
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

#### `infra/modules/cloud-run/variables.tf`

```hcl
variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run service"
  type        = string
}

variable "image" {
  description = "Docker image URL (e.g., gcr.io/project/image:tag)"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Cloud Run runtime"
  type        = string
}

variable "cpu" {
  description = "CPU allocation (e.g., '1', '2', '4')"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation (e.g., '512Mi', '2Gi', '4Gi')"
  type        = string
  default     = "512Mi"
}

variable "port" {
  description = "Container port"
  type        = number
  default     = 8000
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "env_vars" {
  description = "Environment variables (plain text)"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Environment variables from Secret Manager"
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access"
  type        = bool
  default     = false
}
```

#### `infra/modules/cloud-run/outputs.tf`

```hcl
output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.name
}

output "service_id" {
  description = "Full service ID"
  value       = google_cloud_run_v2_service.this.id
}
```

### Module 3: Service Account

#### `infra/modules/service-account/main.tf`

```hcl
resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

# IAM role bindings
resource "google_project_iam_member" "roles" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}
```

#### `infra/modules/service-account/variables.tf`

```hcl
variable "account_id" {
  description = "Service account ID (e.g., 'pairreader-runtime')"
  type        = string
}

variable "display_name" {
  description = "Human-readable name"
  type        = string
}

variable "description" {
  description = "Description of service account purpose"
  type        = string
  default     = ""
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_roles" {
  description = "List of IAM roles to grant at project level"
  type        = list(string)
  default     = []
}
```

#### `infra/modules/service-account/outputs.tf`

```hcl
output "email" {
  description = "Service account email"
  value       = google_service_account.this.email
}

output "member" {
  description = "Service account member (for IAM bindings)"
  value       = "serviceAccount:${google_service_account.this.email}"
}

output "id" {
  description = "Service account ID"
  value       = google_service_account.this.id
}
```

### Environment Configuration Example

#### `infra/environments/dev/main.tf`

```hcl
# Service Account for Cloud Run runtime
module "runtime_service_account" {
  source = "../../modules/service-account"

  account_id   = "${var.service_name}-runtime"
  display_name = "PairReader Cloud Run Runtime (Dev)"
  description  = "Service account for PairReader Cloud Run service in dev environment"
  project_id   = var.project_id

  project_roles = [
    "roles/secretmanager.secretAccessor",  # Access secrets
    "roles/logging.logWriter",             # Write logs
    "roles/cloudtrace.agent",              # Send traces
  ]
}

# GCS Bucket for ChromaDB data
module "chromadb_storage" {
  source = "../../modules/gcs-bucket"

  bucket_name             = "${var.service_name}-chromadb-${var.environment}"
  project_id              = var.project_id
  location                = var.region
  force_destroy           = var.storage_force_destroy
  versioning_enabled      = var.storage_versioning
  retention_days          = var.storage_retention_days
  service_account_member  = module.runtime_service_account.member
}

# Cloud Run Service
module "cloud_run_service" {
  source = "../../modules/cloud-run"

  service_name           = "${var.service_name}-${var.environment}"
  project_id             = var.project_id
  region                 = var.region
  image                  = var.image  # Placeholder, overridden by CI
  service_account_email  = module.runtime_service_account.email

  cpu           = var.cloud_run_cpu
  memory        = var.cloud_run_memory
  port          = var.cloud_run_port
  min_instances = var.cloud_run_min_instances
  max_instances = var.cloud_run_max_instances

  env_vars = {
    ENVIRONMENT = var.environment
    GCS_BUCKET  = module.chromadb_storage.bucket_name
  }

  secret_env_vars = {
    ANTHROPIC_API_KEY = {
      secret  = "ANTHROPIC_API_KEY" <!-- pragma: allowlist secret -->
      version = "latest"
    }
    CHAINLIT_AUTH_SECRET = {
      secret  = "CHAINLIT_AUTH_SECRET" <!-- pragma: allowlist secret -->
      version = "latest"
    }
    LANGSMITH_API_KEY = {
      secret  = "LANGSMITH_API_KEY" <!-- pragma: allowlist secret -->
      version = "latest"
    }
  }

  allow_unauthenticated = var.allow_unauthenticated
}
```

#### `infra/environments/dev/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "service_name" {
  description = "Base service name"
  type        = string
  default     = "pairreader-service"
}

variable "image" {
  description = "Docker image URL"
  type        = string
  default     = "us-central1-docker.pkg.dev/PROJECT_ID/pairreader/pairreader-dev:latest"
}

# Cloud Run configuration
variable "cloud_run_cpu" {
  description = "Cloud Run CPU allocation"
  type        = string
}

variable "cloud_run_memory" {
  description = "Cloud Run memory allocation"
  type        = string
}

variable "cloud_run_port" {
  description = "Cloud Run container port"
  type        = number
  default     = 8000
}

variable "cloud_run_min_instances" {
  description = "Minimum instances"
  type        = number
}

variable "cloud_run_max_instances" {
  description = "Maximum instances"
  type        = number
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access"
  type        = bool
}

# Storage configuration
variable "storage_force_destroy" {
  description = "Allow deletion of non-empty bucket"
  type        = bool
}

variable "storage_versioning" {
  description = "Enable object versioning"
  type        = bool
}

variable "storage_retention_days" {
  description = "Object retention days"
  type        = number
}
```

#### `infra/environments/dev/dev.auto.tfvars`

```hcl
# Project configuration
project_id  = "your-gcp-project-id"
region      = "us-central1"
environment = "dev"

# Cloud Run configuration
cloud_run_cpu           = "1"
cloud_run_memory        = "4Gi"
cloud_run_min_instances = 0
cloud_run_max_instances = 5
allow_unauthenticated   = true  # Dev only

# Storage configuration
storage_force_destroy    = true   # OK to delete dev data
storage_versioning       = false  # Not critical for dev
storage_retention_days   = 7      # Short retention
```

#### `infra/environments/prod/prod.auto.tfvars`

```hcl
# Project configuration
project_id  = "your-gcp-project-id"
region      = "us-central1"
environment = "prod"

# Cloud Run configuration
cloud_run_cpu           = "2"
cloud_run_memory        = "8Gi"
cloud_run_min_instances = 1      # Always warm
cloud_run_max_instances = 20
allow_unauthenticated   = false  # Require auth

# Storage configuration
storage_force_destroy    = false  # Protect prod data
storage_versioning       = true   # Enable for safety
storage_retention_days   = 90     # Long retention
```

#### `infra/environments/dev/outputs.tf`

```hcl
output "service_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run_service.service_url
}

output "service_account_email" {
  description = "Runtime service account email"
  value       = module.runtime_service_account.email
}

output "chromadb_bucket_name" {
  description = "ChromaDB storage bucket name"
  value       = module.chromadb_storage.bucket_name
}
```

---

## CI/CD Implementation

### Workflow 1: Terraform CI/CD

**File**: `.github/workflows/terraform-cicd.yml`

```yaml
name: Terraform CI/CD

on:
  pull_request:
    paths:
      - 'infra/**'
    branches:
      - main

  push:
    branches:
      - main
    paths:
      - 'infra/**'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy (prod only)'
        required: true
        type: choice
        options:
          - prod

env:
  TF_VERSION: '1.7.0'
  TERRAFORM_WORKING_DIR_DEV: infra/environments/dev
  TERRAFORM_WORKING_DIR_PROD: infra/environments/prod

jobs:
  # ============================================
  # JOB 1: Validation (on PR)
  # ============================================
  terraform-validate:
    name: Validate & Plan (Dev)
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    environment: gcp-dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to Google Cloud
        run: |
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}

      - name: Terraform Format Check
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform fmt -check -recursive ../../

      - name: Terraform Init
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform init

      - name: Terraform Validate
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: |
          terraform plan -no-color -out=tfplan
          terraform show -no-color tfplan > plan-output.txt
        continue-on-error: true

      - name: Upload Plan Output
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan-dev
          path: ${{ env.TERRAFORM_WORKING_DIR_DEV }}/plan-output.txt

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const planPath = '${{ env.TERRAFORM_WORKING_DIR_DEV }}/plan-output.txt';
            const plan = fs.readFileSync(planPath, 'utf8');
            const truncated = plan.length > 65000
              ? plan.substring(0, 65000) + '\n\n... (truncated, see artifacts for full output)'
              : plan;

            const header = '## 🏗️ Terraform Plan (Dev Environment)\n\n';
            const footer = '\n\n---\n📝 **Review this plan carefully before merging**';
            const body = `${header}\`\`\`terraform\n${truncated}\n\`\`\`${footer}`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

      - name: Fail if Plan Failed
        if: steps.plan.outcome == 'failure'
        run: exit 1

  # ============================================
  # JOB 2: Apply to Dev (on merge to main)
  # ============================================
  terraform-apply-dev:
    name: Apply to Dev
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: gcp-dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to Google Cloud
        run: |
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}

      - name: Terraform Init
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform init

      - name: Terraform Apply
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform apply -auto-approve

      - name: Output Summary
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: |
          echo "## ✅ Terraform Apply Successful (Dev)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: `\(.value.value)`"' >> $GITHUB_STEP_SUMMARY

  # ============================================
  # JOB 3: Apply to Prod (manual trigger)
  # ============================================
  terraform-apply-prod:
    name: Apply to Prod (Manual)
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
    environment: gcp-prod  # GitHub Environment with protection rules

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to Google Cloud
        run: |
          echo '${{ secrets.SA_PROD }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}

      - name: Terraform Init
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: terraform init

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: |
          terraform plan -no-color -out=tfplan
          terraform show -no-color tfplan

      - name: Terraform Apply
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: terraform apply tfplan

      - name: Output Summary
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: |
          echo "## ✅ Terraform Apply Successful (Prod)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: `\(.value.value)`"' >> $GITHUB_STEP_SUMMARY
```

### Workflow 2: Updated App CI/CD

**File**: `.github/workflows/app-cicd.yml` (updated)

```yaml
name: App CI/CD

env:
  GAR_LOCATION: ${{ vars.GCP_REGION }}
  GAR_REPOSITORY: "pairreader"
  GAR_BASE_IMAGE_NAME: "pairreader"
  CLOUDRUN_BASE_SERVICE_NAME: "pairreader-service"

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
    branches:
      - 'main'
    paths-ignore:
      - 'infra/**'  # Don't trigger on infra changes

  push:
    branches:
      - main
    paths-ignore:
      - 'infra/**'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - prod

jobs:
  authorize:
    name: Authorize PR
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
    steps:
      - name: Authorized
        run: echo "PR authorized to run workflows"

  env-vars:
    name: Extract env vars
    runs-on: ubuntu-latest
    needs: authorize
    outputs:
      PAIRREADER_VERSION: ${{ steps.extract-versions.outputs.PAIRREADER_VERSION }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Extract pairreader version
        id: extract-versions
        run: |
          PAIRREADER_VERSION=$(grep -m 1 '^version = ' pyproject.toml | sed 's/version = "\(.*\)"/\1/')
          echo "PAIRREADER_VERSION = $PAIRREADER_VERSION"
          echo "PAIRREADER_VERSION=$PAIRREADER_VERSION" >> $GITHUB_OUTPUT

  pre-commit:
    name: Pre-commit
    needs: env-vars
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install uv
        uses: astral-sh/setup-uv@v6

      - name: Set up Python
        run: uv python install

      - name: Install dependencies
        run: |
          uv sync --only-group pre-commit
          uv tree --only-group pre-commit

      - name: run pre-commit
        run: uv run --no-sync pre-commit run --all-files

  pytest:
    name: Unit tests
    needs:
      - env-vars
      - pre-commit
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install uv
        uses: astral-sh/setup-uv@v6

      - name: Set up Python
        run: uv python install

      - name: Install dependencies
        run: uv sync --group test

      - name: Run unit tests
        run: uv run pytest -m unit -v

  build-and-deploy-dev:
    name: Build and Deploy to Dev
    runs-on: ubuntu-latest
    needs: pytest
    if: (github.event_name == 'push' && github.ref == 'refs/heads/main') || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'dev')
    environment: gcp-dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        run: |
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}
          rm ${HOME}/gcp-key.json

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.GAR_LOCATION }}-docker.pkg.dev

      - name: Build and Push Docker Image
        run: |
          IMAGE_TAG="${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-dev:${{ github.sha }}"
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG

      - name: Get Service Account from Terraform Output
        id: terraform-output
        working-directory: infra/environments/dev
        run: |
          # Initialize Terraform to read state
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          terraform init

          # Extract outputs
          SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
          echo "SERVICE_ACCOUNT=$SERVICE_ACCOUNT" >> $GITHUB_OUTPUT

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-dev \
            --image=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-dev:${{ github.sha }} \
            --region=${{ env.GAR_LOCATION }} \
            --service-account=${{ steps.terraform-output.outputs.SERVICE_ACCOUNT }} \
            --allow-unauthenticated \
            --memory=4Gi \
            --port=8000 \
            --set-secrets=ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest,CHAINLIT_AUTH_SECRET=CHAINLIT_AUTH_SECRET:latest,LANGSMITH_API_KEY=LANGSMITH_API_KEY:latest \
            --quiet

  build-and-deploy-prod:
    name: Build and Deploy to Prod (Manual)
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
    environment: gcp-prod  # Requires manual approval

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        run: |
          echo '${{ secrets.SA_PROD }}' > ${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}
          rm ${HOME}/gcp-key.json

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.GAR_LOCATION }}-docker.pkg.dev

      - name: Build and Push Docker Image
        run: |
          IMAGE_TAG="${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-prod:${{ github.sha }}"
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG

      - name: Get Service Account from Terraform Output
        id: terraform-output
        working-directory: infra/environments/prod
        run: |
          echo '${{ secrets.SA_PROD }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          terraform init

          SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
          echo "SERVICE_ACCOUNT=$SERVICE_ACCOUNT" >> $GITHUB_OUTPUT

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-prod \
            --image=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-prod:${{ github.sha }} \
            --region=${{ env.GAR_LOCATION }} \
            --service-account=${{ steps.terraform-output.outputs.SERVICE_ACCOUNT }} \
            --no-allow-unauthenticated \
            --memory=8Gi \
            --port=8000 \
            --set-secrets=ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest,CHAINLIT_AUTH_SECRET=CHAINLIT_AUTH_SECRET:latest,LANGSMITH_API_KEY=LANGSMITH_API_KEY:latest \
            --quiet
```

### Key Improvements in App CI/CD

1. **Dynamic Service Account**: Reads from Terraform output instead of hardcoded value
2. **Separate Prod Job**: Manual trigger with approval gate
3. **Path Filters**: Doesn't run on infra changes (separate concern)
4. **Environment-Specific Configs**: Dev uses `allow-unauthenticated`, prod doesn't

---

## GitHub Environment Setup

### Environment: `gcp-dev`

**Settings → Environments → New environment → "gcp-dev"**

**Environment Secrets:**
- `SA`: GCP service account JSON key (dev project)

**Environment Variables:**
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_REGION`: `us-central1` (or your preferred region)

**Protection Rules:**
- ❌ Required reviewers: None (auto-deploy)
- ❌ Wait timer: None
- ✅ Deployment branches: `main` only

### Environment: `gcp-prod`

**Settings → Environments → New environment → "gcp-prod"**

**Environment Secrets:**
- `SA_PROD`: GCP service account JSON key (prod project, different from dev)

**Environment Variables:**
- `GCP_PROJECT_ID`: Your GCP project ID (same or different from dev)
- `GCP_REGION`: `us-central1` (or your preferred region)

**Protection Rules:**
- ✅ Required reviewers: Add yourself (manual approval required)
- ⏱️ Wait timer: 0 minutes (or add delay if desired)
- ✅ Deployment branches: `main` only

**Important**: The "Required reviewers" setting creates a manual approval gate. When prod workflow runs, it pauses and sends notification. You must click "Approve deployment" button.

---

## Step-by-Step Implementation Plan

### Phase 1: Setup Terraform Structure (Week 1)

#### Day 1: Initialize Terraform

1. **Create directory structure**
   ```bash
   mkdir -p infra/{modules,environments/{dev,prod},scripts}
   mkdir -p infra/modules/{gcs-bucket,cloud-run,service-account,artifact-registry}
   ```

2. **Create `.gitignore`**
   ```gitignore
   # Terraform
   **/.terraform/*
   *.tfstate
   *.tfstate.*
   *.tfvars  # Ignore sensitive tfvars (keep *.auto.tfvars)
   !dev.auto.tfvars
   !prod.auto.tfvars
   crash.log
   override.tf
   override.tf.json
   *_override.tf
   *_override.tf.json
   .terraformrc
   terraform.rc

   # Credentials
   **/gcp-key.json
   ```

3. **Create state buckets**
   ```bash
   # Dev bucket
   gcloud storage buckets create gs://pairreader-terraform-state-dev \
     --project=YOUR_PROJECT_ID \
     --location=us-central1 \
     --uniform-bucket-level-access

   gcloud storage buckets update gs://pairreader-terraform-state-dev \
     --versioning

   # Prod bucket
   gcloud storage buckets create gs://pairreader-terraform-state-prod \
     --project=YOUR_PROJECT_ID \
     --location=us-central1 \
     --uniform-bucket-level-access

   gcloud storage buckets update gs://pairreader-terraform-state-prod \
     --versioning
   ```

#### Day 2-3: Create Modules

Copy module code from [Module Examples](#module-examples) section:
- `infra/modules/gcs-bucket/`
- `infra/modules/cloud-run/`
- `infra/modules/service-account/`

#### Day 4-5: Create Environment Configurations

1. **Dev environment** (`infra/environments/dev/`)
   - `backend.tf`
   - `provider.tf`
   - `versions.tf`
   - `variables.tf`
   - `dev.auto.tfvars`
   - `main.tf`
   - `outputs.tf`

2. **Prod environment** (`infra/environments/prod/`)
   - Same files as dev, adjust `backend.tf` to point to prod bucket
   - Adjust `prod.auto.tfvars` with prod-specific values

#### Day 6: Import Existing Resources

If you have existing GCP resources, import them:

```bash
cd infra/environments/dev

# Import service account
terraform import module.runtime_service_account.google_service_account.this \
  projects/YOUR_PROJECT/serviceAccounts/pairreader-runtime@YOUR_PROJECT.iam.gserviceaccount.com

# Import Cloud Run service (if exists)
terraform import module.cloud_run_service.google_cloud_run_v2_service.this \
  projects/YOUR_PROJECT/locations/us-central1/services/pairreader-service-dev
```

#### Day 7: Validate

```bash
cd infra/environments/dev
terraform init
terraform plan  # Should show no changes if imports correct
```

### Phase 2: Setup CI/CD (Week 2)

#### Day 1: Create GitHub Environments

1. Go to GitHub → Settings → Environments
2. Create `gcp-dev` environment (no protection rules)
3. Create `gcp-prod` environment (add yourself as required reviewer)
4. Add secrets and variables to both

#### Day 2-3: Create Terraform CI/CD Workflow

1. Create `.github/workflows/terraform-cicd.yml`
2. Copy code from [Workflow 1: Terraform CI/CD](#workflow-1-terraform-cicd)
3. Test:
   - Create feature branch with trivial change (add comment to `main.tf`)
   - Push → PR → Verify plan appears in comment
   - Don't merge yet

#### Day 4-5: Update App CI/CD Workflow

1. Rename existing `cicd.yml` to `app-cicd.yml`
2. Update with code from [Workflow 2: Updated App CI/CD](#workflow-2-updated-app-cicd)
3. Test:
   - Make trivial app change (update comment in source code)
   - Push → PR → Verify app pipeline runs

#### Day 6: End-to-End Test

1. Merge Terraform PR from Day 2 → Verify dev auto-applies
2. Merge app PR from Day 4 → Verify app auto-deploys to dev
3. Manually trigger prod workflows (don't approve yet, just test pausing)

### Phase 3: Production Migration (Week 3)

#### Day 1: Setup Prod Terraform

```bash
cd infra/environments/prod
terraform init
terraform plan  # Review what will be created
```

#### Day 2: Create Prod Resources

Option 1: Import existing prod resources (if you have them)
```bash
terraform import module.runtime_service_account.google_service_account.this \
  projects/YOUR_PROJECT/serviceAccounts/pairreader-runtime-prod@YOUR_PROJECT.iam.gserviceaccount.com
```

Option 2: Create fresh prod resources via Terraform
```bash
terraform apply
```

#### Day 3-4: Test Prod Deployment

1. Go to GitHub Actions
2. Click "Terraform Apply to Prod" → workflow_dispatch → prod
3. Review plan → Approve → Verify applies successfully
4. Click "Deploy App to Prod" → workflow_dispatch → prod
5. Review → Approve → Verify deploys successfully

#### Day 5: Smoke Test Prod

```bash
# Test prod endpoint
curl https://pairreader-service-prod-XXX.run.app

# Upload test document, verify functionality
```

### Phase 4: Documentation & Cleanup (Week 4)

1. Update `README.md` with Terraform workflow
2. Document two-button prod deployment process
3. Archive old deployment scripts (if any)
4. Train team on new workflow

---

## Two-Button Prod Deployment

### Button 1: Deploy Infrastructure

1. **Navigate to Actions**
   - Go to: `https://github.com/YOUR_ORG/pairreader/actions`

2. **Select Terraform Workflow**
   - Click: "Terraform CI/CD" in left sidebar

3. **Trigger Manual Run**
   - Click: "Run workflow" dropdown (top right)
   - Branch: `main`
   - Environment: `prod`
   - Click: "Run workflow" button

4. **Review Plan**
   - Wait for workflow to reach "Terraform Plan" step
   - Click on workflow run → "Terraform Apply to Prod (Manual)" job
   - Review plan output in logs

5. **Approve Deployment**
   - Yellow banner appears: "This deployment is waiting for approval"
   - Click: "Review deployments" button
   - Check: `gcp-prod`
   - Click: "Approve and deploy"

6. **Verify Success**
   - Wait for green checkmark
   - Review outputs in "Output Summary" step

### Button 2: Deploy Application

1. **Navigate to Actions**
   - Go to: `https://github.com/YOUR_ORG/pairreader/actions`

2. **Select App Workflow**
   - Click: "App CI/CD" in left sidebar

3. **Trigger Manual Run**
   - Click: "Run workflow" dropdown
   - Branch: `main`
   - Environment: `prod`
   - Click: "Run workflow" button

4. **Approve Deployment**
   - Wait for yellow banner
   - Click: "Review deployments" → Approve

5. **Verify Success**
   - Check green checkmark
   - Visit Cloud Run URL to smoke test

**Total Time**: ~5-10 minutes (mostly waiting for Docker build)

---

## Common Pitfalls

### 1. Forgetting to Create State Buckets First

**Error**:
```
Error: Failed to get existing workspaces: querying Cloud Storage failed:
storage: bucket doesn't exist: pairreader-terraform-state-dev
```

**Solution**: Create state buckets BEFORE `terraform init`:
```bash
gcloud storage buckets create gs://pairreader-terraform-state-dev \
  --location=us-central1 --uniform-bucket-level-access
```

### 2. State Locking Conflicts

**Error**:
```
Error acquiring the state lock
Lock Info:
  ID:        abc-123
  Operation: OperationTypeApply
  Who:       github-actions@...
```

**Solution**: Wait for other operation to finish, or force-unlock (dangerous):
```bash
terraform force-unlock abc-123  # Only if sure no other process running
```

### 3. Hardcoded Values in Workflows

**Mistake**:
```yaml
--service-account=pairreader-runtime@soufianesys.iam.gserviceaccount.com  # ❌
```

**Solution**: Use Terraform outputs:
```yaml
SERVICE_ACCOUNT=$(terraform output -raw service_account_email)  # ✅
```

### 4. Drift Between Environments

**Problem**: Dev and prod configs diverge over time

**Solution**: Always update both in same PR. Use modules to enforce consistency.

### 5. Sensitive Data in `.tfvars`

**Mistake**:
```hcl
# dev.auto.tfvars
anthropic_api_key = "sk-ant-..." # ❌ Committed to git <!-- pragma: allowlist secret -->
```

**Solution**: Use separate `secrets.tfvars` (gitignored) or Secret Manager.

### 6. Missing Provider Credentials in CI

**Error**:
```
Error: google: could not find default credentials
```

**Solution**: Ensure `GOOGLE_APPLICATION_CREDENTIALS` set in workflow:
```yaml
- name: Authenticate to Google Cloud
  run: |
    echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
    export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
```

### 7. Terraform Version Mismatch

**Error**:
```
Error: Unsupported Terraform Core version
```

**Solution**: Pin version in `versions.tf` and workflow:
```hcl
terraform {
  required_version = "~> 1.7.0"
}
```

```yaml
env:
  TF_VERSION: '1.7.0'
```

---

## Troubleshooting

### Debug Terraform Plan

```bash
# Enable verbose logging
export TF_LOG=DEBUG
terraform plan

# Save plan for inspection
terraform plan -out=tfplan
terraform show tfplan
```

### Check State Bucket

```bash
# List state files
gcloud storage ls gs://pairreader-terraform-state-dev/terraform/state/

# Download state for inspection (read-only)
gcloud storage cp gs://pairreader-terraform-state-dev/terraform/state/default.tfstate .
cat default.tfstate | jq '.resources[] | {type, name}'
```

### Validate Module Syntax

```bash
cd infra/modules/gcs-bucket
terraform init
terraform validate
```

### Test Module Locally

```bash
# Create test directory
mkdir -p /tmp/test-module
cd /tmp/test-module

cat > main.tf <<EOF
module "test_bucket" {
  source = "../../infra/modules/gcs-bucket"

  bucket_name            = "test-bucket-12345"
  project_id             = "your-project"
  location               = "us-central1"
  force_destroy          = true
  versioning_enabled     = false
  retention_days         = 7
  service_account_member = "serviceAccount:test@project.iam.gserviceaccount.com"
}
EOF

terraform init
terraform plan
```

### Recover from Failed Apply

```bash
# Check state
terraform show

# Refresh state from actual resources
terraform refresh

# Target specific resource for re-apply
terraform apply -target=module.cloud_run_service
```

### GitHub Actions Debugging

```yaml
# Add debug step to workflow
- name: Debug Terraform State
  run: |
    terraform show
    terraform output -json
```

---

## Additional Resources

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCS Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/gcs)
- [Terraform Module Best Practices](https://developer.hashicorp.com/terraform/language/modules/develop)
- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

## Changelog

- **2025-01-XX**: Initial version
- Tracks infrastructure as code implementation
- Documents DRY approach with modules
- Establishes dev/prod workflow patterns

---

**Last Updated**: 2025-01-XX
**Maintained By**: @sfnsys710
**Questions?**: Open an issue or PR
