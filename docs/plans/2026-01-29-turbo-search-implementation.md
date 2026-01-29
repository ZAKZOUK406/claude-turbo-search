# Claude Turbo Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that provides `/turbo-index` command for optimized file search and semantic indexing in large codebases.

**Architecture:** Standalone plugin with bash scripts for dependency management and file suggestion, plus a markdown skill that orchestrates the setup flow. Integrates QMD as MCP server for semantic search.

**Tech Stack:** Bash scripts, Claude Code plugin format, QMD (Bun), ripgrep, fzf, jq

---

### Task 1: Create Plugin Manifest (package.json)

**Files:**
- Create: `package.json`

**Step 1: Create the package.json**

```json
{
  "name": "claude-turbo-search",
  "version": "1.0.0",
  "description": "Optimized file search and semantic indexing for large codebases in Claude Code",
  "author": "Iago Cavalcante",
  "license": "MIT",
  "keywords": [
    "claude-code",
    "plugin",
    "search",
    "qmd",
    "semantic-search",
    "ripgrep",
    "fzf"
  ],
  "repository": {
    "type": "git",
    "url": "https://github.com/iagocavalcante/claude-turbo-search"
  },
  "claude-code": {
    "skills": [
      "skills/turbo-index.md"
    ]
  }
}
```

**Step 2: Verify the file is valid JSON**

Run: `cd ~/claude-turbo-search && cat package.json | jq .`
Expected: JSON output without errors

**Step 3: Commit**

```bash
git add package.json
git commit -m "feat: add plugin manifest"
```

---

### Task 2: Create Dependency Installer Script

**Files:**
- Create: `scripts/install-deps.sh`

**Step 1: Create the installer script**

```bash
#!/bin/bash
# install-deps.sh - Install dependencies for claude-turbo-search
# Usage: ./install-deps.sh [--check-only]

set -e

CHECK_ONLY=false
if [ "$1" = "--check-only" ]; then
  CHECK_ONLY=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
  local cmd=$1
  local name=$2
  if command -v "$cmd" &> /dev/null; then
    local version=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
    echo -e "  ${GREEN}✓${NC} $name ($version)"
    return 0
  else
    echo -e "  ${RED}✗${NC} $name - not installed"
    return 1
  fi
}

install_with_brew() {
  local package=$1
  local tap=$2

  if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: Homebrew is required but not installed.${NC}"
    echo "Install from: https://brew.sh"
    exit 1
  fi

  if [ -n "$tap" ]; then
    echo "  Adding tap: $tap"
    brew tap "$tap" 2>/dev/null || true
  fi

  echo "  Installing $package..."
  brew install "$package"
}

echo "Checking dependencies..."
echo ""

MISSING=()

check_command "rg" "ripgrep" || MISSING+=("ripgrep")
check_command "fzf" "fzf" || MISSING+=("fzf")
check_command "jq" "jq" || MISSING+=("jq")
check_command "bun" "bun" || MISSING+=("bun")
check_command "qmd" "qmd" || MISSING+=("qmd")

echo ""

if [ ${#MISSING[@]} -eq 0 ]; then
  echo -e "${GREEN}All dependencies installed!${NC}"
  exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
  echo -e "${YELLOW}Missing: ${MISSING[*]}${NC}"
  exit 1
fi

echo -e "${YELLOW}Missing dependencies: ${MISSING[*]}${NC}"
echo ""
read -p "Install missing dependencies? [Y/n] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
  echo "Skipping installation."
  exit 1
fi

for dep in "${MISSING[@]}"; do
  echo ""
  echo -e "${YELLOW}Installing $dep...${NC}"

  case $dep in
    ripgrep)
      install_with_brew "ripgrep"
      ;;
    fzf)
      install_with_brew "fzf"
      ;;
    jq)
      install_with_brew "jq"
      ;;
    bun)
      install_with_brew "bun" "oven-sh/bun"
      ;;
    qmd)
      if ! command -v bun &> /dev/null; then
        echo -e "${RED}Error: bun must be installed first for qmd${NC}"
        exit 1
      fi
      echo "  Installing qmd globally with bun..."
      bun install -g https://github.com/tobi/qmd
      echo -e "${YELLOW}  Note: QMD will download ~1.7GB of models on first use${NC}"
      ;;
  esac

  echo -e "${GREEN}  ✓ $dep installed${NC}"
done

echo ""
echo -e "${GREEN}All dependencies installed!${NC}"
```

