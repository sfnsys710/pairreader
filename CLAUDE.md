# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PairReader is a document chat application built with Chainlit that allows users to upload documents (PDFs, text files) and query them using natural language. It uses a LangGraph-based multi-agent architecture with ChromaDB for vector storage and Docling for document parsing.

## Development Commands

### Running the Application

**Local Development:**
```bash
uv run pairreader         # Recommended: Uses project.scripts entry point
# OR
uv run chainlit run src/pairreader/__main__.py -w  # Direct Chainlit command with watch mode
```

**Docker Deployment:**
```bash
docker compose up -d --build    # Build and start in detached mode
docker compose logs -f          # Follow logs
docker compose down             # Stop and remove containers
docker compose build --no-cache # Force rebuild without cache
```

The application will be available at `http://localhost:8000`

### Installing Dependencies
```bash
uv sync                  # Install all dependencies (respects uv.lock)
uv sync --group dev      # Install with dev dependencies (includes Jupyter)
uv sync --group test     # Install testing dependencies
uv add <package-name>    # Add a new dependency and update uv.lock
```

**Important**:
- Always use `uv sync --locked` in production/Docker to ensure reproducible builds
- Build backend is `uv_build`
- Python 3.12+ required
- Uses `uv` package manager (not pip)

### Testing

**Running Tests:**
```bash
# Run all tests
uv run pytest

# Run only unit tests (fast)
uv run pytest -m unit

# Run with coverage report
uv run pytest --cov=src/pairreader --cov-report=html

# Run specific test file
uv run pytest tests/test_utils.py

# Run with verbose output
uv run pytest -v

# Skip slow tests
uv run pytest -m "not slow"
```

**Test Markers:**
- `@pytest.mark.unit` - Fast unit tests for individual components
- `@pytest.mark.integration` - Integration tests with mocked dependencies
- `@pytest.mark.slow` - Tests that take longer to run

**Coverage:**
- Coverage reports are generated in `htmlcov/` directory
- Open `htmlcov/index.html` in a browser to view detailed coverage
- Target: 70%+ coverage for core modules

### Pre-commit Hooks

**Installation:**
```bash
uv run pre-commit install   # Install hooks (auto-runs on git commit)
```

**Manual Execution:**
```bash
# Run all hooks
uv run pre-commit run --all-files

# Run specific hook
uv run pre-commit run ruff --all-files
uv run pre-commit run detect-secrets --all-files
```

**Configured Hooks:**
- **File hygiene**: trailing-whitespace, end-of-file-fixer, mixed-line-ending
- **Validation**: check-yaml, check-toml, check-json, check-added-large-files, check-merge-conflict
- **Python linting**: ruff (auto-fixes bugs, unused imports, style issues)
- **Python formatting**: ruff-format (spacing, line length, quotes)
- **Secret detection**: detect-secrets (prevents committing API keys/tokens)
- **Notebook processing**: nbqa-ruff, nbqa-ruff-format, nbstripout (keeps outputs, strips volatile metadata)

**Important Notes:**
- Use `# noqa: <code>` comments for intentional violations (e.g., `# noqa: F841` for unused vars)
- Use `<!-- pragma: allowlist secret -->` for false positive secrets (works inline, no baseline file needed)
- Notebooks in `idea/` directory are processed but outputs are preserved for readability

### Environment Setup
Create a `.env` file in the project root with the following variables:
```bash
ANTHROPIC_API_KEY=your_api_key_here
CHAINLIT_AUTH_SECRET=your_secret_here  # Generate with: chainlit create-secret

# LangSmith (Optional but recommended for production observability)
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
LANGSMITH_API_KEY=your_langsmith_api_key_here
LANGSMITH_PROJECT=pairreader
```

**LangSmith Integration**: The application uses LangSmith for tracing, debugging, and LLMOps monitoring. When `LANGSMITH_TRACING=true`, all LangGraph workflows are automatically traced without requiring code changes. This provides visibility into agent execution, LLM calls, and multi-agent interactions.

## CI/CD Pipeline

PairReader uses **GitHub Actions** with a **multi-environment deployment strategy** across three separate workflows for dev, staging, and production environments.

### Workflow Structure

**Three Independent Workflows**:
- `.github/workflows/pr.yml` - PR checks and dev deployment (automatic on PR)
- `.github/workflows/staging.yml` - Staging deployment (automatic on merge to `main`)
- `.github/workflows/prod.yml` - Production deployment (manual `workflow_dispatch` only)

### Development Lifecycle

