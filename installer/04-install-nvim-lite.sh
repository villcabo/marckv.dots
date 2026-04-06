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
use_sync=false
use_deps=false
for arg in "$@"; do
    case "$arg" in
        -c|--copy) use_copy=true ;;
        -s|--sync) use_sync=true ;;
        -d|--deps) use_deps=true ;;
        -h|--help)
            bold "marckv.dots nvim-lite installer"
            echo ""
            echo -e "${BLUE}Usage:${NC} $0 [-c|--copy] [-s|--sync] [-d|--deps]"
            echo ""
            echo -e "  ${YELLOW}-c, --copy${NC}   Copy the config directory instead of creating a symlink."
            echo -e "               Useful for remote servers where the repo won't be available."
            echo ""
            echo -e "  ${YELLOW}-s, --sync${NC}   Install plugins and treesitter parsers headlessly."
            echo -e "               Run this after install to avoid waiting on first launch."
            echo ""
            echo -e "  ${YELLOW}-d, --deps${NC}   Check and install system dependencies (gcc, make, ripgrep, fzf, fd)."
            echo -e "               Requires root or sudo. Installs fzf from GitHub (apt version is too old)."
            echo ""
            echo -e "  By default, a symlink is created so changes in the repo reflect immediately."
            echo ""
            exit 0
            ;;
    esac
done

# Helper: install packages via apt respecting root/sudo/no-access
_apt_install() {
    local apt_cmd="apt-get install -y $*"
    if [[ $EUID -eq 0 ]]; then
        info "Running: ${BOLD}apt-get update${NC}"
        apt-get update -qq
        info "Running: ${BOLD}${apt_cmd}${NC}"
        apt-get install -y "$@"
    elif sudo -n true 2>/dev/null; then
        info "Running: ${BOLD}sudo apt-get update${NC}"
        sudo apt-get update -qq
        info "Running: ${BOLD}sudo ${apt_cmd}${NC}"
        sudo apt-get install -y "$@"
    else
        error "Cannot install $*: no root or sudo access."
        info "Run manually: ${BOLD}sudo ${apt_cmd}${NC}"
        return 1
    fi
}

# Install fzf from GitHub (apt version is too old for fzf-lua)
_install_fzf() {
    local fzf_version arch fzf_url
    info "Fetching latest fzf version from GitHub API..."
    fzf_version=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [[ -z "$fzf_version" ]]; then
        error "Failed to fetch fzf version from GitHub API"
        info "Run manually: ${BOLD}curl -s https://api.github.com/repos/junegunn/fzf/releases/latest${NC}"
        return 1
    fi
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac
    fzf_url="https://github.com/junegunn/fzf/releases/download/v${fzf_version}/fzf-${fzf_version}-linux_${arch}.tar.gz"
    info "Downloading: ${BOLD}fzf v${fzf_version} (${arch})${NC}"
    info "URL: ${fzf_url}"
    curl -fsSL "$fzf_url" -o /tmp/fzf.tar.gz \
        && tar -C /usr/local/bin -xzf /tmp/fzf.tar.gz fzf \
        && rm /tmp/fzf.tar.gz
}

# Deps mode: check and install system dependencies
if [[ "$use_deps" == true ]]; then
    bold "=== nvim-lite dependencies ==="
    echo ""

    # apt packages: command_name -> package_name
    APT_DEPS="gcc:gcc make:make cc-headers:libc6-dev rg:ripgrep fd:fd-find git:git curl:curl"
    missing_apt=()

    for entry in $APT_DEPS; do
        cmd="${entry%%:*}"
        pkg="${entry##*:}"
        # Special case: libc6-dev has no command, check header file
        if [[ "$cmd" == "cc-headers" ]]; then
            if ! echo '#include <stdint.h>' | gcc -E -x c - &>/dev/null 2>&1; then
                warn "libc6-dev not found (C headers missing)"
                missing_apt+=("$pkg")
            else
                success "libc6-dev found"
            fi
        elif command -v "$cmd" &>/dev/null; then
            success "$pkg found: $($cmd --version 2>&1 | head -n1)"
        else
            warn "$pkg not found"
            missing_apt+=("$pkg")
        fi
    done

    # Install missing apt packages
    if [[ ${#missing_apt[@]} -gt 0 ]]; then
        echo ""
        info "Missing packages: ${BOLD}${missing_apt[*]}${NC}"
        _apt_install "${missing_apt[@]}" && success "apt packages installed" || error "Failed to install: ${missing_apt[*]}"
    else
        echo ""
        success "All apt dependencies are installed"
    fi

    # fzf: must be v0.40+ (apt version is too old)
    echo ""
    if command -v fzf &>/dev/null; then
        fzf_ver=$(fzf --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        fzf_major=$(echo "$fzf_ver" | cut -d. -f1)
        fzf_minor=$(echo "$fzf_ver" | cut -d. -f2)
        if [[ "$fzf_major" -eq 0 && "$fzf_minor" -lt 40 ]]; then
            warn "fzf found but too old (v$fzf_ver, need v0.40+)"
            info "Installing latest fzf from GitHub..."
            _install_fzf && success "fzf installed: $(fzf --version 2>&1 | head -1)" || error "Failed to install fzf"
        else
            success "fzf found: v$fzf_ver"
        fi
    else
        warn "fzf not found"
        info "Installing latest fzf from GitHub..."
        _install_fzf && success "fzf installed: $(fzf --version 2>&1 | head -1)" || error "Failed to install fzf"
    fi

    echo ""
    success "Dependencies check complete."
    exit 0
fi

# Sync mode: install plugins + parsers headlessly and exit
if [[ "$use_sync" == true ]]; then
    bold "=== nvim-lite sync (headless) ==="

    if ! command -v nvim >/dev/null 2>&1; then
        error "Neovim is not installed."
        exit 1
    fi

    if [[ ! -d "$TARGET_NVIM_LITE" ]]; then
        error "nvim-lite is not installed. Run ${BOLD}$0${NC} first."
        exit 1
    fi

    info "Installing plugins..."
    nvim --headless "+Lazy! sync" +qa 2>&1
    success "Plugins installed"

    info "Compiling treesitter parsers..."
    nvim --headless "+TSUpdateSync" +qa 2>&1
    success "Treesitter parsers compiled"

    echo ""
    success "nvim-lite is ready to use."
    exit 0
fi

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