**Step 2: Make the script executable**

Run: `chmod +x ~/claude-turbo-search/scripts/install-deps.sh`

**Step 3: Test the check-only mode**

Run: `~/claude-turbo-search/scripts/install-deps.sh --check-only`
Expected: Shows status of each dependency with checkmarks or X marks

**Step 4: Commit**

```bash
git add scripts/install-deps.sh
git commit -m "feat: add dependency installer script"
```

---

### Task 3: Create File Suggestion Script

**Files:**
- Create: `scripts/file-suggestion.sh`

**Step 1: Create the file suggestion script**

```bash
#!/bin/bash
# file-suggestion.sh - Turbo file suggestion for Claude Code
# Combines rg + fzf + QMD awareness for fast, semantic file suggestions

# Parse JSON input to get query
QUERY=$(jq -r '.query // ""')

# Use project dir from env, fallback to pwd
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

# Get project name for QMD collection lookup
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Check if QMD collection exists for semantic boost
QMD_AVAILABLE=false
if command -v qmd &> /dev/null; then
  # Check if collection exists by trying to list it
  if qmd collections 2>/dev/null | grep -q "^$PROJECT_NAME$"; then
    QMD_AVAILABLE=true
  fi
fi

# Semantic search results (if available and query is meaningful)
if [ "$QMD_AVAILABLE" = true ] && [ -n "$QUERY" ] && [ ${#QUERY} -gt 2 ]; then
  # Prepend QMD results for relevant docs
  qmd search "$PROJECT_NAME" "$QUERY" --format=paths --limit=5 2>/dev/null
fi

# Fast file search with rg + fzf
{
  # Main search - respects .gitignore, includes hidden files, follows symlinks
  rg --files --follow --hidden . 2>/dev/null

  # Always include important docs even if gitignored
  [ -e docs/CODEBASE_MAP.md ] && echo "docs/CODEBASE_MAP.md"
  [ -e CLAUDE.md ] && echo "CLAUDE.md"
  [ -e README.md ] && echo "README.md"
} | sort -u | fzf --filter "$QUERY" 2>/dev/null | head -15
```

**Step 2: Make the script executable**

Run: `chmod +x ~/claude-turbo-search/scripts/file-suggestion.sh`

**Step 3: Test the script with a sample query**

Run: `echo '{"query": "readme"}' | ~/claude-turbo-search/scripts/file-suggestion.sh`
Expected: Shows matching files (may be empty if not in a project directory)

**Step 4: Commit**

```bash
git add scripts/file-suggestion.sh
git commit -m "feat: add turbo file suggestion script with QMD integration"
```

---

### Task 4: Create MCP Setup Script

**Files:**
- Create: `scripts/setup-mcp.sh`

**Step 1: Create the MCP setup script**

```bash
#!/bin/bash
# setup-mcp.sh - Configure QMD MCP server in Claude Code settings
# Usage: ./setup-mcp.sh

set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Configuring QMD MCP server..."

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

# Check if qmd is installed
if ! command -v qmd &> /dev/null; then
  echo -e "${YELLOW}Warning: qmd is not installed. MCP server won't work until qmd is available.${NC}"
fi

# Use jq to add/update mcpServers.qmd
# This preserves existing settings while adding/updating the qmd server
UPDATED=$(jq '
  .mcpServers = (.mcpServers // {}) |
  .mcpServers.qmd = {
    "command": "qmd",
    "args": ["mcp"],
    "env": {}
  }
' "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

echo -e "${GREEN}✓${NC} QMD MCP server configured in $SETTINGS_FILE"
echo ""
echo "Available MCP tools after restart:"
echo "  - qmd_search: Semantic search across indexed docs"
echo "  - qmd_get: Retrieve specific document by path"
echo "  - qmd_collections: List indexed projects"
```

