#!/bin/bash

# Script to install marckv.dots custom bashrc
# Appends a source line to ~/.bashrc pointing to the repo's bash/.bashrc

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASHRC_FILE="$HOME/.bashrc"
MARCK_BASHRC="$MARCKV_DOTS_DIR/bash/.bashrc"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash/.bashrc" ]] && source "$HOME/.marckv.dots/bash/.bashrc"'

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots bash installer"
            echo ""
            echo -e "Appends a source line to ${YELLOW}~/.bashrc${NC} that loads the custom bash config."
            echo -e "Changes in the repo reflect immediately (live sync)."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0"
            echo ""
            exit 0
            ;;
    esac
done

bold "=== marckv.dots bash installer ==="

# Verify marckv.dots directory exists
if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
    error "Directory $MARCKV_DOTS_DIR does not exist."
    exit 1
fi

# Verify custom bashrc exists
if [[ ! -f "$MARCK_BASHRC" ]]; then
    error "File $MARCK_BASHRC not found"
    exit 1
fi

info "marckv.dots directory: $MARCKV_DOTS_DIR"
info "Custom bashrc: $MARCK_BASHRC"

# Create ~/.bashrc if it does not exist
if [[ ! -f "$BASHRC_FILE" ]]; then
    info "Creating ~/.bashrc..."
    touch "$BASHRC_FILE"
fi

# Check if already installed
if grep -Fq "$LOAD_LINE" "$BASHRC_FILE"; then
    warn "Already installed in $BASHRC_FILE"
    info "No changes needed."
    exit 0
fi

# Back up original ~/.bashrc
if [[ -s "$BASHRC_FILE" ]]; then
    backup_file="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup: $backup_file"
    cp "$BASHRC_FILE" "$backup_file"
fi

# Append load line to ~/.bashrc
info "Adding source line to ~/.bashrc..."
echo "" >> "$BASHRC_FILE"
echo "# marckv.dots custom bashrc" >> "$BASHRC_FILE"
echo "$LOAD_LINE" >> "$BASHRC_FILE"

success "Installed successfully!"
echo ""
bold "To apply changes:"
echo -e "  ${YELLOW}source ~/.bashrc${NC}  ${BLUE}# or restart terminal${NC}"
echo ""