**Progressive deployment strategy**: dev → staging → prod

1. **Dev Environment** (Automatic on PR to `main`):
   - Runs pre-commit checks, Terraform validation, unit tests
   - Deploys to `pairreader-service-dev` with image tag: `pairreader-dev:{git-sha}`
   - Public access (unauthenticated)

2. **Staging Environment** (Automatic on merge to `main`):
   - Deploys to `pairreader-service-staging` with image tag: `pairreader-staging:v{version}`
   - Uses semantic version from `pyproject.toml`
   - Public access (unauthenticated)

3. **Production Environment** (Manual trigger only):
   - Requires typing "production" to confirm
   - Deploys to `pairreader-service-prod` with image tag: `pairreader-prod:v{version}`
   - **Private** (requires authentication)

### GitHub Environment Configuration

**Required Environment** (configure in GitHub repo settings):
- **`gcp`** (single environment shared across all deployment targets)
  - Secret: `SA` (GCP service account JSON key) <!-- pragma: allowlist secret -->
  - Variables: `GCP_PROJECT_ID`, `GCP_REGION`

**Note**: All three deployment targets (dev, staging, prod) share the same GitHub environment configuration since they use the same GCP project and service account. Environment-specific resources are differentiated by Terraform workspace directories and resource naming conventions.

### Terraform & Infrastructure

**Version Management**:
- Terraform CLI version: `infra/.terraform-version` (used by CI/CD)
- Terraform required_version: In each env's `main.tf` (dev/staging/prod)
- When updating: Update all 3 env files + `.terraform-version` (comments remind you)

**State Management**:
- Separate GCS buckets per environment:
  - Dev: `sfn-terraform-state-dev`
  - Staging: `sfn-terraform-state-staging`
  - Prod: `sfn-terraform-state-prod`
- State locking enabled by default (GCS backend)

**Infrastructure Resources** (per environment):
- Artifact Registry repository: `pairreader-{env}`
- Cloud Run service: `pairreader-service-{env}`
- Service Account: `pairreader-runtime-{env}`
- Secrets: Managed via Secret Manager (ANTHROPIC_API_KEY, CHAINLIT_AUTH_SECRET, LANGSMITH_API_KEY)

**Key Design Decisions**:
- **Shared Secrets**: All environments share the same Secret Manager secrets
- **Manual Secret Management**: Secrets are managed completely outside Terraform via `gcloud` commands for security
- **Global Configuration**: Project ID and region defined once in `infra/terraform.tfvars` (gitignored)

### Repository Governance

**Code Ownership** (`.github/CODEOWNERS`):
- All code changes require review from designated code owners
- `@sfnsys710` owns all core application code, infrastructure, documentation, and CI/CD

**Branch Protection**:
- **Merge Strategy**: Rebase-only merges enforced for clean, linear git history
- **Pull Request Requirements**:
  - 1 code owner approval required
  - Last person who pushed cannot approve their own PR
  - CI must pass (`pre-commit` + `pytest`)
  - Branch must be up-to-date with `main`
- **Security**: Secret scanning and push protection enabled

## Architecture Overview

### Multi-Agent System Architecture

PairReader uses a **three-tier agent hierarchy** with LangGraph:

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

1. **PairReaderAgent** (Supervisor) - Top-level orchestrator
   - Handles knowledge base operations (Create/Update/Query modes)
   - Routes user queries to specialized sub-agents
   - Graph: `knowledge_base_handler` → `qa_discovery_router` → sub-agents

2. **QAAgent** (Sub-agent) - **DEFAULT agent** for most queries
   - Graph: `query_optimizer` → `human_in_the_loop_approver` → `info_retriever` → `info_summarizer`
   - Handles all regular questions and information requests
   - Optional query decomposition for complex questions

3. **DiscoveryAgent** (Sub-agent) - Used only for explicit exploration
   - Graph: `cluster_retriever` → `map_summarizer` → `reduce_summarizer`
   - Uses map-reduce pattern to cluster and summarize documents
   - Only triggered when user explicitly asks for overview/exploration/themes/key ideas

### Agent Routing with Command Primitive

The `QADiscoveryRouter` uses LangGraph's **Command primitive** for dynamic routing:
- LLM is bound with two tools: `qa_agent_handoff` and `discovery_agent_handoff`
- Based on user query intent, LLM selects appropriate tool
- Tool execution returns a `Command(goto="agent_name", update={...})` to navigate the graph
- This enables intelligent handoff between specialized agents

