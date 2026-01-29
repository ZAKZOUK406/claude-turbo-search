#!/bin/bash
# setup-mcp.sh - Configure QMD MCP server in Claude Code settings
# Usage: ./setup-mcp.sh [--force]

set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups"

FORCE=false
if [ "$1" = "--force" ]; then
  FORCE=true
fi

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

# Check for existing qmd MCP config
EXISTING_QMD=$(jq -r '.mcpServers.qmd // empty' "$SETTINGS_FILE" 2>/dev/null)
if [ -n "$EXISTING_QMD" ] && [ "$FORCE" != true ]; then
  echo -e "${YELLOW}Warning: Existing qmd MCP server config found in settings.json${NC}"
  echo "  Current: $(echo "$EXISTING_QMD" | jq -c .)"

  # Backup settings
  mkdir -p "$BACKUP_DIR"
  BACKUP_SETTINGS="$BACKUP_DIR/settings.json.$(date +%Y%m%d_%H%M%S).bak"
  cp "$SETTINGS_FILE" "$BACKUP_SETTINGS"
  echo -e "${GREEN}✓${NC} Backed up settings to $BACKUP_SETTINGS"
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
