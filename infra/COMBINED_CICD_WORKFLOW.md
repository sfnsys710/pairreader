# Combined Infra + App CI/CD Workflow

This workflow handles BOTH infrastructure (Terraform) and application (Docker) changes in a SINGLE PR.

## Workflow Design

**On PR:**
- Validates Terraform (fmt, validate, plan)
- Validates app code (pre-commit, pytest)
- Comments plan output on PR

**On Merge to Main:**
- Applies Terraform to dev (infra first)
- Builds and deploys app to dev (app second)

**On Manual Trigger:**
- Deploys to prod with approval gates

---

## Implementation

**File**: `.github/workflows/combined-cicd.yml`

```yaml
name: Combined CI/CD (Infra + App)

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
    branches:
      - main

  push:
    branches:
      - main

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
  GAR_LOCATION: ${{ vars.GCP_REGION }}
  GAR_REPOSITORY: "pairreader"
  GAR_BASE_IMAGE_NAME: "pairreader"
  CLOUDRUN_BASE_SERVICE_NAME: "pairreader-service"

jobs:
  # ============================================
  # JOB 1: Authorization (PR only)
  # ============================================
  authorize:
    name: Authorize PR
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - name: Authorized
        if: github.event.pull_request.head.repo.full_name == github.repository
        run: echo "PR authorized to run workflows"

  # ============================================
  # JOB 2: Validate Infrastructure (PR only)
  # ============================================
  validate-infra:
    name: Validate Infrastructure
    runs-on: ubuntu-latest
    needs: authorize
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

      - name: Check if Infra Changed
        id: infra-changed
        run: |
          if git diff --name-only origin/main...HEAD | grep -q '^infra/'; then
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "Infrastructure files changed"
          else
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "No infrastructure changes"
          fi

      - name: Terraform Format Check
        if: steps.infra-changed.outputs.changed == 'true'
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform fmt -check -recursive ../../

      - name: Terraform Init
        if: steps.infra-changed.outputs.changed == 'true'
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform init

      - name: Terraform Validate
        if: steps.infra-changed.outputs.changed == 'true'
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform validate

      - name: Terraform Plan
        if: steps.infra-changed.outputs.changed == 'true'
        id: plan
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: |
          terraform plan -no-color -out=tfplan
          terraform show -no-color tfplan > plan-output.txt
        continue-on-error: true

      - name: Upload Plan Output
        if: steps.infra-changed.outputs.changed == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan-dev
          path: ${{ env.TERRAFORM_WORKING_DIR_DEV }}/plan-output.txt

      - name: Comment PR with Plan
        if: steps.infra-changed.outputs.changed == 'true'
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const planPath = '${{ env.TERRAFORM_WORKING_DIR_DEV }}/plan-output.txt';
            const plan = fs.readFileSync(planPath, 'utf8');
            const truncated = plan.length > 65000
              ? plan.substring(0, 65000) + '\n\n... (truncated, see artifacts)'
              : plan;

            const body = `## 🏗️ Terraform Plan (Dev)\n\`\`\`terraform\n${truncated}\n\`\`\`\n\n---\n📝 Review before merging`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

      - name: Fail if Plan Failed
        if: steps.infra-changed.outputs.changed == 'true' && steps.plan.outcome == 'failure'
        run: exit 1

  # ============================================
  # JOB 3: Validate Application (PR only)
  # ============================================
  validate-app:
    name: Validate Application
    runs-on: ubuntu-latest
    needs: authorize
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check if App Changed
        id: app-changed
        run: |
          if git diff --name-only origin/main...HEAD | grep -qE '^(src/|tests/|pyproject.toml|Dockerfile|compose.yml)'; then
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "Application files changed"
          else
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "No application changes"
          fi

      - name: Install uv
        if: steps.app-changed.outputs.changed == 'true'
        uses: astral-sh/setup-uv@v6

      - name: Set up Python
        if: steps.app-changed.outputs.changed == 'true'
        run: uv python install

      - name: Install pre-commit dependencies
        if: steps.app-changed.outputs.changed == 'true'
        run: uv sync --only-group pre-commit

      - name: Run pre-commit
        if: steps.app-changed.outputs.changed == 'true'
        run: uv run --no-sync pre-commit run --all-files

      - name: Install test dependencies
        if: steps.app-changed.outputs.changed == 'true'
        run: uv sync --group test

      - name: Run pytest
        if: steps.app-changed.outputs.changed == 'true'
        run: uv run pytest -m unit -v

      - name: Validate Docker build
        if: steps.app-changed.outputs.changed == 'true'
        run: docker build -t test:local .

  # ============================================
  # JOB 4: Deploy to Dev (on merge)
  # ============================================
  deploy-dev:
    name: Deploy to Dev (Infra + App)
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: gcp-dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2  # Need previous commit to check diffs

      # ====== INFRA DEPLOYMENT ======
      - name: Check if Infra Changed
        id: infra-changed
        run: |
          if git diff --name-only HEAD~1 HEAD | grep -q '^infra/'; then
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "🏗️ Infrastructure changes detected"
          else
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "⏭️ No infrastructure changes, skipping Terraform"
          fi

      - name: Setup Terraform
        if: steps.infra-changed.outputs.changed == 'true'
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to Google Cloud (Infra)
        if: steps.infra-changed.outputs.changed == 'true'
        run: |
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}

      - name: Terraform Init
        if: steps.infra-changed.outputs.changed == 'true'
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform init

      - name: Terraform Apply
        if: steps.infra-changed.outputs.changed == 'true'
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: terraform apply -auto-approve

      - name: Terraform Outputs
        if: steps.infra-changed.outputs.changed == 'true'
        id: tf-outputs
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: |
          echo "## ✅ Terraform Applied (Dev)" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: `\(.value.value)`"' >> $GITHUB_STEP_SUMMARY

      # ====== APP DEPLOYMENT ======
      - name: Check if App Changed
        id: app-changed
        run: |
          if git diff --name-only HEAD~1 HEAD | grep -qE '^(src/|tests/|pyproject.toml|Dockerfile|compose.yml)'; then
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "🚀 Application changes detected"
          else
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "⏭️ No application changes, skipping Docker build/deploy"
          fi

      - name: Authenticate to Google Cloud (App)
        if: steps.app-changed.outputs.changed == 'true'
        run: |
          echo '${{ secrets.SA }}' > ${HOME}/gcp-key.json
          gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
          gcloud config set project ${{ vars.GCP_PROJECT_ID }}
          rm ${HOME}/gcp-key.json

      - name: Set up Docker Buildx
        if: steps.app-changed.outputs.changed == 'true'
        uses: docker/setup-buildx-action@v3

      - name: Configure Docker for Artifact Registry
        if: steps.app-changed.outputs.changed == 'true'
        run: gcloud auth configure-docker ${{ env.GAR_LOCATION }}-docker.pkg.dev

      - name: Build and Push Docker Image
        if: steps.app-changed.outputs.changed == 'true'
        run: |
          IMAGE_TAG="${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-dev:${{ github.sha }}"
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG
          echo "📦 Image pushed: $IMAGE_TAG" >> $GITHUB_STEP_SUMMARY

      - name: Get Service Account from Terraform
        if: steps.app-changed.outputs.changed == 'true'
        id: get-sa
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_DEV }}
        run: |
          # Re-authenticate for Terraform read
          export GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json
          terraform init > /dev/null 2>&1

          SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
          echo "SERVICE_ACCOUNT=$SERVICE_ACCOUNT" >> $GITHUB_OUTPUT
          echo "🔐 Using service account: $SERVICE_ACCOUNT"

      - name: Deploy to Cloud Run
        if: steps.app-changed.outputs.changed == 'true'
        run: |
          gcloud run deploy ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-dev \
            --image=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-dev:${{ github.sha }} \
            --region=${{ env.GAR_LOCATION }} \
            --service-account=${{ steps.get-sa.outputs.SERVICE_ACCOUNT }} \
            --allow-unauthenticated \
            --memory=4Gi \
            --port=8000 \
            --set-secrets=ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest,CHAINLIT_AUTH_SECRET=CHAINLIT_AUTH_SECRET:latest,LANGSMITH_API_KEY=LANGSMITH_API_KEY:latest \
            --quiet

          SERVICE_URL=$(gcloud run services describe ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-dev \
            --region=${{ env.GAR_LOCATION }} \
            --format='value(status.url)')

          echo "## ✅ Deployed to Dev" >> $GITHUB_STEP_SUMMARY
          echo "🌐 Service URL: $SERVICE_URL" >> $GITHUB_STEP_SUMMARY

  # ============================================
  # JOB 5: Deploy to Prod (manual)
  # ============================================
  deploy-prod:
    name: Deploy to Prod (Manual)
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
    environment: gcp-prod  # Requires approval

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # ====== INFRA DEPLOYMENT ======
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
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: |
          terraform plan -out=tfplan
          terraform show -no-color tfplan

      - name: Terraform Apply
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: terraform apply tfplan

      - name: Terraform Outputs
        id: tf-outputs
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: |
          echo "## ✅ Terraform Applied (Prod)" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: `\(.value.value)`"' >> $GITHUB_STEP_SUMMARY

      # ====== APP DEPLOYMENT ======
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.GAR_LOCATION }}-docker.pkg.dev

      - name: Build and Push Docker Image
        run: |
          IMAGE_TAG="${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-prod:${{ github.sha }}"
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG

      - name: Get Service Account from Terraform
        id: get-sa
        working-directory: ${{ env.TERRAFORM_WORKING_DIR_PROD }}
        run: |
          SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
          echo "SERVICE_ACCOUNT=$SERVICE_ACCOUNT" >> $GITHUB_OUTPUT

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-prod \
            --image=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/${{ env.GAR_BASE_IMAGE_NAME }}-prod:${{ github.sha }} \
            --region=${{ env.GAR_LOCATION }} \
            --service-account=${{ steps.get-sa.outputs.SERVICE_ACCOUNT }} \
            --no-allow-unauthenticated \
            --memory=8Gi \
            --port=8000 \
            --set-secrets=ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest,CHAINLIT_AUTH_SECRET=CHAINLIT_AUTH_SECRET:latest,LANGSMITH_API_KEY=LANGSMITH_API_KEY:latest \
            --quiet

          SERVICE_URL=$(gcloud run services describe ${{ env.CLOUDRUN_BASE_SERVICE_NAME }}-prod \
            --region=${{ env.GAR_LOCATION }} \
            --format='value(status.url)')

          echo "## ✅ Deployed to Prod" >> $GITHUB_STEP_SUMMARY
          echo "🌐 Service URL: $SERVICE_URL" >> $GITHUB_STEP_SUMMARY