**QAAgent (DEFAULT)** - Used for most queries:
- User asks questions about content: "What does this say about X?", "Explain Y", "How many Z are mentioned?"
- User seeks specific information from the documents
- Workflow emphasizes precise retrieval and focused answers
- **This is the default agent** - used unless user explicitly requests exploration

**DiscoveryAgent** - Used only for explicit exploration requests:
- User explicitly asks for: "overview", "explore", "discover", "main themes", "main ideas", "key ideas", "overall summary"
- User wants high-level exploration without specific questions
- Workflow uses map-reduce clustering for comprehensive insights
- **Only triggered by explicit exploration language** - not used for regular questions

### Node Architecture Design Principles

PairReader implements a **three-tier node inheritance hierarchy** for clean separation of concerns and code reusability:

#### 1. BaseNode (Foundation Layer)
Base class for all LangGraph nodes providing:
- **User I/O operations**: `ask()`, `send()`, `stream()` methods for UI interaction
- **Dynamic parameter management**: `set_params()` and `get_params()` for runtime configuration
- **Standard interface**: All nodes implement `async __call__(state: Dict) -> Dict`

**When to use**: Pure logic nodes that don't need LLM or vector store access
- Example: `KnowledgeBaseHandler` (handles file uploads and commands)

#### 2. LLMNode (extends BaseNode)
Specialized for nodes using Language Models with encapsulated patterns:
- **Primary + Fallback LLM**: Automatic failover if primary model fails
- **Tool Binding**: Optional `.bind_tools()` for routing/function calling
- **Structured Output**: Optional `.with_structured_output()` for Pydantic models
- **Smart `@property llm`**: Dynamically applies all configurations when accessed

**When to use**: Nodes that generate text, make decisions, or use LLM reasoning
- Examples: `QueryOptimizer`, `InfoSummarizer`, `MapSummarizer`, `ReduceSummarizer`, `QADiscoveryRouter`, `HumanInTheLoopApprover`

#### 3. RetrievalNode (extends BaseNode)
Specialized for nodes interacting with vector stores:
- **Vectorstore access**: Direct access via `self.vectorstore`
- **Common retrieval patterns**: Query, sample, cluster, metadata operations
- **Separation of concerns**: Retrieval logic separated from LLM logic

**When to use**: Nodes that query, sample, or cluster documents
- Examples: `InfoRetriever`, `ClusterRetriever`

**Key Benefits of This Architecture**:
1. **Code Reusability**: Common LLM and retrieval patterns extracted once
2. **Separation of Concerns**: LLM logic, retrieval logic, and I/O cleanly separated
3. **Flexibility**: Easy to swap LLM configurations, add tools, or change vectorstore
4. **Consistency**: All nodes follow the same patterns and interfaces
5. **Testability**: Each layer can be tested independently

### State Management

`PairReaderState` TypedDict is **shared across all agents** (PairReaderAgent, QAAgent, DiscoveryAgent):
- `messages`: Annotated list with `add_messages` reducer for LLM conversation history
- `user_query`: Original user question
- `user_command`: Command type (Create/Update/None)
- QA-specific: `subqueries`, `human_in_the_loop_decision`, `retrieved_documents`, `retrieved_metadatas`, `summary`
- Discovery-specific: `clusters`, `cluster_summaries`, `summary_of_summaries`

### Node Organization

Nodes are organized into three files, with each node inheriting from the appropriate base class:

1. **`pairreader_nodes.py`** - Supervisor-level nodes
   - `KnowledgeBaseHandler` (BaseNode): Manages file uploads and vector store initialization
   - `QADiscoveryRouter` (LLMNode): Routes queries to QA or Discovery agent using Command primitive with tool binding

2. **`qa_nodes.py`** - QA Agent nodes
   - `QueryOptimizer` (LLMNode): Decomposes queries using LLM (configurable via `query_decomposition` param). When `query_decomposition=False`, passes through original query WITHOUT calling LLM.
   - `HumanInTheLoopApprover` (LLMNode): Uses `interrupt()` for user interaction, returns structured `HITLDecision` via structured output
   - `InfoRetriever` (RetrievalNode): Queries ChromaDB with subqueries
   - `InfoSummarizer` (LLMNode): Generates final response using LLM (no fallback by design)

3. **`discovery_nodes.py`** - Discovery Agent nodes
   - `ClusterRetriever` (RetrievalNode): Samples documents from vectorstore and clusters them
   - `MapSummarizer` (LLMNode): Summarizes each cluster in parallel using `asyncio.gather()`
   - `ReduceSummarizer` (LLMNode): Combines cluster summaries into a final overview

