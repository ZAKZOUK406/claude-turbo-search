#!/bin/bash
# rag-context-hook.sh - RAG-style context injection for Claude Code
# Searches QMD and injects relevant content snippets before each prompt
#
# This hook automatically provides Claude with relevant context from your
# indexed documentation, reducing the need to read files manually.
#
# Usage: Configured as a UserPromptSubmit hook in Claude Code

set -e

# Configuration
MAX_CONTEXT_TOKENS=2000  # Approximate max tokens to inject
MAX_RESULTS=3            # Max number of search results to include
MIN_QUERY_LENGTH=15      # Min prompt length to trigger search

# Get the prompt
PROMPT="${CLAUDE_PROMPT:-$(cat)}"

# Skip if prompt is too short
if [ ${#PROMPT} -lt $MIN_QUERY_LENGTH ]; then
  exit 0
fi

# Skip for certain patterns (commands, simple responses)
if echo "$PROMPT" | grep -qiE "^(/|yes|no|ok|thanks|hi|hello|hey|commit|push|pull|git )"; then
  exit 0
fi

# Check if qmd is available
if ! command -v qmd &> /dev/null; then
  exit 0
fi

# Check if there are indexed collections
if ! qmd status 2>/dev/null | grep -q "Collection"; then
  exit 0
fi

# Extract meaningful search terms from the prompt
# Remove common words and keep substantive terms
extract_search_query() {
  echo "$1" | \
    tr '[:upper:]' '[:lower:]' | \
    tr -cs '[:alnum:]' ' ' | \
    tr ' ' '\n' | \
    grep -vE '^(the|a|an|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|could|should|may|might|must|can|this|that|these|those|it|its|i|you|we|they|he|she|what|how|why|when|where|which|who|whom|and|or|but|if|then|else|for|to|of|in|on|at|by|with|from|about|into|through|during|before|after|above|below|between|under|over|out|up|down|off|just|only|also|very|really|please|help|me|my|your|can|want|need|like|make|create|add|fix|update|change|show|tell|explain|find|search|look|get|write|read|use|implement|build)$' | \
    awk 'length >= 3' | \
    head -8 | \
    tr '\n' ' '
}

SEARCH_QUERY=$(extract_search_query "$PROMPT")

if [ -z "$SEARCH_QUERY" ]; then
  exit 0
fi

# Perform QMD search (fast BM25)
# Get results with snippets in a parseable format
SEARCH_RESULTS=$(qmd search "$SEARCH_QUERY" -n $MAX_RESULTS --json 2>/dev/null || true)

if [ -z "$SEARCH_RESULTS" ] || [ "$SEARCH_RESULTS" = "[]" ]; then
  exit 0
fi

# Parse results and build context
# Extract file paths and snippets from JSON results
CONTEXT=""
RESULT_COUNT=0

# Process JSON results using jq
while IFS= read -r result; do
  if [ -z "$result" ]; then
    continue
  fi

  FILE_PATH=$(echo "$result" | jq -r '.path // .file // .docid // empty' 2>/dev/null)
  SNIPPET=$(echo "$result" | jq -r '.snippet // .content // .text // empty' 2>/dev/null)
  SCORE=$(echo "$result" | jq -r '.score // "N/A"' 2>/dev/null)

  if [ -n "$FILE_PATH" ] && [ -n "$SNIPPET" ]; then
    # Clean up the path (remove qmd:// prefix if present)
    CLEAN_PATH=$(echo "$FILE_PATH" | sed 's|^qmd://[^/]*/||')

    CONTEXT="$CONTEXT
### $CLEAN_PATH (relevance: $SCORE)
\`\`\`
$SNIPPET
\`\`\`
"
    RESULT_COUNT=$((RESULT_COUNT + 1))
  fi
done < <(echo "$SEARCH_RESULTS" | jq -c '.[]' 2>/dev/null)

# If no context was built, try a simpler approach
if [ -z "$CONTEXT" ] || [ $RESULT_COUNT -eq 0 ]; then
  # Fallback: Get file paths and fetch snippets directly
  FILE_PATHS=$(qmd search "$SEARCH_QUERY" --files -n $MAX_RESULTS 2>/dev/null | head -$MAX_RESULTS)

  if [ -n "$FILE_PATHS" ]; then
    CONTEXT=""
    echo "$FILE_PATHS" | while IFS=',' read -r id score path rest; do
      if [ -n "$path" ]; then
        CLEAN_PATH=$(echo "$path" | sed 's|^qmd://[^/]*/||')
        # Get a snippet from the file
        SNIPPET=$(qmd get "$path" -l 30 2>/dev/null | head -30 || true)
        if [ -n "$SNIPPET" ]; then
          CONTEXT="$CONTEXT
### $CLEAN_PATH
\`\`\`
$SNIPPET
\`\`\`
"
        fi
      fi
    done
  fi
fi

# Output the context if we have any
if [ -n "$CONTEXT" ]; then
  echo ""
  echo "<relevant-context source=\"qmd-rag\">"
  echo "The following content was automatically retrieved from your indexed documentation"
  echo "based on your prompt. Use this context to answer without reading additional files"
  echo "unless more detail is needed."
  echo ""
  echo "**Search query:** $SEARCH_QUERY"
  echo "$CONTEXT"
  echo "</relevant-context>"
  echo ""
fi
