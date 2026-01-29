#!/bin/bash
# setup-file-suggestion.sh - Install file suggestion script and configure Claude Code
# Usage: ./setup-file-suggestion.sh [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
TARGET_SCRIPT="$CLAUDE_DIR/file-suggestion.sh"
BACKUP_DIR="$CLAUDE_DIR/backups"

FORCE=false
if [ "$1" = "--force" ]; then
  FORCE=true
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Setting up turbo file suggestion..."

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Check for existing file-suggestion.sh
if [ -f "$TARGET_SCRIPT" ] && [ "$FORCE" != true ]; then
  echo -e "${YELLOW}Warning: $TARGET_SCRIPT already exists.${NC}"

  # Create backup
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="$BACKUP_DIR/file-suggestion.sh.$(date +%Y%m%d_%H%M%S).bak"
  cp "$TARGET_SCRIPT" "$BACKUP_FILE"
  echo -e "${GREEN}✓${NC} Backed up existing script to $BACKUP_FILE"
fi

# Copy the file suggestion script
cp "$SCRIPT_DIR/file-suggestion.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
echo -e "${GREEN}✓${NC} Installed file-suggestion.sh to $TARGET_SCRIPT"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

# Check for existing fileSuggestion config
EXISTING_CONFIG=$(jq -r '.fileSuggestion // empty' "$SETTINGS_FILE" 2>/dev/null)
if [ -n "$EXISTING_CONFIG" ] && [ "$FORCE" != true ]; then
  echo -e "${YELLOW}Warning: Existing fileSuggestion config found in settings.json${NC}"
  echo "  Current: $(echo "$EXISTING_CONFIG" | jq -c .)"

  # Backup settings
  mkdir -p "$BACKUP_DIR"
  BACKUP_SETTINGS="$BACKUP_DIR/settings.json.$(date +%Y%m%d_%H%M%S).bak"
  cp "$SETTINGS_FILE" "$BACKUP_SETTINGS"
  echo -e "${GREEN}✓${NC} Backed up settings to $BACKUP_SETTINGS"
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