**Step 2: Make the script executable**

Run: `chmod +x ~/claude-turbo-search/scripts/setup-mcp.sh`

**Step 3: Commit**

```bash
git add scripts/setup-mcp.sh
git commit -m "feat: add QMD MCP server setup script"
```

---

### Task 5: Create File Suggestion Setup Script

**Files:**
- Create: `scripts/setup-file-suggestion.sh`

**Step 1: Create the setup script**

```bash
#!/bin/bash
# setup-file-suggestion.sh - Install file suggestion script and configure Claude Code
# Usage: ./setup-file-suggestion.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
TARGET_SCRIPT="$CLAUDE_DIR/file-suggestion.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Setting up turbo file suggestion..."

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Copy the file suggestion script
cp "$SCRIPT_DIR/file-suggestion.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
echo -e "${GREEN}✓${NC} Installed file-suggestion.sh to $TARGET_SCRIPT"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

# Use jq to add/update fileSuggestion config
UPDATED=$(jq '
  .fileSuggestion = {
    "type": "command",
    "command": "~/.claude/file-suggestion.sh"
  }
' "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

echo -e "${GREEN}✓${NC} Configured fileSuggestion in $SETTINGS_FILE"
echo ""
echo "File suggestion is now using turbo search!"
echo "Restart Claude Code to apply changes."
```

**Step 2: Make the script executable**

Run: `chmod +x ~/claude-turbo-search/scripts/setup-file-suggestion.sh`

**Step 3: Commit**

```bash
git add scripts/setup-file-suggestion.sh
git commit -m "feat: add file suggestion setup script"
```

---

### Task 6: Create the Turbo Index Skill

**Files:**
- Create: `skills/turbo-index.md`

**Step 1: Create the skill file**

```markdown
---
name: turbo-index
description: Index the current project for optimized search with QMD semantic search and fast file suggestions. Run this when entering a new codebase or after significant changes.
---

# Turbo Index

You are running the turbo-index skill to set up optimized search for this project.

## Instructions

Follow these phases in order. Use the Bash tool to run commands. Report progress to the user after each phase.

### Phase 1: Check Dependencies

Run the dependency checker:

```bash
~/.claude/plugins/*/claude-turbo-search/scripts/install-deps.sh --check-only 2>/dev/null || \
  ~/claude-turbo-search/scripts/install-deps.sh --check-only 2>/dev/null || \
  echo "DEPS_SCRIPT_NOT_FOUND"
```

If dependencies are missing, ask the user if they want to install them. If yes, run without `--check-only`:

```bash
~/.claude/plugins/*/claude-turbo-search/scripts/install-deps.sh 2>/dev/null || \
  ~/claude-turbo-search/scripts/install-deps.sh 2>/dev/null
```

### Phase 2: Global Setup (if needed)

Check if file-suggestion.sh exists in ~/.claude/:

```bash
[ -f ~/.claude/file-suggestion.sh ] && echo "FILE_SUGGESTION_EXISTS" || echo "FILE_SUGGESTION_MISSING"
```

If missing, run the setup scripts:

```bash
# Setup file suggestion
~/.claude/plugins/*/claude-turbo-search/scripts/setup-file-suggestion.sh 2>/dev/null || \
  ~/claude-turbo-search/scripts/setup-file-suggestion.sh 2>/dev/null

# Setup QMD MCP server
~/.claude/plugins/*/claude-turbo-search/scripts/setup-mcp.sh 2>/dev/null || \
  ~/claude-turbo-search/scripts/setup-mcp.sh 2>/dev/null
