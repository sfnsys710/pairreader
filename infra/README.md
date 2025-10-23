# PairReader Infrastructure

Terraform infrastructure for deploying PairReader across multiple environments (dev, staging, prod) on Google Cloud Platform.

## Overview

This infrastructure setup provisions isolated environments for the PairReader application, with each environment having its own:
- Artifact Registry repository for Docker images
- Cloud Run service for running the application
- Service account with access to shared Secret Manager secrets

**Key Design Decisions**:
- **Shared Secrets**: All environments (dev/staging/prod) share the same Secret Manager secrets (ANTHROPIC_API_KEY, CHAINLIT_AUTH_SECRET, LANGSMITH_API_KEY)
- **Manual Secret Management**: Secrets are managed completely outside Terraform via `gcloud` commands
- **Separate State Buckets**: Each environment has its own GCS bucket for Terraform state isolation
- **Global Configuration**: Project ID and region are defined once in `infra/terraform.tfvars` and shared across all environments

## Directory Structure

```
infra/
├── terraform.tfvars          # Global config: project_id, region (gitignored)
├── modules/
│   └── pairreader/          # Reusable Terraform module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── artifact_registry.tf
│       ├── runtime_sa.tf         # Service account + IAM bindings
│       └── cloud_run.tf
└── envs/
    ├── dev/                 # Development environment
    │   ├── backend.tf       # State: sfn-terraform-state-dev
    │   └── main.tf
    ├── staging/             # Staging environment
    │   ├── backend.tf       # State: sfn-terraform-state-staging
    │   └── main.tf
    └── prod/                # Production environment
        ├── backend.tf       # State: sfn-terraform-state-prod
        └── main.tf
```

## Resources Created Per Environment

Each environment (dev, staging, prod) provisions:

| Resource Type | Naming Pattern | Example (dev) |
|---------------|----------------|---------------|
| **Artifact Registry** | `pairreader-{env}` | `pairreader-dev` |
| **Service Account** | `pairreader-runtime-{env}@{project}.iam.gserviceaccount.com` | `pairreader-runtime-dev@soufianesys.iam.gserviceaccount.com` |
| **Cloud Run Service** | `pairreader-service-{env}` | `pairreader-service-dev` |
| **Secrets** | Shared across all environments | `ANTHROPIC_API_KEY`, `CHAINLIT_AUTH_SECRET`, `LANGSMITH_API_KEY` |

### Resource Details

- **Artifact Registry**: Docker repository for storing application images (format: DOCKER)
- **Service Account**: Runtime identity for Cloud Run with `secretmanager.secretAccessor` role
- **Secret Manager**: Stores API keys and secrets (shared across environments, populated manually)
- **Cloud Run Service**:
  - Memory: 4Gi (default, configurable)
  - CPU: 2 vCPU (default, configurable)
  - Port: 8000
  - Scaling: 0-10 instances
  - LangSmith env vars (LANGSMITH_TRACING, LANGSMITH_ENDPOINT) have defaults in Dockerfile

## Prerequisites

### 0. Required Tool Versions

Ensure you have the following versions installed:

- **Terraform**: `>= 1.10.0` (latest stable: 1.13.4)
  - Terraform 1.10+ includes ephemeral values for better secret handling
  - Install: https://developer.hashicorp.com/terraform/downloads
- **Google Cloud Provider**: `~> 7.0` (latest: 7.7.0)
  - Version 7.0+ includes write-only attributes to keep secrets out of state
  - Automatically downloaded during `terraform init`

Check your versions:
```bash
terraform version
# Should show: Terraform v1.10.0 or higher
```

### 1. Google Cloud Setup

```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set project (use your project ID from terraform.tfvars)
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com
```

### 2. Create GCS Buckets for Terraform State (MANUAL SETUP)

Each environment needs its own GCS bucket for Terraform state. Create them manually:

```bash
# Dev environment state bucket
gcloud storage buckets create gs://sfn-terraform-state-dev \
  --location=europe-southwest1 \
  --uniform-bucket-level-access

# Staging environment state bucket
gcloud storage buckets create gs://sfn-terraform-state-staging \
  --location=europe-southwest1 \
  --uniform-bucket-level-access

# Production environment state bucket
gcloud storage buckets create gs://sfn-terraform-state-prod \
  --location=europe-southwest1 \
  --uniform-bucket-level-access
```

