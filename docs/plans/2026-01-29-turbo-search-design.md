# Claude Turbo Search Plugin Design

## Overview

A Claude Code plugin that optimizes file search and context gathering for large codebases (1000-10,000+ files). Combines fast file suggestion (rg + fzf), semantic search (QMD), and codebase mapping (cartographer) into a single `/turbo-index` command.

## Problem Statement

Working with large codebases in Claude Code is token-expensive:
- File suggestion can be slow
- Context gathering reads many files to find relevant information
- Finding related documentation requires manual exploration
- No semantic understanding of codebase structure

## Solution

A single `/turbo-index` slash command that:
1. Installs and configures all dependencies
2. Sets up fast file suggestion via rg + fzf
3. Indexes the project with QMD for semantic search
4. Integrates with cartographer for structural awareness
5. Exposes search via MCP tools

## Plugin Structure

```
claude-turbo-search/
├── package.json           # Plugin manifest
├── skills/
│   └── turbo-index.md     # Main slash command
├── scripts/
│   ├── file-suggestion.sh # Fast file autocomplete
│   ├── install-deps.sh    # Dependency installer
│   └── setup-mcp.sh       # QMD MCP configuration
└── README.md
```

## Dependencies

| Tool | Purpose | Installation |
|------|---------|--------------|
| ripgrep | Fast file search | `brew install ripgrep` |
| fzf | Fuzzy finder | `brew install fzf` |
| jq | JSON parsing | `brew install jq` |
| bun | JS runtime for QMD | `brew install oven-sh/bun/bun` |
| qmd | Semantic search | `bun install -g https://github.com/tobi/qmd` |

## `/turbo-index` Command Flow

### Phase 1: Dependency Check

Verify installed, prompt to install if missing:
- ripgrep (rg)
- fzf
- jq
- bun
- qmd

### Phase 2: Global Setup (once per machine)

Only runs if not already configured:
- Write `file-suggestion.sh` to `~/.claude/`
- Add `fileSuggestion` config to `~/.claude/settings.json`
- Configure QMD MCP server in settings

### Phase 3: Project Indexing (every run)

- Detect project root (git root or cwd)
- Run `/cartographer` if `docs/CODEBASE_MAP.md` missing or stale
- Create QMD collection named after project directory
- Index: `**/*.md`, plus extracted code structure
- Store collection config in `.claude/turbo-search.json`

### Phase 4: Report

- Show files indexed count
- Show estimated token savings
- Confirm MCP tools available

## File Suggestion Script

Enhanced `~/.claude/file-suggestion.sh`:

```bash
#!/bin/bash
# Turbo file suggestion for Claude Code
# Combines rg + fzf + QMD awareness

QUERY=$(jq -r '.query // ""')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

# Check if QMD collection exists for this project
PROJECT_NAME=$(basename "$PROJECT_DIR")
QMD_COLLECTION="$HOME/.qmd/collections/$PROJECT_NAME"

if [ -d "$QMD_COLLECTION" ] && [ -n "$QUERY" ]; then
  # Semantic boost: prepend QMD results for relevant docs
  qmd search "$PROJECT_NAME" "$QUERY" --format=paths --limit=5 2>/dev/null
fi

# Fast file search with rg + fzf
{
  rg --files --follow --hidden . 2>/dev/null
  # Include cartographer output even if gitignored
  [ -e docs/CODEBASE_MAP.md ] && echo "docs/CODEBASE_MAP.md"
} | sort -u | fzf --filter "$QUERY" | head -15
```

## QMD MCP Configuration

Added to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"],
      "env": {}
    }
  }
}
```

### Available MCP Tools

| Tool | Purpose | Token Savings |
|------|---------|---------------|
| `qmd_search` | Semantic search across indexed docs | Find relevant files without reading everything |
| `qmd_get` | Retrieve specific doc by path/ID | Get exact content with line numbers |
| `qmd_collections` | List indexed projects | Know what's available |

## Cartographer Integration

### On `/turbo-index` run:

1. Check `docs/CODEBASE_MAP.md` exists and age
   - Missing → Run `/cartographer` first
   - Older than 24h → Suggest refresh
   - Fresh → Skip to indexing

2. Index with QMD:
   - `docs/CODEBASE_MAP.md` (high priority)
   - `docs/**/*.md`
   - `README.md`, `CLAUDE.md`
   - Code structure extraction:
     - Function/class signatures
     - Module exports
     - Comment blocks (JSDoc, docstrings)

3. Store metadata in `.claude/turbo-search.json`:
```json
{
  "project": "my-app",
  "lastIndexed": "2026-01-29T10:30:00Z",
  "filesIndexed": 847,
  "cartographerVersion": "1.2.0",
  "qmdCollection": "my-app"
}
```

### Staleness Detection

- Git: Compare last indexed commit vs HEAD
- Non-git: Compare file modification times
- Prompt to re-index if significant changes detected

## User Experience

### First time setup (any machine):

```
$ claude
> /turbo-index

🔍 Turbo Search Setup

Checking dependencies...
  ✓ ripgrep (3.1.0)
  ✓ fzf (0.46.0)
  ✓ jq (1.7)
  ✗ bun - not installed
  ✗ qmd - not installed

Install missing dependencies? [Y/n] y

Installing bun... ✓
Installing qmd... ✓ (downloading models ~1.7GB)

Configuring Claude Code...
  ✓ file-suggestion.sh installed
  ✓ settings.json updated
  ✓ QMD MCP server registered

Running cartographer... ✓
Indexing with QMD... ✓

📊 Project "my-app" indexed
   Files: 2,847
   Docs: 43 markdown files
   Estimated token savings: 60-80% on exploration

Ready! Try: "search for authentication logic"
```

### Subsequent runs:

```
> /turbo-index

🔄 Refreshing index for "my-app"
   Last indexed: 2 hours ago
   Changes detected: 12 files

Re-indexing... ✓ (3.2s)
```

## Token Savings Analysis

### Before (traditional exploration):
```
Read file1.md (2000 tokens)
Read file2.md (1500 tokens)
Read file3.md (1800 tokens)
→ Found answer in file3.md
Total: 5300 tokens
```

### After (with QMD):
```
qmd_search "how does auth work" (50 tokens response)
→ Returns: file3.md lines 45-62 (200 tokens)
Total: 250 tokens
```

**Estimated savings: 60-80% on exploration tasks**

## Future Enhancements

- Auto-reindex on file save via hooks
- Project profiles for different indexing strategies
- Integration with other search tools (ripgrep-all for PDFs, etc.)
- Shared indexes for monorepo workspaces
