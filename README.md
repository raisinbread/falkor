# Falkor Combat Script

A Mudlet combat automation script for Achaea, featuring auto-attack, butterfly catching, and rat farming capabilities.

## Prerequisites

Lua is required to build the project. On macOS, install it via Homebrew:

```bash
brew install lua
```

## Project Structure

```
falkor/
├── src/              # Source Lua files (edit these)
│   ├── log.lua       # Logging utilities
│   ├── main.lua      # Core utilities and startup
│   ├── player.lua    # Combat and prompt handling
│   ├── runewarden.lua # Battlerage abilities
│   ├── butterflies.lua # Butterfly catching
│   └── rats.lua      # Rat farming
├── build/            # Build output (generated, don't edit)
├── .vscode/          # VSCode configuration
│   └── tasks.json    # Build task configuration
├── build.lua         # Build script
└── README.md         # This file
```

## Building

To build the project, you can use either method:

### Command Line
```lua
lua build.lua
```

### VSCode
Press `Cmd+Shift+B` (or `Ctrl+Shift+B` on Windows/Linux) to run the "🐉 Build Falkor" task.

Building creates a new Mudlet XML package file.

## Usage in Mudlet

1. Build the project.
2. Open Mudlet
3. Open the Module Manager () (Toolbox > Module Manager)
4. Press the Install button, navigating to the XML file to complete the installation.

## Commands

### Combat
- `att <target>` - Begin auto-attacking a target
- `stop` - Stop auto-attacking

### Battlerage (Runewarden)
- `autocollide` - Toggle auto-Collide (14 rage, 16s cooldown)
- `autobulwark` - Toggle auto-Bulwark (28 rage, 45s cooldown)
- `collide [target]` - Manually use Collide
- `bulwark` - Manually use Bulwark
- `rage` - Show current rage and ability status

### Utility
- `butterflies` - Toggle butterfly catching
- `butterflies-start` - Walk to Vellis and set up butterfly catching
- `sellbutterflies` - Walk to Vellis and sell butterflies
- `sellrats` - Walk to Hakhim and sell rats

### Knowledge Base
- `fquery <question>` - Query the local knowledge base (requires Pinecone setup)
  - Example: `fquery What are the tenets of Targossas?`
  - Example: `fquery Explain devotion`

### System
- `falkor` - Reinstall Falkor module (automatically cleans up and shows what was removed)
- `fregistry` - Show registry statistics (triggers, aliases, timers)
- `ftriggers` - List all registered triggers
- `faliases` - List all registered aliases
- `ftimers` - List all active timers
- `fconfig` - Show or set configuration values

## Features

### Balance & Queue System
Falkor includes a self-contained balance tracking and command queue system:
- Automatic balance/equilibrium detection from prompts
- Intelligent command queuing with priority support
- Balanceful function system for repeating combat actions
- No external dependencies required
- No command stacking or timing issues

### Battlerage System
The Runewarden module provides intelligent battlerage ability management:
- **Auto-Collide**: Automatically uses Collide when you have 14+ rage
- **Auto-Bulwark**: Automatically uses Bulwark when you have 28+ rage
- Tracks cooldowns (16s for Collide, 45s for Bulwark)
- Manual override commands available
- Real-time rage tracking from prompt

### Auto-Attack
- Intelligent target tracking from game prompt
- Automatic attack queueing via built-in queue system
- Auto-disables on target death or error conditions
- Integrates with battlerage abilities

## Code Organization

The code follows Lua best practices:
- Uses a namespace pattern (`Falkor = Falkor or {}`) to avoid global pollution
- Object-oriented style with `self` for method calls
- Proper initialization and cleanup for reloading
- Modular structure ready for expansion
- Self-contained with no external dependencies

## Development

- Edit files in `src/` directory
- Build the project
- Issue the `falkor` command in Mudlet to re-load the module.

### Clean Reload System

Falkor includes a comprehensive cleanup system to prevent duplicate triggers, aliases, and event handlers when reloading:

**Automatic Cleanup**: The `falkor` command automatically cleans up all resources before reinstalling and shows you what was removed:
- All registered triggers and aliases
- All event handlers (GMCP listeners, etc.)
- All tracked timers
- Persistent actions and callbacks
- Combat state and hunting targets

**Registry System**: All triggers, aliases, and timers are tracked in a central registry:
- Use `fregistry` to see counts of registered resources
- Use `ftriggers`, `faliases`, or `ftimers` to list specific resources
- The registry automatically prevents duplicates by cleaning up old instances before creating new ones

**Best Practices**:
- Always use `Falkor:registerTrigger()` and `Falkor:registerAlias()` instead of `tempTrigger()` and `tempAlias()`
- Use `Falkor:registerTimer()` for timers that should be tracked and cleaned up
- The `falkor` command is now safe to use repeatedly without needing to reset the client

## Pinecone Integration

This project includes TypeScript tooling for document ingestion and querying with Pinecone.

### Setup

1. Install dependencies: `pnpm install`
2. Copy `.env.example` to `.env` and configure your Pinecone credentials
3. Install Ollama and pull the required models:
   - `ollama pull nomic-embed-text` (for embeddings)
   - `ollama pull llama3.2:3b` (for responses)
4. Place text files (`.txt`, `.md`, `.markdown`) in the `docs/` directory
5. Run ingestion: `pnpm ingest:docs`

### Scripts

#### Ingestion
```bash
# Ingest all documents from the docs directory
pnpm ingest:docs

# Ingest a specific file
pnpm ingest path/to/file.txt
```

#### Query
```bash
# Query the knowledge base
pnpm query "What are the tenets of Targossas?"

# Query with custom number of results (default: 5)
pnpm query "What is devotion?" --topK 10

# Query with a different model (default: llama3.2:3b)
pnpm query "Explain the Bloodsworn" --model llama3.2:3b
```

The query script will:
1. Generate an embedding for your question
2. Search Pinecone for the most relevant document chunks
3. Feed the results to a local Ollama model (llama3.2:3b by default)
4. Stream the AI-generated response based on your documents
