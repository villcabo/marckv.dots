#!/bin/bash

# Script to install marckv.dots tmux configuration
# Creates a symlink from ~/.tmux.conf to the repo's tmux/.tmux.conf

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_TMUX_CONF="$MARCKV_DOTS_DIR/tmux/.tmux.conf"
TARGET_TMUX_CONF="$HOME/.tmux.conf"

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots tmux installer"
            echo ""
            echo -e "Creates a symlink from ${YELLOW}~/.tmux.conf${NC} to the repo's tmux config."
            echo -e "Changes in the repo reflect immediately (live sync)."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0"
            echo ""
            exit 0
            ;;
    esac
done

bold "=== marckv.dots tmux installer ==="

# Verify source config exists
if [[ ! -f "$SOURCE_TMUX_CONF" ]]; then
    error "Source file not found: $SOURCE_TMUX_CONF"
    exit 1
fi

info "Source config: $SOURCE_TMUX_CONF"
info "Target config: $TARGET_TMUX_CONF"

# Check if already correctly linked
if [[ -L "$TARGET_TMUX_CONF" && "$TARGET_TMUX_CONF" -ef "$SOURCE_TMUX_CONF" ]]; then
    warn "~/.tmux.conf is already linked to repository config"
    info "No changes needed."
    exit 0
fi

# Skip if target exists but is not our symlink (avoid overwriting user config)
if [[ -e "$TARGET_TMUX_CONF" || -L "$TARGET_TMUX_CONF" ]]; then
    warn "~/.tmux.conf already exists and is not managed by this installer"
    warn "Remove it manually first if you want to replace it:"
    echo -e "  ${YELLOW}rm ~/.tmux.conf${NC}"
    exit 1
fi

ln -s "$SOURCE_TMUX_CONF" "$TARGET_TMUX_CONF"
success "Symlink created: $TARGET_TMUX_CONF -> $SOURCE_TMUX_CONF"
