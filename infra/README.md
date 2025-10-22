# PairReader Infrastructure

Terraform infrastructure for deploying PairReader across multiple environments (dev, staging, prod) on Google Cloud Platform.

## Directory Structure

```
infra/
├── terraform.tfvars          # Shared secrets (gitignored)
├── modules/
│   └── pairreader/          # Reusable Terraform module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── artifact_registry.tf
│       ├── service_account.tf
│       ├── secrets.tf
│       └── cloud_run.tf
└── envs/
    ├── dev/                 # Development environment
    │   ├── backend.tf
    │   └── main.tf
    ├── staging/             # Staging environment
    │   ├── backend.tf
    │   └── main.tf
    └── prod/                # Production environment
        ├── backend.tf
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

- **Artifact Registry**: Docker repository for storing application images
- **Service Account**: Runtime identity for Cloud Run with `secretmanager.secretAccessor` role
- **Secret Manager**: Stores API keys and secrets (shared across environments)
- **Cloud Run Service**: Runs the PairReader application with 4Gi memory, port 8000

## Prerequisites

### 1. Google Cloud Setup

```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project soufianesys

# Enable required APIs
gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com
```

### 2. Create GCS Bucket for Terraform State

```bash
gcloud storage buckets create gs://soufianesys-terraform-state \
  --location=europe-southwest1 \
  --uniform-bucket-level-access
```

### 3. Configure Secrets

Create `infra/terraform.tfvars` (this file is gitignored):

```hcl
# Shared secrets across all environments
anthropic_api_key     = "key" <!-- pragma: allowlist secret -->
chainlit_auth_secret  = "key" <!-- pragma: allowlist secret -->
langsmith_api_key     = "key" <!-- pragma: allowlist secret -->
```

You can copy values from your `.env` file:

```bash
# From project root
cd infra
cat > terraform.tfvars <<EOF
anthropic_api_key     = "$(grep ANTHROPIC_API_KEY ../.env | cut -d'=' -f2-)"
chainlit_auth_secret  = "$(grep CHAINLIT_AUTH_SECRET ../.env | cut -d'=' -f2-)"
langsmith_api_key     = "$(grep LANGSMITH_API_KEY ../.env | cut -d'=' -f2-)"
EOF
```

## Usage

### Deploy to Development

```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

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
```

## Configuration

### Environment-Specific Settings

Each environment can customize:

- **memory**: Cloud Run memory allocation (default: `4Gi`)
- **port**: Container port (default: `8000`)
- **allow_unauthenticated**: Public access flag
  - `dev`: `true` (default)
  - `staging`: `true` (default)
  - `prod`: `false` (requires authentication)

To override defaults, add to `infra/envs/{env}/main.tf`:

```hcl
module "pairreader" {
  source = "../../modules/pairreader"

  # ... other config ...

  memory                = "8Gi"  # Override default
  allow_unauthenticated = false
}
```

### Shared Configuration

The following are hardcoded and shared across all environments:

- **GCP Project**: `soufianesys`
- **GCP Region**: `europe-southwest1`
- **Secrets**: All environments use the same API keys from `infra/terraform.tfvars`

## CI/CD Integration

After deploying infrastructure with Terraform, update `.github/workflows/cicd.yml`:

```yaml
env:
  GAR_REPOSITORY: "pairreader-dev"  # Changed from "pairreader"
```

The CI/CD pipeline will:
1. Build Docker image
2. Push to environment-specific Artifact Registry (`pairreader-dev`)
3. Deploy to Cloud Run service (`pairreader-service-dev`)
4. Inject secrets from Secret Manager

## Backend State Management

Terraform state is stored in GCS with environment-specific prefixes:

- **Dev**: `gs://soufianesys-terraform-state/pairreader/dev`
- **Staging**: `gs://soufianesys-terraform-state/pairreader/staging`
- **Prod**: `gs://soufianesys-terraform-state/pairreader/prod`

This ensures state isolation between environments.

## Important Notes

### Secrets Management

- ⚠️ **Security**: Secrets are stored in Terraform state. Ensure GCS bucket has encryption and restricted access.
- Secrets are **shared** across all environments (not environment-specific).
- For production, consider using separate API keys per environment.

### Cloud Run Image Lifecycle

- Terraform creates Cloud Run with a **placeholder image** (`gcr.io/cloudrun/hello`)
- CI/CD pipeline updates the image on each deployment
- Terraform ignores image changes via `lifecycle.ignore_changes`

### Resource Naming

All resources follow the pattern: `{resource-name}-{env}` except secrets (shared).

### Upgrading Infrastructure

To update resources:

```bash
cd infra/envs/dev
terraform plan    # Review changes
terraform apply   # Apply changes
```

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

### Secrets Not Found

Ensure `infra/terraform.tfvars` exists and contains valid values:

```bash
ls -la infra/terraform.tfvars
cat infra/terraform.tfvars  # Check values
```

## Maintenance

### Adding a New Environment

1. Copy an existing environment directory:
   ```bash
   cp -r infra/envs/dev infra/envs/new-env
   ```

2. Update `backend.tf`:
   ```hcl
   prefix = "pairreader/new-env"
   ```

3. Update `main.tf`:
   ```hcl
   environment = "new-env"
   ```

4. Deploy:
   ```bash
   cd infra/envs/new-env
   terraform init
   terraform apply
   ```

### Updating Secrets

To update secrets in Secret Manager:

1. Update `infra/terraform.tfvars`
2. Run `terraform apply` in each environment
3. Secrets will be updated with new versions

### Rotating Service Account Keys

Service accounts use Google-managed keys (no rotation needed). If you need to recreate:

```bash
terraform taint module.pairreader.google_service_account.pairreader_runtime
terraform apply
```

## References

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