### Core Components

**Agent Classes** (`src/pairreader/agents.py`):
- `PairReaderAgent`: Main orchestrator with sub-agents (QAAgent, DiscoveryAgent, router)
- `QAAgent`: Question-answering workflow with query decomposition and retrieval
- `DiscoveryAgent`: Document exploration with clustering and map-reduce summarization
- All agents use `InMemorySaver` for checkpointing (not persisted to disk)
- Nodes are stored as tuples `(name, node_instance)` in `self.nodes` list
- `set_params(**params)` propagates settings changes to all nodes (accesses `node[1]` for node instance)

**Utility Classes** (`src/pairreader/utils.py`):
- `BaseNode`: Foundation class for all nodes (UserIO + parameter management)
- `LLMNode`: Extends BaseNode for nodes using language models
- `RetrievalNode`: Extends BaseNode for nodes accessing vector stores
- `BaseAgent`: Base class for all agents with common initialization
- `@Verboser`: Decorator for logging and streaming verbosity (levels 0-3)

**Prompts and Messages** (`src/pairreader/prompts_msgs.py`):
- Centralized repository for all LLM prompts and user messages
- `DISCOVERY_PROMPTS`/`DISCOVERY_MSGS`: Discovery Agent templates
- `QA_PROMPTS`/`QA_MSGS`: QA Agent templates
- `PAIRREADER_PROMPTS`/`PAIRREADER_MSGS`: Routing and knowledge base operations
- All prompts use `.format()` for variable substitution

**Document Processing**:
- `DocParser` (`src/pairreader/docparser.py`): Uses Docling's `DocumentConverter` and `HybridChunker`
- `VectorStore` (`src/pairreader/vectorestore.py`):
  - ChromaDB client with persistent storage in `./chroma` directory
  - Default collection name: `"knowledge_base"`
  - Discovery-specific methods: `get_sample()`, `get_clusters()`

**Chainlit Integration** (`src/pairreader/__main__.py`):
- Entry point with `main()` function for CLI command
- Custom `InMemoryDataLayer` for chat history (not persisted between restarts)
- Password authentication: username/password = "admin"/"admin" (TODO: move to secure storage)  <!-- pragma: allowlist secret -->
- Settings UI with general and discovery-specific parameters
- Uses `cl.context.session.thread_id` for thread-based conversations

### Three Usage Modes
- **Default**: Query existing knowledge base (no command sent)
- **Update** (`/Update`): Add documents to existing knowledge base
- **Create** (`/Create`): Flush knowledge base and start fresh

Commands are triggered via Chainlit commands `/Create` or `/Update`, or via starter buttons in UI

## Code Style and Patterns

### Node Implementation Patterns

All LangGraph nodes inherit from one of three base classes. Choose based on the node's function:

#### Pattern 1: BaseNode (Pure Logic Nodes)
For nodes that don't need LLM or vectorstore access:
```python
from pairreader.utils import BaseNode, Verboser
from pairreader.prompts_msgs import AGENT_MSGS

class KnowledgeBaseHandler(BaseNode):
    def __init__(self, docparser: DocParser, vectorstore: VectorStore):
        self.docparser = docparser
        self.vectorstore = vectorstore

    @Verboser(verbosity_level=2)
    async def __call__(self, state: PairReaderState, *args, **kwds) -> Dict:
        # Inform user first (if needed)
        await self.send(AGENT_MSGS["operation_starting"])

        # Pure logic here (file handling, state management, etc.)
        return {"state_key": value}
```