```

---

## Key Features

### 1. Smart Change Detection
```yaml
- name: Check if Infra Changed
  run: |
    if git diff --name-only HEAD~1 HEAD | grep -q '^infra/'; then
      echo "changed=true"
    fi
```

- Only runs Terraform if `infra/` changed
- Only builds Docker if `src/`, `tests/`, or `Dockerfile` changed
- Saves CI time when only one side changes

### 2. Sequential Deployment
```
deploy-dev job:
├─ Step 1: Apply Terraform (if infra changed)
├─ Step 2: Build Docker (if app changed)
└─ Step 3: Deploy to Cloud Run (if app changed)
```

Infrastructure is ALWAYS applied before app deployment (when both change).

### 3. One-Button Prod
The `deploy-prod` job does BOTH:
1. Terraform apply (prod)
2. Docker build + Cloud Run deploy (prod)

Single workflow_dispatch trigger = complete prod deployment.

---

## When to Use Combined vs Separate

### Use COMBINED (ONE PR) when:
✅ Feature requires both infra and app changes
✅ App depends on new infrastructure
✅ Testing locally before commit
✅ Want atomic deployment (infra + app together)

**Examples:**
- Add GCS storage for ChromaDB
- Add new Cloud SQL database
- Add Redis cache layer
- Add Cloud CDN

### Use SEPARATE (TWO PRs) when:
✅ Pure infrastructure changes (no app impact)
✅ Multiple features will use the infra
✅ Infra team separate from app team

**Examples:**
- Add monitoring/alerting
- Update IAM roles
- Add VPC firewall rules
- Create shared service accounts

---

## Summary

Your intuition is correct:

**Phase 1 (Local):**
- Provision infra with Terraform locally
- Develop app locally
- Test locally (Docker Compose)
- Optionally: Manual Cloud Run deploy for end-to-end test

**Phase 2 (Consolidated Dev):**
- ONE PR with both infra and app
- CI validates both
- Merge → Auto-deploy both sequentially

**Phase 3 (Prod):**
- ONE button (workflow_dispatch)
- Deploys both infra and app with approval gate

This is cleaner, faster, and more intuitive than splitting into two PRs for most use cases.
