#!/bin/bash

# Script to install marckv.dots nvim-lite configuration
# Default: creates a symlink from ~/.config/nvim to repo nvim-lite/
# With --copy: copies the directory instead (useful for remote servers without repo access)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
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

install_nvim_lite() {
    local use_copy=false

    # Parse flags
    for arg in "$@"; do
        case "$arg" in
            -c|--copy) use_copy=true ;;
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

    local nvim_version
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
        return 0
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
        local backup_dir="${TARGET_NVIM_LITE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup: $backup_dir"
        mv "$TARGET_NVIM_LITE" "$backup_dir"
        success "Backup created: $backup_dir"
    fi

    if [[ "$use_copy" == true ]]; then
        # Copy directory
        cp -r "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
        success "Directory copied: $SOURCE_NVIM_LITE → $TARGET_NVIM_LITE"
    else
        # Create symlink
        ln -s "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
        success "Symlink created: $TARGET_NVIM_LITE -> $SOURCE_NVIM_LITE"
    fi

    echo ""
    bold "To use nvim-lite:"
    echo -e "  ${YELLOW}nvim${NC}"
    echo ""
    info "First launch will install plugins automatically via lazy.nvim."
    if [[ "$use_copy" == true ]]; then
        info "Note: to sync future repo changes, run: ${BOLD}$0 install --copy${NC}"
    fi
}

status_nvim_lite() {
    bold "=== nvim-lite config status ==="

    # Check source directory
    if [[ ! -d "$SOURCE_NVIM_LITE" ]]; then
        error "Repository nvim-lite config not found: $SOURCE_NVIM_LITE"
        return 1
    fi
    success "Repository nvim-lite config found: $SOURCE_NVIM_LITE"

    # Check Neovim
    if command -v nvim >/dev/null 2>&1; then
        success "Neovim installed: $(nvim --version | head -n1)"
    else
        warn "Neovim is not installed"
    fi

    # Check target
    if [[ ! -e "$TARGET_NVIM_LITE" && ! -L "$TARGET_NVIM_LITE" ]]; then
        warn "~/.config/nvim does not exist (not installed)"
        return 0
    fi

    if [[ -L "$TARGET_NVIM_LITE" && "$TARGET_NVIM_LITE" -ef "$SOURCE_NVIM_LITE" ]]; then
        success "~/.config/nvim → symlink to repository config"
        info "Mode: symlink (live sync with repo)"
    elif [[ -L "$TARGET_NVIM_LITE" ]]; then
        warn "~/.config/nvim is a symlink to a different target"
        info "Current symlink target: $(readlink "$TARGET_NVIM_LITE")"
    else
        success "~/.config/nvim exists as a regular directory"
        info "Mode: copy (independent from repo)"
    fi

    # Check lazy.nvim data directory
    local data_dir="$HOME/.local/share/nvim"
    if [[ -d "$data_dir" ]]; then
        info "Plugin data directory exists: $data_dir"
        if [[ -d "$data_dir/lazy/lazy.nvim" ]]; then
            success "lazy.nvim is installed"
        else
            warn "lazy.nvim not yet bootstrapped (run nvim once)"
        fi
    else
        info "Plugin data directory not yet created (run nvim once)"
    fi
}

uninstall_nvim_lite() {
    bold "=== nvim-lite config uninstaller ==="

    if [[ ! -e "$TARGET_NVIM_LITE" && ! -L "$TARGET_NVIM_LITE" ]]; then
        warn "~/.config/nvim does not exist, nothing to uninstall"
    elif [[ -L "$TARGET_NVIM_LITE" && "$TARGET_NVIM_LITE" -ef "$SOURCE_NVIM_LITE" ]]; then
        rm "$TARGET_NVIM_LITE"
        success "Removed symlink: $TARGET_NVIM_LITE"
    elif [[ -L "$TARGET_NVIM_LITE" ]]; then
        warn "~/.config/nvim is a symlink to a different target — not removed"
        info "Current symlink target: $(readlink "$TARGET_NVIM_LITE")"
    else
        warn "~/.config/nvim is a regular directory (copy mode)"
        read -p "Remove ~/.config/nvim directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local backup_dir="${TARGET_NVIM_LITE}.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$TARGET_NVIM_LITE" "$backup_dir"
            success "Moved to backup: $backup_dir"
        else
            info "Directory kept."
            return 0
        fi
    fi

    # Ask about plugin data
    local data_dir="$HOME/.local/share/nvim"
    local state_dir="$HOME/.local/state/nvim"
    local cache_dir="$HOME/.cache/nvim"

    local has_data=false
    for dir in "$data_dir" "$state_dir" "$cache_dir"; do
        [[ -d "$dir" ]] && has_data=true && break
    done

    if [[ "$has_data" == true ]]; then
        echo ""
        warn "Plugin data directories found:"
        [[ -d "$data_dir"  ]] && info "  $data_dir"
        [[ -d "$state_dir" ]] && info "  $state_dir"
        [[ -d "$cache_dir" ]] && info "  $cache_dir"

        echo ""
        read -p "Remove plugin data directories? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            [[ -d "$data_dir"  ]] && rm -rf "$data_dir"  && success "Removed: $data_dir"
            [[ -d "$state_dir" ]] && rm -rf "$state_dir" && success "Removed: $state_dir"
            [[ -d "$cache_dir" ]] && rm -rf "$cache_dir" && success "Removed: $cache_dir"
        else
            info "Plugin data directories kept."
        fi
    fi

    success "nvim-lite config uninstalled."
}

case "${1:-install}" in
    install|i)
        shift
        install_nvim_lite "$@"
        ;;
    status|s)
        status_nvim_lite
        ;;
    uninstall|u)
        uninstall_nvim_lite
        ;;
    *)
        bold "marckv.dots nvim-lite installer"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo -e "  ${GREEN}$0 [install|i]${NC}           - Install via symlink (default, live sync)"
        echo -e "  ${GREEN}$0 [install|i] --copy${NC}    - Install via directory copy (standalone)"
        echo -e "  ${GREEN}$0 [install|i] -c${NC}        - Same as --copy"
        echo -e "  ${GREEN}$0 status|s${NC}              - Show installation status"
        echo -e "  ${GREEN}$0 uninstall|u${NC}           - Remove config and optionally plugin data"
        echo ""
        echo -e "${YELLOW}Modes:${NC}"
        echo -e "  ${CYAN}symlink${NC}  Changes in repo reflect immediately. Requires repo to stay mounted."
        echo -e "  ${CYAN}copy${NC}     Independent copy. Useful for remote servers without repo access."
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  ${GREEN}$0${NC}                 # Symlink (default)"
        echo -e "  ${GREEN}$0 install --copy${NC}  # Copy for a remote server"
        echo -e "  ${GREEN}$0 status${NC}          # Check current installation"
        echo ""
        ;;
esac