#### Pattern 2: LLMNode (Language Model Nodes)
For nodes using LLMs with optional fallback, tools, or structured output:
```python
from pairreader.utils import LLMNode, Verboser
from pairreader.prompts_msgs import AGENT_PROMPTS, AGENT_MSGS
from langchain_core.messages import HumanMessage

# Simple LLM node
class InfoSummarizer(LLMNode):
    def __init__(self, llm_name: str = "anthropic:claude-3-5-haiku-latest", **kwargs):
        super().__init__(llm_name=llm_name, fallback_llm_name=None, **kwargs)

    @Verboser(verbosity_level=2)
    async def __call__(self, state: PairReaderState, *args, **kwds) -> Dict:
        await self.send(AGENT_MSGS["operation_starting"])

        prompt = AGENT_PROMPTS["operation_name"].format(user_input=state["field"])
        msg = HumanMessage(content=prompt)

        # Use self.llm (automatically configured with fallback/tools/structured output)
        content = await self.stream(self.llm, state["messages"] + [msg])
        return {"state_key": content}

# LLM node with structured output
class HumanInTheLoopApprover(LLMNode):
    def __init__(self, **kwargs):
        super().__init__(structured_output_schema=HITLDecision, **kwargs)

    @Verboser(verbosity_level=2)
    async def __call__(self, state: PairReaderState, *args, **kwds) -> Dict:
        # self.llm automatically returns HITLDecision instance
        decision: HITLDecision = self.llm.invoke(state["messages"])
        return {"human_in_the_loop_decision": decision}

# LLM node with tool binding
class QADiscoveryRouter(LLMNode):
    def __init__(self, **kwargs):
        super().__init__(tools=[self.qa_agent, self.discovery_agent], **kwargs)

    @Verboser(verbosity_level=2)
    async def __call__(self, state: PairReaderState) -> Command:
        # self.llm automatically bound with tools
        response = await self.llm.ainvoke(messages)
        tool_call = response.tool_calls[0]
        return Command(goto=tool_call["name"], update={...})

    @tool(description="...")
    def qa_agent():
        return "qa_agent"
```

#### Pattern 3: RetrievalNode (Vector Store Nodes)
For nodes that query, sample, or cluster documents:
```python
from pairreader.utils import RetrievalNode, Verboser
from pairreader.prompts_msgs import AGENT_MSGS

class InfoRetriever(RetrievalNode):
    def __init__(self, vectorstore: VectorStore, n_documents: int = 10, **kwargs):
        super().__init__(vectorstore=vectorstore, **kwargs)
        self.n_documents = n_documents

    @Verboser(verbosity_level=2)
    async def __call__(self, state: PairReaderState, *args, **kwds) -> Dict:
        await self.send(AGENT_MSGS["retriever_querying"])

        # Access vectorstore via self.vectorstore
        results = self.vectorstore.query(
            query_texts=state["subqueries"],
            n_documents=self.n_documents
        )

        return {
            "retrieved_documents": results["documents"][0],
            "retrieved_metadatas": results["metadatas"][0]
        }
```

### Important Patterns

**Node Inheritance**:
- **Choose the right base class**:
  - `BaseNode` for pure logic (file handling, commands)
  - `LLMNode` for text generation, decision-making, routing
  - `RetrievalNode` for vectorstore queries, sampling, clustering
- **All nodes inherit from one of these three classes** - never create nodes from scratch
- **LLM configuration is automatic**: `LLMNode.llm` property handles fallbacks, tools, and structured output
- **Vectorstore access is built-in**: `RetrievalNode.vectorstore` provides direct access

**Agent instantiation**:
- All three agents (PairReaderAgent, QAAgent, DiscoveryAgent) follow the same pattern:
  - Node classes are instantiated as tuples: `("node_name", NodeInstance())`
  - When accessing nodes from `self.nodes` list, use `node[1]` to get the instance (e.g., in `set_params()`)
  - Each agent has its own `InMemorySaver` checkpointer

**Prompts and Messages**:
- All prompts/messages are centralized in `prompts_msgs.py`
- `*_PROMPTS` dictionaries contain templates sent to LLMs
- `*_MSGS` dictionaries contain user-facing messages
- Use `.format()` for variable substitution in templates
- Inform user first before long-running operations (using `MSGS`)

**LLM Patterns**:
- **Dynamic initialization**: LLM nodes use `@property llm` to ensure fresh initialization with current params
- **Fallback configuration**: Set `fallback_llm_name=None` to disable (e.g., InfoSummarizer)
- **Structured outputs**: Pass `structured_output_schema=MyModel` to `__init__` (e.g., HumanInTheLoopApprover)
- **Tool binding**: Pass `tools=[...]` to `__init__` (e.g., QADiscoveryRouter)

**State and Flow Control**:
- **State updates**: Return a dict with only the keys being updated (not the full state)
- **Interrupts**: Use `interrupt()` from `langgraph.types` to pause workflow for user input
- **Command-based routing**: Router nodes return `Command(goto="target", update={...})` for dynamic navigation
- **Parallel execution**: Use `asyncio.gather()` for parallel LLM calls (e.g., MapSummarizer)

## Important Implementation Details

### LangSmith LLMOps Integration

PairReader implements production-ready LLMOps through LangSmith for full observability and debugging.

**Automatic Tracing** (Zero-Configuration):
- Enable with `LANGSMITH_TRACING=true` in `.env` - no code changes needed
- Traces all LangGraph workflows, LLM calls, agent routing, and state transitions
- Organized under `pairreader` project at https://smith.langchain.com/

