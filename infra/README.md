# PairReader Infrastructure

This directory contains Terraform Infrastructure-as-Code (IaC) for managing PairReader's GCP resources.

## Quick Links

- **📘 [Complete Terraform Guide](./TERRAFORM_GUIDE.md)** - Comprehensive documentation (READ THIS FIRST)
- **🏗️ [Modules](./modules/)** - Reusable infrastructure components
- **🌍 [Environments](./environments/)** - Dev/Prod configurations

## Structure

```
infra/
├── TERRAFORM_GUIDE.md    # 📘 Complete documentation (start here)
├── modules/              # Reusable Terraform modules
│   ├── cloud-run/
│   ├── gcs-bucket/
│   └── service-account/
└── environments/         # Environment-specific configs
    ├── dev/
    └── prod/
```

## Quick Start

### Local Development

```bash
# Navigate to dev environment
cd environments/dev

# Initialize Terraform (first time only)
terraform init

# Preview changes
terraform plan

# Apply changes (use with caution)
terraform apply
```

### CI/CD Workflow

**Dev (Automatic):**
1. Create feature branch with infra changes
2. Push → PR → Review Terraform plan in PR comment
3. Merge → CI automatically applies to dev

**Prod (Manual):**
1. Navigate to GitHub Actions
2. Click "Terraform CI/CD" → "Run workflow"
3. Select `prod` environment
4. Approve deployment after reviewing plan

## Key Concepts

### DRY Approach
- Both dev and prod updated in SAME PR (no copy-paste)
- Modules define resources ONCE
- Environments configure modules with different values

### Environment Separation
- Separate state buckets: `pairreader-terraform-state-dev` / `-prod`
- Separate service accounts for CI
- Dev auto-deploys, prod requires manual approval

### GitOps Workflow
- All changes tracked in version control
- CI enforces validation (fmt, validate, plan)
- Infrastructure changes separated from app changes

## Prerequisites

Before using Terraform, ensure:

1. **GCS State Buckets Created**
   ```bash
   gcloud storage buckets create gs://pairreader-terraform-state-dev \
     --location=us-central1 --uniform-bucket-level-access

   gcloud storage buckets create gs://pairreader-terraform-state-prod \
     --location=us-central1 --uniform-bucket-level-access
   ```

2. **GitHub Environments Configured**
   - `gcp-dev` with service account secret
   - `gcp-prod` with service account secret + approval gate

3. **Terraform Installed**
   ```bash
   brew install terraform
   # Or download from: https://www.terraform.io/downloads
   ```

## Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List outputs
terraform output

# Refresh state
terraform refresh
```

## Best Practices

✅ Always review `terraform plan` before applying
✅ Update both dev and prod in same PR
✅ Use modules for reusable infrastructure
✅ Never commit sensitive `.tfvars` files
✅ Pin Terraform version in `versions.tf`

❌ Never auto-apply to production
❌ Don't commit `.tfstate` files
❌ Avoid hardcoding values (use variables)
❌ Don't manually edit resources after Terraform manages them

## Troubleshooting

### State Lock Error

```
Error: Error acquiring the state lock
```

**Solution**: Wait for other operation to finish, or force-unlock if sure no concurrent operations:
```bash
terraform force-unlock <LOCK_ID>
```

### Provider Authentication Error

```
Error: google: could not find default credentials
```

**Solution**: Authenticate locally:
```bash
gcloud auth application-default login
```

### Module Not Found

```
Error: Module not found
```

**Solution**: Re-initialize Terraform:
```bash
rm -rf .terraform
terraform init
```

## Resources

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCS Backend Docs](https://developer.hashicorp.com/terraform/language/settings/backends/gcs)
- [Internal: Complete Terraform Guide](./TERRAFORM_GUIDE.md)

## Getting Help

- **Questions?** Check [TERRAFORM_GUIDE.md](./TERRAFORM_GUIDE.md) first
- **Issues?** Open GitHub issue with `infra` label
- **Changes?** Follow development workflow in guide

---

**Maintained By**: @sfnsys710
**Last Updated**: 2025-01-XX
