# PairReader

[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/license-Open%20Source-green.svg)](LICENSE)
[![LangGraph](https://img.shields.io/badge/LangGraph-Multi--Agent-orange.svg)](https://langchain-ai.github.io/langgraph/)

A smart document companion that allows you to chat with your books, presentations, notes, and other documents. Upload your files and have conversations with your content using advanced AI capabilities powered by LangGraph and Claude.

---

## Why PairReader?

Working with large documents, research papers, or collections of notes can be overwhelming. You need to find specific information quickly, understand key themes, or compare content across multiple sources. Traditional search only finds keywords, not meaning.

**PairReader solves this** by becoming your intelligent reading partner:

Unlike simple RAG chatbots, PairReader uses a **multi-agent architecture** that intelligently routes queries, decomposes complex questions, and provides both targeted answers and high-level overviews. It's production-ready with LangSmith tracing, giving you full observability into how answers are generated.

**What makes PairReader different:**
- Multi-agent system with specialized workflows (QA vs Discovery)
- Human-in-the-loop query review for transparency and control
- Smart query decomposition for complex multi-part questions
- Production-grade observability with LangSmith integration
- Full infrastructure-as-code for cloud deployment
- Complete CI/CD pipeline for dev/staging/prod environments

---

## Features

### Core Capabilities

- **Multi-Agent Architecture** - Specialized AI agents for different query types (QA vs Discovery)
- **Smart Query Processing** - Automatic decomposition of complex questions into sub-queries
- **Intelligent Routing** - System picks QA mode (specific questions) or Discovery mode (exploration)
- **Human-in-the-Loop** - Review and refine queries before search execution
- **Persistent Storage** - Your knowledge base persists between sessions with ChromaDB
- **Production-Ready** - Built-in observability with LangSmith tracing

### Intelligent Query Processing

- **Query Decomposition**: Complex questions like "Compare methods and results" automatically break into "What methods?" + "What results?"
- **Human-in-the-Loop**: Review and revise subqueries before search - you stay in control
- **Smart Routing**: System automatically picks QA (specific) or Discovery (overview) mode based on intent
- **Multi-document Search**: Searches across all uploaded documents simultaneously

### Advanced Document Processing

- **Smart Chunking**: Uses Docling's HybridChunker to preserve document structure and context
- **Contextual Embedding**: Each chunk knows its context for better semantic search
- **Persistent Storage**: ChromaDB saves your knowledge base between sessions
- **Flexible Formats**: Supports PDF and text files (up to 5 files, 10MB each)

### Production-Ready LLMOps

Built-in observability powered by LangSmith (optional):

- **Zero-Configuration Tracing**: Automatically traces all agent workflows, LLM calls, and routing decisions
- **Visual Debugging**: Inspect exact prompts, responses, and state transitions in the LangSmith UI
- **Performance Monitoring**: Track latency, token usage, and costs per agent and LLM call
- **Error Tracking**: Monitor fallback triggers, timeouts, and failure patterns
- **Cost Optimization**: Identify expensive queries and optimize token consumption

View your traces at [smith.langchain.com](https://smith.langchain.com/) under the `pairreader` project after enabling `LANGSMITH_TRACING` in your `.env` file.

### Configurable Settings

Adjust in the UI settings panel:
- **LLM Model**: Claude Haiku (fast, default) or Sonnet (more powerful)
- **Query Decomposition**: Break complex questions into sub-queries (ON/OFF)
- **Document Retrieval Count**: How many chunks to retrieve (5-20, default: 10)
- **Discovery Sampling/Clustering**: Advanced options for exploration mode

### Architecture Overview

PairReader uses a **multi-agent architecture** powered by LangGraph, where specialized AI agents work together to understand and answer your questions:

```
User Query
    ↓
PairReaderAgent (Supervisor)
    ↓
QADiscoveryRouter
    ↓
  ┌─────────────────┐
  ↓                 ↓
QAAgent          DiscoveryAgent
(Default)        (Exploration)
  ↓                 ↓
Answer           Overview
```

**How It Works:**

1. **PairReaderAgent** (Supervisor) - Handles file uploads and routes to the right agent
2. **QAAgent** (Default) - Answers specific questions by decomposing queries and retrieving relevant chunks
3. **DiscoveryAgent** (Exploration) - Creates overviews using clustering when you ask for "themes", "overview", or "explore"

The system automatically picks the right agent based on your question.

**Technology Stack:**
- **UI Framework**: Chainlit for interactive chat interface
- **Orchestration**: LangGraph for multi-agent workflow management
- **Node Architecture**: Modular three-tier design (BaseNode → LLMNode/RetrievalNode)
- **LLM**: Anthropic's Claude (Haiku/Sonnet) via LangChain with automatic fallbacks
- **Vector Store**: ChromaDB for semantic search and clustering
- **Document Parser**: Docling for robust PDF and text processing
- **LLMOps Platform**: LangSmith for production observability, tracing, debugging, and monitoring

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

### How to Use

#### First Time Setup
1. **Login** with default credentials: `admin` / `admin`
2. **Choose a mode**: Click `/Create` button or type the command
3. **Upload documents**: Drag & drop PDFs or text files (up to 5 files, 10MB each)
4. **Wait for processing**: Documents are chunked and embedded into ChromaDB

#### Daily Usage
1. **Ask questions naturally**: "What are the main findings?" or "Explain the methodology"
2. **Review subqueries** (if enabled): System shows how it breaks down your question
3. **Get your answer**: AI synthesizes information from relevant document chunks
4. **Iterate**: Refine your question or ask follow-ups

#### Mode Selection
- **Default mode** (no command): Query existing documents
- **/Update**: Add new documents to current collection
- **/Create**: Start fresh with a new knowledge base

### Tips for Best Results

- **Start with "Give me an overview"** when you upload new documents to understand what's available
- **Be specific** for better answers: "What were the results of experiment 2?" > "Tell me about results"
- **Use exploration keywords** ("overview", "themes", "explore") to trigger Discovery mode
- **Review subqueries** when shown - they reveal what's being searched
- **Adjust settings** in the UI panel: toggle query decomposition, change retrieval count (5-20)
- **Use `/Create`** to start fresh when switching topics, **`/Update`** to add related documents
- **Your data persists** - the knowledge base is saved between sessions in ChromaDB

---

## Run Locally

### Option A: Using uv (Recommended)

#### Prerequisites
- Python 3.12 or higher
- [uv](https://github.com/astral-sh/uv) package manager
- Anthropic API key

#### Installation

```bash
git clone https://github.com/soufianesys710/pairreader.git
cd pairreader
uv sync
```

#### Configuration

1. Generate a Chainlit authentication secret:
```bash
uv run chainlit create-secret
```

2. Create a `.env` file (or copy from `.env.example`):
```bash
# Required
ANTHROPIC_API_KEY=your_api_key_here
CHAINLIT_AUTH_SECRET=your_secret_from_step_1

# Optional - LangSmith for production observability (get API key from https://smith.langchain.com/)
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
LANGSMITH_API_KEY=your_langsmith_api_key_here
LANGSMITH_PROJECT=pairreader
```

> **Note**: LangSmith is optional but recommended for production use. It provides tracing, debugging, and monitoring capabilities.

#### Running the Application

```bash
uv run pairreader
```

Then open your browser to `http://localhost:8000`

**Default credentials:** username: `admin`, password: `admin` <!-- pragma: allowlist secret -->

### Option B: Using Docker

Run PairReader with Docker:

```bash
# Create .env file (same format as above)
docker compose up -d --build    # Start in background
docker compose logs -f          # View logs
docker compose down             # Stop
```

Access at `http://localhost:8000` with credentials `admin` / `admin`

> **Note**: ChromaDB data is stored in the container and persists as long as the container exists.

---

## Run in Cloud (Google Cloud Platform)

Deploy PairReader to GCP using **Terraform** for infrastructure provisioning and **GitHub Actions** for CI/CD.

### Prerequisites

- `gcloud` CLI installed and configured
- Terraform >= 1.10 installed
- GCP project with billing enabled
- Required APIs enabled: Artifact Registry, Cloud Run, Secret Manager, IAM, Cloud Resource Manager

### Infrastructure Overview

PairReader uses **Terraform** to provision isolated environments (dev/staging/prod), with each environment having its own:
- **Artifact Registry** repository for Docker images
- **Cloud Run** service for running the application
- **Service Account** with access to shared Secret Manager secrets

**Key Design Decisions:**
- **Shared Secrets**: All environments (dev/staging/prod) share the same Secret Manager secrets (`ANTHROPIC_API_KEY`, `CHAINLIT_AUTH_SECRET`, `LANGSMITH_API_KEY`)
- **Manual Secret Management**: Secrets are managed completely outside Terraform via `gcloud` commands for security
- **Separate State Buckets**: Each environment has its own GCS bucket for Terraform state isolation
- **Global Configuration**: Project ID and region defined once in `infra/terraform.tfvars` and shared across all environments

**Directory Structure:**
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

**Resources Created Per Environment:**

| Resource Type | Naming Pattern | Example (dev) |
|---------------|----------------|---------------|
| **Artifact Registry** | `pairreader-{env}` | `pairreader-dev` |
| **Service Account** | `pairreader-runtime-{env}@{project}.iam.gserviceaccount.com` | `pairreader-runtime-dev@soufianesys.iam.gserviceaccount.com` |
| **Cloud Run Service** | `pairreader-service-{env}` | `pairreader-service-dev` |
| **Secrets** | Shared across all environments | `ANTHROPIC_API_KEY`, `CHAINLIT_AUTH_SECRET`, `LANGSMITH_API_KEY` |

**Resource Details:**
- **Artifact Registry**: Docker repository for storing application images (format: DOCKER)
- **Service Account**: Runtime identity for Cloud Run with `secretmanager.secretAccessor` role
- **Secret Manager**: Stores API keys and secrets (shared across environments, populated manually)
- **Cloud Run Service**: 4Gi memory, 2 vCPU, port 8000, scaling 0-10 instances

### One-Time Setup

#### 1. Create GCS Buckets for Terraform State

Each environment needs its own GCS bucket for Terraform state:

```bash
# Create state buckets for each environment
for ENV in dev staging prod; do
  gcloud storage buckets create gs://sfn-terraform-state-${ENV} \
    --location=${GCP_REGION} \
    --uniform-bucket-level-access
done
```

#### 2. Configure Global Terraform Variables

Create `infra/terraform.tfvars` (this file is gitignored):

```hcl
# Global configuration shared across all environments
project_id = "your-gcp-project-id"
region     = "your-gcp-region"  # e.g., "europe-southwest1"
```

#### 3. Create Secrets in Secret Manager

Create secrets manually (shared across all environments):

```bash
# Create secrets
echo -n "your_anthropic_api_key" | gcloud secrets create ANTHROPIC_API_KEY --data-file=-
echo -n "your_chainlit_auth_secret" | gcloud secrets create CHAINLIT_AUTH_SECRET --data-file=-
echo -n "your_langsmith_api_key" | gcloud secrets create LANGSMITH_API_KEY --data-file=-
```

#### 4. Provision Infrastructure with Terraform

```bash
# Navigate to environment directory
cd infra/envs/dev  # or staging/prod

# Initialize Terraform (downloads providers and configures backend)
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply

# View outputs (service URL, repository URL, service account email)
terraform output
```

This provisions:
- Artifact Registry repository
- Service account with Secret Manager access (`secretmanager.secretAccessor` role)
- Cloud Run service

### Manual Deployment

The **CI/CD pipeline** automatically deploys to dev on every PR to `main`. For manual deployment or other environments:

```bash
# Set environment variables
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_REGION="your-gcp-region"
export ENV="dev"  # or staging/prod

# Authenticate Docker
gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev

# Build and push image
IMAGE_TAG="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/pairreader-${ENV}/pairreader-service-${ENV}:latest"
docker build -t $IMAGE_TAG .
docker push $IMAGE_TAG

# Cloud Run service will automatically pick up the new image
# Or update it manually:
gcloud run services update pairreader-service-${ENV} \
  --image=$IMAGE_TAG \
  --region=${GCP_REGION}
```

---

## CI/CD Setup (GitHub Actions)

PairReader uses **GitHub Actions** with a **multi-environment deployment strategy** across three separate workflows for dev, staging, and production environments.

### Workflow Overview

**Three Independent Workflows:**
- `.github/workflows/pr.yml` - PR checks and dev deployment (automatic on PR)
- `.github/workflows/staging.yml` - Staging deployment (automatic on merge to `main`)
- `.github/workflows/prod.yml` - Production deployment (manual `workflow_dispatch` only)

### GitHub Configuration

#### 1. Create GitHub Environment

Create a **single GitHub environment** in your repository settings (Settings → Environments):

**Environment name:** `gcp`

**Environment secrets:**
- `SA`: GCP service account JSON key (see service account setup below)

**Environment variables:**
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_REGION`: Your GCP region (e.g., `europe-southwest1`)

> **Note**: All three deployment targets (dev, staging, prod) share the same GitHub environment configuration since they use the same GCP project and service account. Environment-specific resources are differentiated by Terraform workspace directories and resource naming conventions.

#### 2. Create CI/CD Service Account

The CI/CD pipeline needs a service account with appropriate permissions:

```bash
# Create service account
gcloud iam service-accounts create pairreader-github-cicd \
  --display-name="GitHub Actions Service Account for PairReader" \
  --description="Used by GitHub Actions CI/CD pipeline"

# Grant required roles
for ROLE in roles/artifactregistry.writer roles/run.admin roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:pairreader-github-cicd@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$ROLE"
done

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=pairreader-github-cicd@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Add key contents to GitHub Secrets as 'SA' in the 'gcp' environment
# Then delete local key file for security
rm github-actions-key.json
```

**Service Account Permissions:**
- Artifact Registry: push images
- Cloud Run: deploy services
- Secret Manager: access secrets
- Terraform: manage infrastructure (storage, IAM, etc.)

---

## Development Lifecycle

PairReader implements a **progressive deployment strategy** across three environments: dev → staging → prod. Each environment has its own isolated infrastructure but shares the same GitHub configuration.

```
Pull Request → Dev Environment → Merge to Main → Staging Environment → Manual Trigger → Production
```

### Dev Environment (Automatic on PR)

**Triggered by:** Pull requests to `main` branch

**Workflow:** `.github/workflows/pr.yml`

**Pipeline Stages:**
1. **Authorization** - Blocks external PRs from consuming resources
2. **Extract Versions** - Reads from `pyproject.toml` and `infra/.terraform-version`
3. **Pre-commit Checks** - Runs all hooks (linting, formatting, secret detection)
4. **Terraform Checks** - Validates Terraform configuration for all environments
5. **Unit Tests** - Runs pytest unit tests
6. **Terraform Plan (Dev)** - Shows infrastructure changes (review window)
7. **Terraform Apply (Dev)** - Applies infrastructure changes
8. **Docker Build (Dev)** - Builds and pushes image
9. **Deploy (Dev)** - Deploys to Cloud Run

**Deployment Details:**
- **Service**: `pairreader-service-dev`
- **Image Tag**: `pairreader-dev:{git-sha}` (e.g., `pairreader-dev:9afe1dd`)
- **Artifact Registry**: `{region}-docker.pkg.dev/{project-id}/pairreader-dev/`
- **Service Account**: `pairreader-runtime-dev@{project-id}.iam.gserviceaccount.com`
- **Access**: Public (unauthenticated)
- **Purpose**: Rapid testing of PR changes before merge

### Staging Environment (Automatic on Merge)

**Triggered by:** Push to `main` branch (after PR merge)

**Workflow:** `.github/workflows/staging.yml`

**Pipeline Stages:**
1. **Extract Versions** - Reads versions
2. **Terraform Plan (Staging)** - Shows infrastructure changes
3. **Terraform Apply (Staging)** - Applies changes
4. **Docker Build (Staging)** - Builds and pushes versioned image
5. **Deploy (Staging)** - Deploys to Cloud Run

**Deployment Details:**
- **Service**: `pairreader-service-staging`
- **Image Tag**: `pairreader-staging:v{version}` (e.g., `pairreader-staging:v0.1.0`)
- **Artifact Registry**: `{region}-docker.pkg.dev/{project-id}/pairreader-staging/`
- **Service Account**: `pairreader-runtime-staging@{project-id}.iam.gserviceaccount.com`
- **Access**: Public (unauthenticated)
- **Purpose**: Pre-production testing with semantic versioning

### Production Environment (Manual Trigger Only)

**Triggered by:** Manual `workflow_dispatch` (GitHub Actions UI)

**Workflow:** `.github/workflows/prod.yml`

**Pipeline Stages:**
1. **Validation** - Requires typing "production" to confirm
2. **Extract Versions** - Reads versions
3. **Terraform Plan (Prod)** - Shows infrastructure changes (**REVIEW THIS CAREFULLY!**)
4. **Terraform Apply (Prod)** - Applies changes
5. **Docker Build (Prod)** - Builds and pushes versioned image
6. **Deploy (Prod)** - Deploys to Cloud Run

**Deployment Details:**
- **Service**: `pairreader-service-prod`
- **Image Tag**: `pairreader-prod:v{version}` (e.g., `pairreader-prod:v0.1.0`)
- **Artifact Registry**: `{region}-docker.pkg.dev/{project-id}/pairreader-prod/`
- **Service Account**: `pairreader-runtime-prod@{project-id}.iam.gserviceaccount.com`
- **Access**: **Private** (requires authentication)
- **Purpose**: Production deployment with manual approval gate

### Typical Development Flow

1. **Create feature branch** and make changes
2. **Open PR to main** → Triggers dev deployment automatically
   - Pre-commit checks run
   - Tests run
   - Infrastructure changes shown in Terraform plan
   - App deploys to `pairreader-service-dev`
3. **Review and test** on dev environment
4. **Merge PR to main** → Triggers staging deployment automatically
   - Semantic versioned image deployed to `pairreader-service-staging`
5. **Test on staging** environment
6. **Manual production deployment** via GitHub Actions UI
   - Type "production" to confirm
   - Review Terraform plan carefully
   - Deploys to `pairreader-service-prod` (authenticated only)

### Version Management

- **Dev**: Uses Git SHA for traceability (e.g., `9afe1dd`)
- **Staging/Prod**: Uses semantic version from `pyproject.toml` (e.g., `v0.1.0`)
- **Terraform**: Version managed in `infra/.terraform-version` and used by all CI/CD workflows

---

## Development

### Adding Dependencies
```bash
uv add <package-name>
```

### Development Mode with Auto-reload
```bash
uv run chainlit run src/pairreader/__main__.py -w
```

### Development Tools
```bash
uv sync --group dev   # Includes Jupyter for experimentation
uv sync --group test  # Install testing dependencies
```

### Running Tests
```bash
# Run all tests
uv run pytest

# Run only unit tests (fast)
uv run pytest -m unit

# Run with coverage report
uv run pytest --cov=src/pairreader --cov-report=html

# Run specific test file
uv run pytest tests/test_vectorstore.py

# View coverage report
open htmlcov/index.html
```

**Test Organization:**
- `tests/conftest.py` - Shared fixtures (mocked LLMs, vectorstore, Chainlit)
- `tests/test_*.py` - Test modules organized by source module
- `tests/fixtures/` - Test data and sample files
- Markers: `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.slow`

### Code Quality (Pre-commit Hooks)
```bash
# Install hooks (runs automatically on git commit)
uv run pre-commit install

# Run manually on all files
uv run pre-commit run --all-files

# Run specific hook
uv run pre-commit run ruff --all-files
```

**Configured Hooks:**
- File hygiene (trailing whitespace, EOF, line endings)
- Python linting and formatting (ruff)
- Secret detection (prevents committing API keys)
- Notebook processing (keeps outputs, strips metadata)

### Project Structure

```
pairreader/src/pairreader/
├── __main__.py        # Entry point
├── agents.py          # PairReaderAgent, QAAgent, DiscoveryAgent
├── *_nodes.py         # Node implementations (pairreader, qa, discovery)
├── schemas.py         # State definitions
├── prompts_msgs.py    # Centralized prompts
├── vectorestore.py    # ChromaDB interface
├── docparser.py       # Document processing
└── utils.py           # Base classes and utilities
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

---

## Repository Governance

PairReader enforces strict code quality and review standards through automated governance:

**Code Ownership** (`.github/CODEOWNERS`):
- All code changes require review from designated code owners
- `@sfnsys710` owns all core application code, infrastructure, documentation, and CI/CD
- GitHub automatically requests reviews from owners when PRs touch their areas
- Patterns follow specificity precedence (more specific patterns override general ones)

**Branch Protection** (`.github/repo-settings.md`):
- **Merge Strategy**: Rebase-only merges enforced for clean, linear git history
- **Pull Request Requirements**:
  - 1 code owner approval required
  - Last person who pushed cannot approve their own PR
  - CI must pass (`pre-commit` + `pytest`)
  - Branch must be up-to-date with `main`
- **Security**: Secret scanning and push protection enabled
- **Repository Admins**: Can bypass rules for flexibility on solo projects
- **Protection Method**: Modern repository ruleset (ID: 8656916)

This ensures all changes are reviewed, tested, and meet quality standards before merging to `main`.

---

## Roadmap

- Enhanced table/image extraction • Embedding-aware chunking • Page number attribution
- Improved Discovery Agent sampling • Secure authentication • Additional formats (Word, Excel)
- OAuth/SSO integration

---

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

---

## License

This project is open source and available under the [MIT License](LICENSE).

---

**Happy reading with your AI pair!** 📖
