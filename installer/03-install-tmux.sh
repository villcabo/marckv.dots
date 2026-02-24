#!/bin/bash

# Script to install marckv.dots tmux configuration
# Creates a symlink from ~/.tmux.conf to repo tmux/.tmux.conf if target doesn't exist

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

# Resolve repository root based on this script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_TMUX_CONF="$MARCKV_DOTS_DIR/tmux/.tmux.conf"
TARGET_TMUX_CONF="$HOME/.tmux.conf"

install_tmux_conf() {
    bold "=== marckv.dots tmux installer ==="

    if [[ ! -f "$SOURCE_TMUX_CONF" ]]; then
        error "Source file not found: $SOURCE_TMUX_CONF"
        exit 1
    fi

    info "Source tmux config: $SOURCE_TMUX_CONF"
    info "Target tmux config: $TARGET_TMUX_CONF"

    if [[ -e "$TARGET_TMUX_CONF" || -L "$TARGET_TMUX_CONF" ]]; then
        if [[ "$TARGET_TMUX_CONF" -ef "$SOURCE_TMUX_CONF" ]]; then
            warn "~/.tmux.conf is already linked to repository config"
            info "No changes needed."
            return 0
        fi

        warn "~/.tmux.conf already exists and points to a different file"
        warn "Skipping to avoid overwriting existing configuration."
        return 0
    fi

    ln -s "$SOURCE_TMUX_CONF" "$TARGET_TMUX_CONF"
    success "Symlink created: $TARGET_TMUX_CONF -> $SOURCE_TMUX_CONF"
}

status_tmux_conf() {
    bold "=== tmux config status ==="

    if [[ ! -f "$SOURCE_TMUX_CONF" ]]; then
        error "Repository tmux config not found: $SOURCE_TMUX_CONF"
        return 1
    fi

    success "Repository tmux config found: $SOURCE_TMUX_CONF"

    if [[ ! -e "$TARGET_TMUX_CONF" && ! -L "$TARGET_TMUX_CONF" ]]; then
        warn "~/.tmux.conf does not exist"
        return 0
    fi

    if [[ "$TARGET_TMUX_CONF" -ef "$SOURCE_TMUX_CONF" ]]; then
        success "~/.tmux.conf is correctly linked to repository config"
    else
        warn "~/.tmux.conf exists but is not linked to repository config"
        if [[ -L "$TARGET_TMUX_CONF" ]]; then
            info "Current symlink target: $(readlink "$TARGET_TMUX_CONF")"
        else
            info "Current target is a regular file"
        fi
    fi
}

uninstall_tmux_conf() {
    bold "=== tmux config uninstaller ==="

    if [[ ! -e "$TARGET_TMUX_CONF" && ! -L "$TARGET_TMUX_CONF" ]]; then
        warn "~/.tmux.conf does not exist, nothing to uninstall"
        return 0
    fi

    if [[ -L "$TARGET_TMUX_CONF" && "$TARGET_TMUX_CONF" -ef "$SOURCE_TMUX_CONF" ]]; then
        rm "$TARGET_TMUX_CONF"
        success "Removed symlink: $TARGET_TMUX_CONF"
        return 0
    fi

    warn "~/.tmux.conf is not managed by this installer"
    warn "Nothing removed to avoid deleting user-managed config."
}

case "${1:-install}" in
    install|i)
        install_tmux_conf
        ;;
    status|s)
        status_tmux_conf
        ;;
    uninstall|u)
        uninstall_tmux_conf
        ;;
    *)
        bold "marckv.dots tmux installer"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo -e "  ${GREEN}$0 [install|i]${NC}    - Create symlink in ~/.tmux.conf (default)"
        echo -e "  ${GREEN}$0 status|s${NC}       - Show installation status"
        echo -e "  ${GREEN}$0 uninstall|u${NC}    - Remove managed symlink"
        echo ""
        ;;
esac