**What Gets Traced**:
- Multi-agent orchestration (PairReaderAgent → QA/Discovery routing)
- LLM interactions (prompts, responses, structured outputs)
- Tool calls (Command navigation, tool binding, interrupts)
- Vectorstore operations (queries, retrieval, clustering)
- State evolution across all nodes

### LLM Configuration
- Default LLM: `anthropic:claude-3-5-haiku-latest`
- Fallback LLM: `anthropic:claude-3-7-sonnet-latest`
- LLMs are initialized using `langchain.chat_models.init_chat_model`
- Fallback is configured with `.with_fallbacks([...])`
- Each node that uses LLM has an `llm` property that returns the configured LLM with fallback

### Vector Store Behavior
- `/Create` command calls `vectorstore.flush()` (deletes and recreates collection)
- `/Update` command appends to existing collection
- Query results include top `n_documents` (default: 10, configurable via settings)
- Uses default ChromaDB embedding (all-MiniLM-L6-v2)
- Persistent storage in `./chroma` directory

### Streaming and Execution
- LangGraph workflow is invoked with `await pairreader(input=input, config=config)` in `on_message()`
- Config includes thread_id: `{"configurable": {"thread_id": thread_id}}`
- Nodes use LangGraph's `get_stream_writer()` to send status updates
- LLM message history is maintained in `state["messages"]` with `add_messages` reducer

### Docker Architecture

**Multi-Stage Build** (`Dockerfile`):
- **Builder stage**: Uses `ghcr.io/astral-sh/uv:python3.12-bookworm-slim` as base
  - `UV_PYTHON_DOWNLOADS=0`: Forces use of system Python (must match pyproject.toml version)
  - `UV_COMPILE_BYTECODE=1`: Pre-compiles bytecode for faster container startup
  - Dependencies installed first (`uv sync --locked --no-install-project --no-dev`) for better layer caching
  - Project installed separately (`uv sync --locked --no-dev`) to leverage Docker layer caching
- **Runtime stage**: Uses `python:3.12-slim-bookworm` (smaller footprint)
  - Only copies `.venv/`, `src/`, `public/`, and `chainlit.md` from builder
  - Sets `PYTHONPATH=/app/src` for module imports
  - Chainlit runs on `0.0.0.0:8000` for container accessibility

**Key Implementation Notes**:
- Python version **must match** across: `pyproject.toml`, builder base image, and runtime base image
- `UV_PYTHON_DOWNLOADS=0` prevents uv from downloading a different Python version
- `chainlit.md` and `README.md` must be copied before `uv sync --locked --no-dev` (required by package metadata)
- Entry point uses full command: `chainlit run src/pairreader/__main__.py` (not `pairreader` script)

## Package Structure
```
pairreader/src/pairreader/
├── __main__.py           # Application entry point with Chainlit integration
├── agents.py             # Multi-agent orchestration (PairReaderAgent, QAAgent, DiscoveryAgent)
├── pairreader_nodes.py   # Supervisor nodes (KnowledgeBaseHandler, QADiscoveryRouter)
├── qa_nodes.py           # QA Agent nodes (QueryOptimizer, InfoRetriever, etc.)
├── discovery_nodes.py    # Discovery Agent nodes (ClusterRetriever, MapSummarizer, ReduceSummarizer)
├── schemas.py            # Shared state definitions
├── prompts_msgs.py       # Centralized prompts and messages
├── vectorestore.py       # ChromaDB interface with clustering support
├── docparser.py          # Document processing with Docling
├── clmemory.py           # Chainlit memory layer (InMemoryDataLayer)
└── utils.py              # Base classes (BaseNode, LLMNode, RetrievalNode), decorators, BaseAgent
```

**Key Files**:
- Entry point: `src/pairreader/__main__.py` with `main()` function
- Package script: `pyproject.toml` defines `pairreader = "pairreader.__main__:main"`
- This allows running via `uv run pairreader` or `pairreader` after installation

## Future TODOs (from codebase comments)
- Enhanced table and image extraction from Docling
- Embedding and tokenization-aware chunking
- Retrieve chunks with metadata (e.g., page numbers)
- Move authentication to database with hashed passwords
- Explore OAuth and header-based authentication
- **DiscoveryAgent**: Improve sampling-clustering algorithm to ensure entire knowledge base is covered
- **Context Management**: Debug and optimize `state["messages"]` to balance context retention and token efficiency