```

### Phase 3: Run Cartographer (if needed)

Check if codebase map exists and its age:

```bash
if [ -f docs/CODEBASE_MAP.md ]; then
  # Check if older than 24 hours (86400 seconds)
  AGE=$(($(date +%s) - $(stat -f %m docs/CODEBASE_MAP.md 2>/dev/null || stat -c %Y docs/CODEBASE_MAP.md 2>/dev/null)))
  if [ $AGE -gt 86400 ]; then
    echo "CODEBASE_MAP_STALE"
  else
    echo "CODEBASE_MAP_FRESH"
  fi
else
  echo "CODEBASE_MAP_MISSING"
fi
```

If missing or stale, use the Skill tool to invoke cartographer:

```
Skill: cartographer
```

### Phase 4: Index with QMD

Get the project name and create/update the QMD collection:

```bash
PROJECT_NAME=$(basename "$PWD")
echo "Indexing project: $PROJECT_NAME"

# Add the project directory as a QMD collection
qmd add "$PROJECT_NAME" . --glob "**/*.md" --glob "**/README*" --glob "**/CLAUDE.md" --context "Codebase documentation and structure for $PROJECT_NAME"

# Also index code structure files if they exist
if [ -d docs ]; then
  qmd add "$PROJECT_NAME" ./docs --glob "**/*.md" --context "Documentation directory"
fi
```

Store metadata for staleness detection:

```bash
PROJECT_NAME=$(basename "$PWD")
mkdir -p .claude
cat > .claude/turbo-search.json << EOF
{
  "project": "$PROJECT_NAME",
  "lastIndexed": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'not-a-git-repo')",
  "qmdCollection": "$PROJECT_NAME"
}
EOF
echo "Metadata saved to .claude/turbo-search.json"
```

### Phase 5: Report Results

Get indexing stats and report to user:

```bash
PROJECT_NAME=$(basename "$PWD")

