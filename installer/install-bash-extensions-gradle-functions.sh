#!/bin/bash

# Script to install marckv.dots Gradle helper functions
# Appends a source line to ~/.bash_aliases

set -e

# Colors for output (resolved by terminal capability)
GREEN=""
BLUE=""
YELLOW=""
RED=""
BOLD=""
NC=""

init_colors() {
    if [[ -n "${NO_COLOR:-}" || ! -t 1 || "${TERM:-}" == "dumb" ]]; then
        return
    fi
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
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    RED=$'\033[0;31m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
}

init_colors

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Configuration
MARCKV_DOTS_DIR="$HOME/.marckv.dots"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
GRADLE_FUNCTIONS_SOURCE="$MARCKV_DOTS_DIR/bash-extensions/bash_gradle_functions.sh"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" ]] && source "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" # Gradle functions'

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots Gradle functions installer"
            echo ""
            echo -e "Appends a source line to ${YELLOW}~/.bash_aliases${NC} that loads Gradle helper functions."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0"
            echo ""
            exit 0
            ;;
    esac
done

bold "=== marckv.dots Gradle functions installer ==="

# Verify marckv.dots directory and source file exist
if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
    error "Directory $MARCKV_DOTS_DIR does not exist."
    error "Make sure marckv.dots is cloned in your home directory."
    exit 1
fi

if [[ ! -f "$GRADLE_FUNCTIONS_SOURCE" ]]; then
    error "File $GRADLE_FUNCTIONS_SOURCE not found."
    exit 1
fi

info "marckv.dots directory: $MARCKV_DOTS_DIR"
info "Gradle functions source: $GRADLE_FUNCTIONS_SOURCE"

# Create ~/.bash_aliases if it does not exist
if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
    info "Creating ~/.bash_aliases..."
    touch "$BASH_ALIASES_FILE"
fi

# Check if already installed
if grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
    warn "Gradle functions already installed in $BASH_ALIASES_FILE"
    info "No changes needed."
    exit 0
fi

# Back up if not empty
if [[ -s "$BASH_ALIASES_FILE" ]]; then
    backup_file="${BASH_ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup: $backup_file"
    cp "$BASH_ALIASES_FILE" "$backup_file"
    echo "" >> "$BASH_ALIASES_FILE"
fi

info "Adding Gradle functions source line to ~/.bash_aliases..."
echo "$LOAD_LINE" >> "$BASH_ALIASES_FILE"

success "Gradle functions installed successfully!"
echo ""
bold "To apply changes:"
echo -e "  ${YELLOW}source ~/.bash_aliases${NC}  ${BLUE}# or restart terminal${NC}"
echo ""
