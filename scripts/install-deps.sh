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