# Count indexed files
TOTAL_FILES=$(rg --files --follow --hidden . 2>/dev/null | wc -l | tr -d ' ')
MD_FILES=$(rg --files --glob "**/*.md" . 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "📊 Project \"$PROJECT_NAME\" indexed"
echo "   Total files: $TOTAL_FILES"
echo "   Markdown docs: $MD_FILES"
echo "   Estimated token savings: 60-80% on exploration"
echo ""
echo "✓ QMD semantic search ready"
echo "✓ Turbo file suggestion active"
echo ""
echo "Try asking: \"search for authentication logic\" or \"find the main entry point\""
```

## Notes

- This skill is idempotent - safe to run multiple times
- First run installs dependencies and configures Claude Code globally
- Subsequent runs just refresh the project index
- Restart Claude Code after first run to activate MCP tools
```

**Step 2: Verify the skill file syntax**

Run: `head -20 ~/claude-turbo-search/skills/turbo-index.md`
Expected: Shows the frontmatter and beginning of the skill

**Step 3: Commit**

```bash
git add skills/turbo-index.md
git commit -m "feat: add turbo-index skill with full setup flow"
```

---

### Task 7: Create README

**Files:**
- Create: `README.md`

**Step 1: Create the README**

```markdown
# Claude Turbo Search

Optimized file search and semantic indexing for large codebases in Claude Code.

## Features

- **Fast file suggestions** - ripgrep + fzf for instant autocomplete
- **Semantic search** - QMD integration for finding relevant docs by meaning
- **Cartographer integration** - Automatic codebase mapping
- **One command setup** - `/turbo-index` does everything

## Installation

### Option 1: Clone and link (development)

```bash
git clone https://github.com/iagocavalcante/claude-turbo-search.git ~/claude-turbo-search
cd ~/claude-turbo-search
```

Add to your `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "claude-turbo-search@local": true
  },
  "pluginPaths": {
    "claude-turbo-search@local": "~/claude-turbo-search"
  }
}
```

### Option 2: From marketplace (when published)

```bash
claude plugins install claude-turbo-search
```

## Usage

In any project, run:

```
/turbo-index
```

This will:

1. Check and install dependencies (ripgrep, fzf, jq, bun, qmd)
2. Configure fast file suggestions
3. Set up QMD MCP server for semantic search
4. Run cartographer to map the codebase
5. Index all documentation with QMD

### Subsequent runs

Running `/turbo-index` again will:
- Skip dependency installation
- Skip global configuration
- Refresh the project index if files changed

## Dependencies

| Tool | Purpose |
|------|---------|
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast file search |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [jq](https://github.com/stedolan/jq) | JSON parsing |
| [bun](https://bun.sh) | JavaScript runtime |
| [qmd](https://github.com/tobi/qmd) | Semantic search engine |

All dependencies are installed automatically via Homebrew on first run.

## How It Saves Tokens

### Before (traditional exploration)
```
Read file1.md (2000 tokens)
Read file2.md (1500 tokens)
Read file3.md (1800 tokens)
→ Found answer in file3.md
Total: 5300 tokens
```

### After (with turbo search)
```
qmd_search "how does auth work" (50 tokens)
→ Returns: file3.md lines 45-62 (200 tokens)
Total: 250 tokens
```

**Estimated savings: 60-80% on exploration tasks**

## Configuration

After running `/turbo-index`, these files are modified:

- `~/.claude/settings.json` - fileSuggestion and mcpServers config
- `~/.claude/file-suggestion.sh` - turbo file suggestion script
- `.claude/turbo-search.json` - project-specific metadata (in each project)

## MCP Tools

After setup, these MCP tools are available:

| Tool | Description |
|------|-------------|
| `qmd_search` | Semantic search across indexed docs |
| `qmd_get` | Retrieve specific document by path/ID |
| `qmd_collections` | List all indexed projects |

## License

MIT
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add comprehensive README"
```

---

### Task 8: Test the Plugin Locally

**Step 1: Verify all files exist**

Run: `ls -la ~/claude-turbo-search/`
Expected: Shows package.json, README.md, skills/, scripts/

Run: `ls -la ~/claude-turbo-search/scripts/`
Expected: Shows all 4 scripts with execute permissions

Run: `ls -la ~/claude-turbo-search/skills/`
Expected: Shows turbo-index.md

**Step 2: Test dependency check**

Run: `~/claude-turbo-search/scripts/install-deps.sh --check-only`
Expected: Shows status of each dependency

**Step 3: Configure Claude Code to use the local plugin**

Read current settings, then add plugin path:

```bash
cat ~/.claude/settings.json
```

Then manually add or use jq to add:
```bash
jq '.pluginPaths = (.pluginPaths // {}) | .pluginPaths["claude-turbo-search@local"] = "~/claude-turbo-search" | .enabledPlugins = (.enabledPlugins // {}) | .enabledPlugins["claude-turbo-search@local"] = true' ~/.claude/settings.json > /tmp/settings.json && mv /tmp/settings.json ~/.claude/settings.json
```

**Step 4: Final commit with all work**

```bash
git add -A
git status
git log --oneline
```

Expected: All files committed, clean working tree

---

## Summary

After completing all tasks, you will have:

1. `package.json` - Plugin manifest
2. `scripts/install-deps.sh` - Installs ripgrep, fzf, jq, bun, qmd
3. `scripts/file-suggestion.sh` - Fast file autocomplete with QMD boost
4. `scripts/setup-mcp.sh` - Configures QMD MCP server
5. `scripts/setup-file-suggestion.sh` - Installs file suggestion to ~/.claude/
6. `skills/turbo-index.md` - The main `/turbo-index` command
7. `README.md` - Documentation

The plugin is ready to use with `/turbo-index` in any project!
