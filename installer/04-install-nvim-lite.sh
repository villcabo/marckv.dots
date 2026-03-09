#!/bin/bash

# Script to install marckv.dots nvim-lite configuration
# Default: creates a symlink from ~/.config/nvim to repo nvim-lite/
# With -c/--copy: copies the directory instead (useful for remote servers without repo access)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Resolve repository root based on this script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_NVIM_LITE="$MARCKV_DOTS_DIR/nvim-lite"
TARGET_NVIM_LITE="$HOME/.config/nvim"

# Parse flags
use_copy=false
for arg in "$@"; do
    case "$arg" in
        -c|--copy) use_copy=true ;;
        -h|--help)
            bold "marckv.dots nvim-lite installer"
            echo ""
            echo -e "${BLUE}Usage:${NC} $0 [-c|--copy]"
            echo ""
            echo -e "  ${YELLOW}-c, --copy${NC}   Copy the config directory instead of creating a symlink."
            echo -e "               Useful for remote servers where the repo won't be available."
            echo ""
            echo -e "  By default, a symlink is created so changes in the repo reflect immediately."
            echo ""
            exit 0
            ;;
    esac
done

if [[ "$use_copy" == true ]]; then
    bold "=== marckv.dots nvim-lite installer (copy mode) ==="
else
    bold "=== marckv.dots nvim-lite installer (symlink mode) ==="
fi

# Verify source directory exists
if [[ ! -d "$SOURCE_NVIM_LITE" ]]; then
    error "Source directory not found: $SOURCE_NVIM_LITE"
    exit 1
fi

# Verify Neovim is installed
if ! command -v nvim >/dev/null 2>&1; then
    error "Neovim is not installed."
    info "Install Neovim first: ${BOLD}sudo ./install-nvim.sh${NC}"
    exit 1
fi

# Helper: install packages via apt respecting root/sudo/no-access
_apt_install() {
    if [[ $EUID -eq 0 ]]; then
        apt-get install -y "$@"
    elif sudo -n true 2>/dev/null; then
        sudo apt-get install -y "$@"
    else
        error "Cannot install $*: no root or sudo access."
        info "Run manually: ${BOLD}sudo apt-get install -y $*${NC}"
        exit 1
    fi
}

# Check gcc — required by nvim-treesitter to compile language parsers
if ! command -v gcc >/dev/null 2>&1; then
    warn "gcc not found — required by nvim-treesitter to compile parsers."
    if command -v apt-get >/dev/null 2>&1; then
        info "Installing gcc via apt..."
        _apt_install gcc
        success "gcc installed: $(gcc --version | head -n1)"
    else
        error "Cannot install gcc automatically (apt-get not available)."
        info "Install manually: ${BOLD}sudo apt-get install -y gcc${NC}"
        exit 1
    fi
else
    success "gcc found: $(gcc --version | head -n1)"
fi

# tree-sitter-cli is NOT required: nvim-lite uses only Neovim's built-in
# parsers (bash, lua, python, markdown, vim, vimdoc, etc.) — no compilation
# needed on the server. Extra parsers can be added later with :TSInstall.

nvim_version=$(nvim --version | head -n1)
info "Neovim found: $nvim_version"
info "Source config: $SOURCE_NVIM_LITE"
info "Target config: $TARGET_NVIM_LITE"
if [[ "$use_copy" == true ]]; then
    info "Mode: ${BOLD}copy${NC} (independent — changes in repo will NOT reflect automatically)"
else
    info "Mode: ${BOLD}symlink${NC} (live — changes in repo reflect immediately)"
fi

# Ensure ~/.config exists
mkdir -p "$HOME/.config"

# Check if already installed correctly (symlink mode only)
if [[ "$use_copy" == false && -L "$TARGET_NVIM_LITE" && "$TARGET_NVIM_LITE" -ef "$SOURCE_NVIM_LITE" ]]; then
    warn "nvim-lite is already linked to repository config"
    info "No changes needed."
    exit 0
fi

# Handle existing target
if [[ -e "$TARGET_NVIM_LITE" || -L "$TARGET_NVIM_LITE" ]]; then
    warn "~/.config/nvim already exists"

    if [[ -L "$TARGET_NVIM_LITE" ]]; then
        info "Current symlink target: $(readlink "$TARGET_NVIM_LITE")"
    else
        info "Current target is a regular directory"
    fi

    # Create backup before replacing
    backup_dir="${TARGET_NVIM_LITE}.backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup: $backup_dir"
    mv "$TARGET_NVIM_LITE" "$backup_dir"
    success "Backup created: $backup_dir"
fi

if [[ "$use_copy" == true ]]; then
    cp -r "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
    success "Directory copied: $SOURCE_NVIM_LITE → $TARGET_NVIM_LITE"
else
    ln -s "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
    success "Symlink created: $TARGET_NVIM_LITE -> $SOURCE_NVIM_LITE"
fi

echo ""
bold "To use nvim-lite:"
echo -e "  ${YELLOW}nvim${NC}"
echo ""
info "First launch will install plugins automatically via lazy.nvim."
if [[ "$use_copy" == true ]]; then
    info "Note: to sync future repo changes, run: ${BOLD}$0 --copy${NC}"
fi
