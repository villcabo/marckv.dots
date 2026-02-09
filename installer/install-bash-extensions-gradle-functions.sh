#!/bin/bash

# Script to install marckv.dots Gradle helper functions
# This script adds a source line in ~/.bash_aliases

set -e

# Colors for output (resolved by terminal capability)
GREEN=""
BLUE=""
YELLOW=""
RED=""
BOLD=""
NC=""

init_colors() {
    # Disable colors for non-interactive output, TERM=dumb, or NO_COLOR opt-out.
    if [[ -n "${NO_COLOR:-}" || ! -t 1 || "${TERM:-}" == "dumb" ]]; then
        return
    fi

    # Prefer terminfo capabilities when available.
    if command -v tput >/dev/null 2>&1; then
        local ncolors
        ncolors="$(tput colors 2>/dev/null || echo 0)"
        if [[ "$ncolors" =~ ^[0-9]+$ ]] && (( ncolors >= 8 )); then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            BOLD="$(tput bold)"
            NC="$(tput sgr0)"
            return
        fi
    fi

    # Fallback to ANSI escape codes.
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    RED=$'\033[0;31m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
}

init_colors

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

# Configuration
MARCK_DOTS_DIR="$HOME/.marckv.dots"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
GRADLE_FUNCTIONS_SOURCE="$MARCK_DOTS_DIR/bash-extensions/bash_gradle_functions.sh"

# Line to be added to ~/.bash_aliases
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" ]] && source "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" # Gradle functions'

install_gradle_functions() {
    bold "=== marckv.dots Gradle functions installer ==="

    if [[ ! -d "$MARCK_DOTS_DIR" ]]; then
        error "Directory $MARCK_DOTS_DIR does not exist."
        error "Make sure marckv.dots is cloned in your home directory."
        exit 1
    fi

    if [[ ! -f "$GRADLE_FUNCTIONS_SOURCE" ]]; then
        error "File $GRADLE_FUNCTIONS_SOURCE not found."
        error "Please ensure bash-extensions/bash_gradle_functions.sh exists in marckv.dots."
        exit 1
    fi

    info "marckv.dots directory found: $MARCK_DOTS_DIR"
    info "Gradle functions source: $GRADLE_FUNCTIONS_SOURCE"

    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        info "Creating ~/.bash_aliases since it doesn't exist..."
        touch "$BASH_ALIASES_FILE"
    fi

    if grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        warn "Gradle functions are already installed in $BASH_ALIASES_FILE"
        info "No changes needed."
        return 0
    fi

    if [[ -s "$BASH_ALIASES_FILE" ]]; then
        local backup_file="${BASH_ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup of ~/.bash_aliases in $backup_file"
        cp "$BASH_ALIASES_FILE" "$backup_file"
        echo "" >> "$BASH_ALIASES_FILE"
    fi

    info "Adding Gradle functions loading to ~/.bash_aliases..."
    echo "$LOAD_LINE" >> "$BASH_ALIASES_FILE"

    success "Gradle functions installed successfully!"
    echo ""
    bold "To apply changes:"
    echo -e "  ${YELLOW}source ~/.bash_aliases${NC}  ${BLUE}# or restart terminal${NC}"
}

uninstall_gradle_functions() {
    bold "=== marckv.dots Gradle functions uninstaller ==="

    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        warn "~/.bash_aliases doesn't exist, nothing to uninstall."
        return 0
    fi

    if ! grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        warn "Gradle functions are not installed."
        return 0
    fi

    local backup_file="${BASH_ALIASES_FILE}.uninstall_backup.$(date +%Y%m%d_%H%M%S)"
    local temp_file
    temp_file="$(mktemp)"

    info "Creating backup in $backup_file"
    cp "$BASH_ALIASES_FILE" "$backup_file"

    info "Removing Gradle functions configuration from ~/.bash_aliases..."
    awk -v line="$LOAD_LINE" '$0 != line { print }' "$BASH_ALIASES_FILE" > "$temp_file"
    mv "$temp_file" "$BASH_ALIASES_FILE"

    # Remove empty line at the end if present
    sed -i '${/^[[:space:]]*$/d;}' "$BASH_ALIASES_FILE"

    success "Gradle functions uninstalled successfully!"
    info "Backup created in: $backup_file"
}

status_gradle_functions() {
    bold "=== marckv.dots Gradle functions status ==="

    if [[ ! -d "$MARCK_DOTS_DIR" ]]; then
        error "marckv.dots directory not found: $MARCK_DOTS_DIR"
        return 1
    else
        success "marckv.dots directory: $MARCK_DOTS_DIR"
    fi

    if [[ ! -f "$GRADLE_FUNCTIONS_SOURCE" ]]; then
        error "Gradle functions file not found: $GRADLE_FUNCTIONS_SOURCE"
        return 1
    else
        success "Gradle functions source: $GRADLE_FUNCTIONS_SOURCE"
    fi

    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        warn "~/.bash_aliases doesn't exist"
    elif grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        success "Gradle functions are INSTALLED in ~/.bash_aliases"
    else
        warn "Gradle functions are NOT installed in ~/.bash_aliases"
    fi

    echo ""
    info "System: $(uname -sr)"
    info "Current shell: $SHELL"
}

show_help() {
    bold "marckv.dots Gradle functions installer"
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  ${GREEN}$0 [install|i]${NC}      - Install Gradle functions (default)"
    echo -e "  ${GREEN}$0 uninstall|u${NC}      - Uninstall Gradle functions"
    echo -e "  ${GREEN}$0 --uninstall${NC}      - Uninstall Gradle functions"
    echo -e "  ${GREEN}$0 status|s${NC}         - Show installation status"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${GREEN}$0${NC}"
    echo -e "  ${GREEN}$0 install${NC}"
    echo -e "  ${GREEN}$0 --uninstall${NC}"
    echo -e "  ${GREEN}$0 status${NC}"
    echo ""
}

case "${1:-install}" in
    install|i)
        install_gradle_functions
        ;;
    uninstall|u|--uninstall)
        uninstall_gradle_functions
        ;;
    status|s|--status)
        status_gradle_functions
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        show_help
        ;;
esac