### 3. Create CI/CD Service Account (MANUAL SETUP)

The CI/CD pipeline needs a service account with appropriate permissions. Create it manually:

```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions-pairreader \
  --display-name="GitHub Actions Service Account for PairReader" \
  --description="Used by GitHub Actions CI/CD pipeline"

# Grant required roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-pairreader@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-pairreader@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-pairreader@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions-pairreader@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Add key to GitHub Secrets as 'SA' in the gcp-dev environment
# Then delete local key file
rm github-actions-key.json
```

### 4. Configure Global Variables

Create `infra/terraform.tfvars` (this file is gitignored):

```hcl
# Global configuration shared across all environments
project_id = "your-gcp-project-id"
region     = "your-gcp-region"  # e.g., "europe-southwest1"
```

**Note**: Secrets are NOT managed by Terraform. They must exist in Secret Manager before running Terraform (see Secret Management section below).

## Secret Management

### How It Works

Secrets are managed **completely outside Terraform** for maximum security:

1. **You create and manage secrets** manually using `gcloud` commands
2. **Terraform only manages IAM bindings** - grants the runtime service account access to existing secrets
3. **Cloud Run accesses secrets** at runtime via service account permissions
4. **CI/CD injects secrets** into Cloud Run using `--set-secrets` flag

**IMPORTANT**: Secrets must exist in Secret Manager **before** running `terraform apply`, otherwise IAM binding creation will fail.

### Setup Secrets (One-Time)

