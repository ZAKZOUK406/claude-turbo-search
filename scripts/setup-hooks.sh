#!/bin/bash
# setup-hooks.sh - Configure Claude Code hooks for automatic QMD context injection
# Usage: ./setup-hooks.sh [--remove]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$1" = "--remove" ]; then
  echo "Removing turbo-search hooks..."

  if [ -f "$SETTINGS_FILE" ]; then
    # Remove our hook from the hooks array
    UPDATED=$(jq 'del(.hooks[] | select(.command | contains("pre-prompt-search")))' "$SETTINGS_FILE" 2>/dev/null || cat "$SETTINGS_FILE")
    echo "$UPDATED" > "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Hooks removed from settings.json"
  fi

  exit 0
fi

echo "Setting up turbo-search hooks..."

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

# Determine the hook script path (try plugin location first, then dev location)
HOOK_SCRIPT=""
for path in \
  "$HOME/.claude/plugins/"*"/claude-turbo-search/hooks/pre-prompt-search.sh" \
  "$HOME/claude-turbo-search/hooks/pre-prompt-search.sh" \
  "$PLUGIN_DIR/hooks/pre-prompt-search.sh"; do
  if [ -f "$path" ]; then
    HOOK_SCRIPT="$path"
    break
  fi
done

if [ -z "$HOOK_SCRIPT" ]; then
  echo -e "${RED}Error: Could not find pre-prompt-search.sh hook script${NC}"
  exit 1
fi

echo "Using hook script: $HOOK_SCRIPT"

# Check if hooks are already configured
EXISTING_HOOK=$(jq -r '.hooks[]? | select(.command | contains("pre-prompt-search")) | .command' "$SETTINGS_FILE" 2>/dev/null)
if [ -n "$EXISTING_HOOK" ]; then
  echo -e "${YELLOW}Warning: Hook already configured${NC}"
  echo "  Current: $EXISTING_HOOK"

  # Backup settings
  mkdir -p "$BACKUP_DIR"
  BACKUP_SETTINGS="$BACKUP_DIR/settings.json.$(date +%Y%m%d_%H%M%S).bak"
  cp "$SETTINGS_FILE" "$BACKUP_SETTINGS"
  echo -e "${GREEN}✓${NC} Backed up settings to $BACKUP_SETTINGS"
fi

# Add the hook to settings.json
# Hook runs on UserPromptSubmit event and injects context
UPDATED=$(jq --arg hook "$HOOK_SCRIPT" '
  .hooks = (.hooks // []) |
  .hooks = [.hooks[] | select(.command | contains("pre-prompt-search") | not)] |
  .hooks += [{
    "event": "UserPromptSubmit",
    "command": $hook,
    "timeout": 5000
  }]
' "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

echo -e "${GREEN}✓${NC} Hook configured in $SETTINGS_FILE"
echo ""
echo "The hook will automatically search QMD before each prompt and"
echo "inject relevant file suggestions to help save tokens."
echo ""
echo "To remove the hook, run: $0 --remove"
echo "Restart Claude Code to apply changes."
