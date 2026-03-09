#!/bin/bash

# Script to install marckv.dots custom bashrc
# This script modifies system ~/.bashrc to load our custom bashrc

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASHRC_FILE="$HOME/.bashrc"
MARCK_BASHRC="$MARCKV_DOTS_DIR/bash/.bashrc"

# Line to be added to system ~/.bashrc
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash/.bashrc" ]] && source "$HOME/.marckv.dots/bash/.bashrc"'

install_bashrc() {
    bold "=== marckv.dots custom bashrc installer ==="

    # Verify marckv.dots directory exists
    if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
        error "Directory $MARCKV_DOTS_DIR does not exist."
        error "Make sure the volume is properly mounted in the container."
        exit 1
    fi

    # Verify custom bashrc exists
    if [[ ! -f "$MARCK_BASHRC" ]]; then
        error "File $MARCK_BASHRC not found"
        exit 1
    fi

    info "marckv.dots directory found: $MARCKV_DOTS_DIR"
    info "Custom bashrc file: $MARCK_BASHRC"

    # Create ~/.bashrc if it does not exist
    if [[ ! -f "$BASHRC_FILE" ]]; then
        info "Creating ~/.bashrc since it doesn't exist..."
        touch "$BASHRC_FILE"
    fi

    # Check if already installed
    if grep -Fq "$LOAD_LINE" "$BASHRC_FILE"; then
        warn "Custom bashrc is already installed in $BASHRC_FILE"
        info "No changes needed."
        return 0
    fi

    # Back up original ~/.bashrc
    if [[ -s "$BASHRC_FILE" ]]; then
        local backup_file="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup of ~/.bashrc in $backup_file"
        cp "$BASHRC_FILE" "$backup_file"
    fi

    # Append load line to ~/.bashrc
    info "Adding custom bashrc loading to ~/.bashrc..."
    echo "" >> "$BASHRC_FILE"
    echo "# marckv.dots custom bashrc" >> "$BASHRC_FILE"
    echo "$LOAD_LINE" >> "$BASHRC_FILE"

    success "Custom bashrc installed successfully!"
    echo ""
    bold "To apply changes:"
    echo -e "  ${YELLOW}source ~/.bashrc${NC}  ${BLUE}# or restart terminal${NC}"
    echo ""
    info "robbyrussell prompt and features are now available."
}

# Function to uninstall
uninstall_bashrc() {
    bold "=== Custom bashrc uninstaller ==="

    if [[ ! -f "$BASHRC_FILE" ]]; then
        warn "~/.bashrc doesn't exist, nothing to uninstall."
        return 0
    fi

    if ! grep -Fq "$LOAD_LINE" "$BASHRC_FILE"; then
        warn "Custom bashrc is not installed."
        return 0
    fi

    # Create backup before modifying
    local backup_file="${BASHRC_FILE}.uninstall_backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup in $backup_file"
    cp "$BASHRC_FILE" "$backup_file"

    # Remove lines related to marckv.dots
    info "Removing marckv.dots configuration from ~/.bashrc..."
    sed -i '/# marckv.dots custom bashrc/d' "$BASHRC_FILE"
    sed -i '\|'"$LOAD_LINE"'|d' "$BASHRC_FILE"

    # Remove empty lines at the end
    sed -i '${/^[[:space:]]*$/d;}' "$BASHRC_FILE"

    success "Custom bashrc uninstalled successfully!"
    info "Backup created in: $backup_file"
}

# Function to show status
status_bashrc() {
    bold "=== Custom bashrc status ==="

    if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
        error "marckv.dots directory not found: $MARCKV_DOTS_DIR"
        return 1
    else
        success "marckv.dots directory: $MARCKV_DOTS_DIR"
    fi

    if [[ ! -f "$MARCK_BASHRC" ]]; then
        error "Custom bashrc not found: $MARCK_BASHRC"
        return 1
    else
        success "Custom bashrc: $MARCK_BASHRC"
    fi

    if [[ ! -f "$BASHRC_FILE" ]]; then
        warn "~/.bashrc doesn't exist"
    elif grep -Fq "$LOAD_LINE" "$BASHRC_FILE"; then
        success "Custom bashrc is INSTALLED in ~/.bashrc"
    else
        warn "Custom bashrc is NOT installed in ~/.bashrc"
    fi

    echo ""
    info "System: $(uname -sr)"
    if command -v lsb_release >/dev/null 2>&1; then
        info "Distribution: $(lsb_release -d | cut -f2)"
    fi
    info "Current shell: $SHELL"
}

# Main menu
case "${1:-install}" in
    install|i)
        install_bashrc
        ;;
    uninstall|u)
        uninstall_bashrc
        ;;
    status|s)
        status_bashrc
        ;;
    *)
        bold "marckv.dots custom bashrc installer"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo -e "  ${GREEN}$0 [install|i]${NC}    - Install custom bashrc (default)"
        echo -e "  ${GREEN}$0 uninstall|u${NC}    - Uninstall custom bashrc"
        echo -e "  ${GREEN}$0 status|s${NC}       - Show installation status"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  ${GREEN}$0${NC}                 # Install"
        echo -e "  ${GREEN}$0 install${NC}         # Install"
        echo -e "  ${GREEN}$0 uninstall${NC}       # Uninstall"
        echo -e "  ${GREEN}$0 status${NC}          # Check status"
        echo ""
        ;;
esac