Create the required secrets manually (if they don't already exist):

```bash
# Option 1: Create secrets with values from stdin
echo "your-anthropic-api-key" | gcloud secrets create ANTHROPIC_API_KEY --data-file=-
echo "your-chainlit-auth-secret" | gcloud secrets create CHAINLIT_AUTH_SECRET --data-file=-
echo "your-langsmith-api-key" | gcloud secrets create LANGSMITH_API_KEY --data-file=-

# Option 2: Copy from local .env file (from project root)
grep ANTHROPIC_API_KEY .env | cut -d'=' -f2- | gcloud secrets create ANTHROPIC_API_KEY --data-file=-
grep CHAINLIT_AUTH_SECRET .env | cut -d'=' -f2- | gcloud secrets create CHAINLIT_AUTH_SECRET --data-file=-
grep LANGSMITH_API_KEY .env | cut -d'=' -f2- | gcloud secrets create LANGSMITH_API_KEY --data-file=-

# If secrets already exist, update them instead:
echo "your-new-key" | gcloud secrets versions add ANTHROPIC_API_KEY --data-file=-
```

### Verify Secrets

```bash
# List all secrets
gcloud secrets list

# Check if a secret has versions
gcloud secrets versions list ANTHROPIC_API_KEY

# View secret value (for verification)
gcloud secrets versions access latest --secret=ANTHROPIC_API_KEY
```

### Update Secrets

To update secret values (e.g., rotate API keys):

```bash
# Add new version (automatically becomes :latest)
echo "new-api-key" | gcloud secrets versions add ANTHROPIC_API_KEY --data-file=-

# Cloud Run will use the new version on next deployment
# No Terraform changes needed
```

## Deployment

### Deploy to Development

```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

**Before first `terraform apply`**: Ensure secrets exist in Secret Manager (see Secret Management section).

### Deploy to Staging

```bash
cd infra/envs/staging
terraform init
terraform plan
terraform apply
```

### Deploy to Production

```bash
cd infra/envs/prod
terraform init
terraform plan
terraform apply
```

### View Outputs

```bash
terraform output

# Example outputs:
# artifact_registry_repository_url = "europe-southwest1-docker.pkg.dev/soufianesys/pairreader-dev"
# service_account_email = "pairreader-runtime-dev@soufianesys.iam.gserviceaccount.com"
# cloud_run_service_url = "https://pairreader-service-dev-xxxx-ew.a.run.app"
```

### Destroy Resources

```bash
cd infra/envs/dev
terraform destroy

# Note: This does NOT delete secrets from Secret Manager
# Delete secrets manually if needed:
# gcloud secrets delete ANTHROPIC_API_KEY
```

## Configuration

### Global Configuration (infra/terraform.tfvars)

These variables are shared across all environments:

```hcl
project_id = "soufianesys"
region     = "europe-southwest1"
```

### Environment-Specific Configuration

Each environment can customize Cloud Run settings in `infra/envs/{env}/main.tf`:

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `memory` | Memory allocation | `4Gi` | Valid: 128Mi, 256Mi, 512Mi, 1Gi, 2Gi, 4Gi, 8Gi, 16Gi, 32Gi |
| `cpu` | CPU allocation | `2` | Valid: 1, 2, 4, 6, 8 |
| `port` | Container port | `8000` | Must match Dockerfile EXPOSE |
| `allow_unauthenticated` | Public access | `true` (dev/staging), `false` (prod) | Set to `false` for authentication |

**Example override** (in `infra/envs/prod/main.tf`):

```hcl
module "pairreader" {
  source = "../../modules/pairreader"

  project_id  = var.project_id
  region      = var.region
  environment = "prod"

  # Override defaults
  memory                = "8Gi"
  cpu                   = "4"
  allow_unauthenticated = false
}
```

## CI/CD Integration

### Current CI/CD Configuration

The GitHub Actions workflow (`.github/workflows/cicd.yml`) is configured for the **old infrastructure setup** and needs updates to work with this Terraform configuration.

**Key mismatches to fix**:
1. Repository naming: CI/CD uses `pairreader` but Terraform creates `pairreader-dev`
2. Service account: CI/CD hardcodes `pairreader-runtime@...` but Terraform creates `pairreader-runtime-dev@...`
3. Secret injection: CI/CD uses `--set-secrets` which works with the Terraform-created secrets

### Required CI/CD Updates

Update `.github/workflows/cicd.yml`:

```yaml
# Update repository name to match Terraform output
GAR_REPOSITORY: "pairreader-dev"  # Changed from "pairreader"

# Update service account to match Terraform output
--service-account=pairreader-runtime-dev@soufianesys.iam.gserviceaccount.com
```

**Note**: After making infrastructure changes with Terraform, always verify CI/CD configuration matches the Terraform outputs.

## Backend State Management

Terraform state is stored in GCS with environment-specific buckets:

- **Dev**: `gs://sfn-terraform-state-dev/pairreader/default.tfstate`
- **Staging**: `gs://sfn-terraform-state-staging/pairreader/default.tfstate`
- **Prod**: `gs://sfn-terraform-state-prod/pairreader/default.tfstate`

**Design**: We use separate buckets per environment (not prefixes) for complete state isolation. The `pairreader` prefix inside each bucket allows multiple projects to share the same bucket structure if needed in the future.

## Important Notes

### Secret Management

- ⚠️ **Security**: Secrets are NOT managed by Terraform at all - completely manual via `gcloud`
- Terraform only manages IAM bindings (grants service account access to secrets)
- Secrets are **shared** across all environments (not environment-specific)
- For production use cases requiring separate secrets per environment, create separate secrets manually: `ANTHROPIC_API_KEY_DEV`, `ANTHROPIC_API_KEY_PROD`, etc., and update IAM bindings in `runtime_sa.tf`

### Cloud Run Image Lifecycle

- Terraform creates Cloud Run with a **placeholder image** (`gcr.io/cloudrun/hello`)
- CI/CD pipeline updates the image on each deployment
- Terraform ignores image changes via `lifecycle.ignore_changes`
- This prevents Terraform from reverting CI/CD deployments

### Resource Naming

All resources follow the pattern: `{resource-name}-{env}` except:
- Secrets are shared (no environment suffix)
- State buckets use custom naming: `sfn-terraform-state-{env}`

### Environment Variables

The following environment variables have defaults in the Dockerfile:
- `LANGSMITH_TRACING=true`
- `LANGSMITH_ENDPOINT=https://api.smith.langchain.com`
- `LANGSMITH_PROJECT=pairreader`

Secrets (ANTHROPIC_API_KEY, CHAINLIT_AUTH_SECRET, LANGSMITH_API_KEY) are injected by Cloud Run via Secret Manager.

### Upgrading Infrastructure

To update resources:

```bash
cd infra/envs/dev
terraform plan    # Review changes
terraform apply   # Apply changes
```

Terraform tracks changes and only updates modified resources.

## Troubleshooting

### State Lock Errors

If you see "Error acquiring the state lock", someone else is running Terraform or a previous run crashed:

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Permission Denied Errors

Ensure your GCP account has the following roles:
- `roles/artifactregistry.admin`
- `roles/run.admin`
- `roles/secretmanager.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/storage.admin` (for state buckets)

Check with:
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:your-email@example.com"
```

### Secrets Not Accessible

If Cloud Run can't access secrets:

1. **Verify secret has value**:
   ```bash
   gcloud secrets versions access latest --secret=ANTHROPIC_API_KEY
   ```

2. **Check service account permissions**:
   ```bash
   gcloud secrets get-iam-policy ANTHROPIC_API_KEY
   # Should show pairreader-runtime-{env}@ with secretAccessor role
   ```

3. **Verify Cloud Run configuration**:
   ```bash
   gcloud run services describe pairreader-service-dev --region=europe-southwest1
   # Check that secrets are referenced in environment
   ```

### Backend Initialization Errors

If `terraform init` fails with "bucket does not exist":

1. Verify bucket exists:
   ```bash
   gcloud storage buckets list | grep sfn-terraform-state
   ```

2. If missing, create it (see Prerequisites section)

3. Verify you have access:
   ```bash
   gcloud storage buckets describe gs://sfn-terraform-state-dev
   ```

## Maintenance

### Adding a New Environment

1. Copy an existing environment directory:
   ```bash
   cp -r infra/envs/dev infra/envs/new-env
   ```

2. Create state bucket:
   ```bash
   gcloud storage buckets create gs://sfn-terraform-state-new-env \
     --location=europe-southwest1 \
     --uniform-bucket-level-access
   ```

3. Update `backend.tf`:
   ```hcl
   bucket = "sfn-terraform-state-new-env"
   prefix = "pairreader/new-env"
   ```

4. Update `main.tf`:
   ```hcl
   environment = "new-env"
   ```

5. Deploy:
   ```bash
   cd infra/envs/new-env
   terraform init
   terraform apply
   ```

6. Populate secrets (if not already done):
   ```bash
   echo "your-key" | gcloud secrets versions add ANTHROPIC_API_KEY --data-file=-
   # ... other secrets
   ```

### Rotating Service Account Keys

Service accounts use Google-managed keys (no rotation needed). If you need to recreate:

```bash
cd infra/envs/dev
terraform taint module.pairreader.google_service_account.pairreader_runtime
terraform apply
```

This will recreate the service account and update IAM bindings.

### Migrating to Environment-Specific Secrets

If you need separate secrets per environment:

1. Create environment-specific secrets manually:
   ```bash
   echo "dev-key" | gcloud secrets create ANTHROPIC_API_KEY_DEV --data-file=-
   echo "prod-key" | gcloud secrets create ANTHROPIC_API_KEY_PROD --data-file=-
   echo "dev-secret" | gcloud secrets create CHAINLIT_AUTH_SECRET_DEV --data-file=-
   echo "prod-secret" | gcloud secrets create CHAINLIT_AUTH_SECRET_PROD --data-file=-
   echo "dev-key" | gcloud secrets create LANGSMITH_API_KEY_DEV --data-file=-
   echo "prod-key" | gcloud secrets create LANGSMITH_API_KEY_PROD --data-file=-
   ```

2. Update `modules/pairreader/runtime_sa.tf` IAM bindings:
   ```hcl
   resource "google_secret_manager_secret_iam_member" "anthropic_api_key_accessor" {
     secret_id = "ANTHROPIC_API_KEY_${upper(var.environment)}"
     # ...
   }
   ```

3. Update CI/CD pipeline to reference environment-specific secrets

## Architecture Scope

This `infra/` directory manages **PairReader application infrastructure only**. The following are managed separately:

**Manual setup required** (not in Terraform):
- GCS state buckets (`sfn-terraform-state-{env}`)
- CI/CD service account (`github-actions-pairreader@...`)
- CI/CD service account IAM roles

**Shared across projects** (not environment-specific):
- Secret Manager secrets (ANTHROPIC_API_KEY, CHAINLIT_AUTH_SECRET, LANGSMITH_API_KEY)
- GCP project and region configuration

This keeps the infrastructure focused and maintainable.

## References

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Secret Manager Best Practices](https://cloud.google.com/secret-manager/docs/best-practices)
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/gcs)
