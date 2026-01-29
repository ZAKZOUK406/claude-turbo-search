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
