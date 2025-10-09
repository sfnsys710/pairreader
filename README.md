# PairReader

A smart document companion that allows you to chat with your books, presentations, notes, and other documents. Upload your files and have conversations with your content using advanced AI capabilities powered by LangGraph and Claude.

## 🎯 What is PairReader?

PairReader is like having a study partner who never forgets anything! It uses a multi-agent architecture to intelligently process your questions, optimize queries, and retrieve relevant information from your documents.

### Three Usage Modes:
- **📖 Default** - Chat with documents you've already uploaded
- **✏️ Update** - Add new documents to your existing collection
- **🆕 Create** - Start fresh with a new knowledge base

All three modes are accessible via clickable buttons at startup or using commands: `/Update`, `/Create`

## 🚀 Quick Start

### Prerequisites
- Python 3.12 or higher
- [uv](https://github.com/astral-sh/uv) package manager
- Anthropic API key

### Installation

```bash
git clone https://github.com/soufianesys710/pairreader.git
cd pairreader
uv sync
```

### Configuration

1. Generate a Chainlit authentication secret:
```bash
uv run chainlit create-secret
```

2. Create a `.env` file with your API keys:
```bash
ANTHROPIC_API_KEY=your_api_key_here
CHAINLIT_AUTH_SECRET=your_secret_from_step_1
```

### Running the Application

```bash
uv run pairreader
```

Then open your browser to `http://localhost:8000`

**Default credentials:** username: `admin`, password: `admin`

## 💡 How to Use

1. **Login** with the default credentials
2. **Choose a mode** when you start:
   - Click a starter button, or
   - Use `/Create` or `/Update` commands
3. **Upload files** (if using Create or Update mode)
   - Supports PDF and text files
   - Up to 5 files at a time (10MB max per file)
4. **Ask questions** about your content naturally
5. **Review and refine** - The system will show you how it's breaking down your question, and you can revise if needed

## ✨ Key Features

### Intelligent Query Processing
- **Query Decomposition**: Automatically breaks complex questions into focused sub-queries
- **Human-in-the-Loop**: Review and approve how your question is being processed
- **Multi-document Retrieval**: Searches across all your uploaded documents

### Advanced Document Processing
- **Smart Chunking**: Uses Docling's HybridChunker for intelligent document segmentation
- **Contextual Embedding**: Chunks are contextualized for better retrieval
- **Persistent Storage**: Your knowledge base is saved in ChromaDB and persists between sessions

### Configurable Settings
Adjust the following in the UI settings panel:

**General Settings:**
- **LLM Selection**: Choose between Claude Haiku (fast) or Sonnet (powerful)
- **Fallback LLM**: Automatic failover if primary model is unavailable
- **Query Decomposition**: Toggle query optimization on/off
- **Retrieval Count**: Control how many document chunks to retrieve (5-20)

**Discovery Agent Settings:**
- **Sampling**: Choose exact count (`n_sample`) or percentage (`p_sample`) of documents to sample
  - Note: `n_sample` takes priority if set above 0
- **Clustering**: Fine-tune cluster granularity and size constraints
  - `cluster_percentage`: Controls how granular the clustering is (lower = more clusters)
  - `min_cluster_size` and `max_cluster_size`: Leave at 0 for automatic sizing (recommended)

## 🏗️ Architecture

PairReader uses a **three-tier LangGraph multi-agent system**:

### Main Agents

1. **PairReaderAgent** (Supervisor)
   - Manages knowledge base operations (Create/Update/Query)
   - Routes queries to specialized sub-agents using LangGraph's Command primitive

2. **QAAgent** - **DEFAULT agent** for answering questions
   - Query optimization and decomposition (optional)
   - Human-in-the-loop review of subqueries
   - Targeted document retrieval from vector store
   - Answer synthesis
   - Handles all regular information requests

3. **DiscoveryAgent** - For explicit exploration only
   - Document retrieval and clustering (ClusterRetriever)
   - Parallel map-reduce summarization (MapSummarizer → ReduceSummarizer)
   - Comprehensive content overview
   - Triggered only by explicit exploration keywords (overview, themes, discover, etc.)

### Intelligent Routing

The system automatically routes your query to the appropriate agent:
- **Most queries** → QAAgent (default for all questions and information requests)
- **"Give me an overview of the documents"** → DiscoveryAgent (explicit exploration)
- **"What are the main themes?"** → DiscoveryAgent (explicit theme exploration)
- **"What does this say about climate change?"** → QAAgent (specific information request)

### Technology Stack
- **UI Framework**: Chainlit for interactive chat interface
- **Orchestration**: LangGraph for multi-agent workflow management
- **LLM**: Anthropic's Claude (Haiku/Sonnet) via LangChain
- **Vector Store**: ChromaDB for semantic search and clustering
- **Document Parser**: Docling for robust PDF and text processing

## 💡 Tips for Best Results

- **Ask natural questions**: The QA agent (default) handles most information requests automatically
- **Use explicit exploration keywords**: Say "overview", "main themes", "key ideas", or "explore" to trigger Discovery mode
- **Iterate**: If the first answer isn't perfect, refine your question based on what you learned
- **Organize your knowledge base**: Use Create mode to start fresh when switching to a completely different topic
- **Review subqueries**: When your question is decomposed, review the subqueries—it helps you understand what's being searched
- **Start with exploration**: Use Discovery mode first with new documents to understand what's available

## 🔧 Development

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
uv sync --group dev  # Includes Jupyter for experimentation
```

## 📁 Project Structure

```
pairreader/
├── src/pairreader/
│   ├── __main__.py           # Application entry point
│   ├── agents.py             # Multi-agent orchestration (PairReaderAgent, QAAgent, DiscoveryAgent)
│   ├── pairreader_nodes.py   # Supervisor nodes (KnowledgeBaseHandler, QADiscoveryRouter)
│   ├── qa_nodes.py           # QA Agent nodes (QueryOptimizer, InfoRetriever, etc.)
│   ├── discovery_nodes.py    # Discovery Agent nodes (ClusterRetriever, MapSummarizer, ReduceSummarizer)
│   ├── schemas.py            # Shared state definitions
│   ├── prompts_msgs.py       # Centralized prompts and messages
│   ├── vectorestore.py       # ChromaDB interface with clustering support
│   ├── docparser.py          # Document processing
│   └── utils.py              # Decorators, mixins, and utilities
├── pyproject.toml            # Project configuration
└── CLAUDE.md                 # Developer documentation
```

## 🚧 Roadmap

- [ ] Enhanced table and image extraction from documents
- [ ] Embedding-aware chunking strategies
- [ ] Page number and source attribution in responses
- [ ] Improve Discovery Agent sampling to ensure full data coverage
- [ ] Secure authentication with database backend
- [ ] Support for additional document formats (Word, Excel, etc.)
- [ ] OAuth and SSO integration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## 🙏 Acknowledgments

Built with these amazing open-source projects:
- [Chainlit](https://chainlit.io/) - Interactive chat interface
- [LangGraph](https://langchain-ai.github.io/langgraph/) - Multi-agent orchestration
- [ChromaDB](https://www.trychroma.com/) - Vector database
- [Docling](https://docling-project.github.io/docling/) - Document parsing
- [Anthropic Claude](https://www.anthropic.com/) - Language models

## 📄 License

This project is open source and available under standard terms.

---

**Happy reading with your AI pair!** 📖✨
