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

# Detect privilege level once: root / sudo / user
# Sets PRIV_MODE to: "root", "sudo", or "user"
if [[ $EUID -eq 0 ]]; then
    PRIV_MODE="root"
elif command -v sudo &>/dev/null; then
    PRIV_MODE="sudo"
else
    PRIV_MODE="user"
fi

# Run a command with appropriate privileges
_run() {
    case "$PRIV_MODE" in
        root) "$@" ;;
        sudo) sudo "$@" ;;
        user)
            error "Cannot run: $*"
            info "No root or sudo access. Run manually with: ${BOLD}sudo $*${NC}"
            return 1
            ;;
    esac
}

# Helper: install packages via apt
_apt_install() {
    local apt_cmd="apt-get install -y $*"
    info "Running: ${BOLD}${apt_cmd}${NC}"
    _run apt-get update -qq || return 1
    _run apt-get install -y "$@"
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
    local fzf_bin="$HOME/.local/bin"
    if [[ "$PRIV_MODE" == "root" ]]; then
        fzf_bin="/usr/local/bin"
    else
        mkdir -p "$fzf_bin"
    fi
    local tmp_file
    tmp_file=$(mktemp /tmp/fzf-XXXXXX.tar.gz)
    info "Downloading: ${BOLD}fzf v${fzf_version} (${arch})${NC}"
    info "URL: ${fzf_url}"
    info "Install to: ${BOLD}${fzf_bin}/fzf${NC}"
    curl -fSL "$fzf_url" -o "$tmp_file" || { error "Failed to download fzf"; rm -f "$tmp_file"; return 1; }
    tar -C "$fzf_bin" -xzf "$tmp_file" fzf || { error "Failed to extract fzf to ${fzf_bin}"; rm -f "$tmp_file"; return 1; }
    rm -f "$tmp_file"
}

# Install the tree-sitter CLI, pinned to a build this machine's GLIBC can run
#
# Only nvim-treesitter's `main` branch needs this — the `master` branch used on
# Neovim 0.10 downloads pre-generated C sources and builds them with cc alone.
# But `main` is what Neovim 0.11+ gets, and without a WORKING CLI it installs
# exactly nothing: measured on Debian 12, `Installed 0/16 languages`, while the
# file still looked coloured because Vim's legacy regex syntax takes over.
#
# LazyVim asks mason for the CLI and mason fetches the latest, which is built
# against GLIBC 2.39 — newer than Debian 12 (2.36) or Ubuntu 22.04 (2.35), so
# it cannot start. Those two sit in a gap: too new for the old branch, too old
# for the current CLI.
#
# The floors below were read off the binaries with objdump, not guessed:
#   v0.26.13 → GLIBC 2.39   (Debian 13, Ubuntu 24.04+)
#   v0.25.10 → GLIBC 2.34   (Debian 12, Ubuntu 22.04)
#   v0.24.7  → GLIBC 2.29   (Debian 11, Ubuntu 20.04)
#
# Installing it on PATH is enough: LazyVim checks `executable("tree-sitter")`
# first and returns before it ever reaches mason.
_install_tree_sitter_cli() {
    local glibc major minor version arch url dest tmp
    glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    major="${glibc%%.*}"
    minor="${glibc##*.}"
    [[ -z "$major" || -z "$minor" ]] && { error "Could not read the system GLIBC"; return 1; }

    if [[ "$major" -gt 2 ]] || [[ "$major" -eq 2 && "$minor" -ge 39 ]]; then
        version="0.26.13"
    elif [[ "$major" -eq 2 && "$minor" -ge 34 ]]; then
        version="0.25.10"
    elif [[ "$major" -eq 2 && "$minor" -ge 29 ]]; then
        version="0.24.7"
    else
        # Debian 10 and older. Every tree-sitter CLI release ever published,
        # back to v0.20.9, needs GLIBC 2.29 — there is no build to fall back
        # to. It does not matter: a GLIBC that old only runs Neovim 0.9/0.10,
        # which uses nvim-treesitter's `master` branch, and that one builds
        # pre-generated C sources with cc and never asks for a CLI.
        info "GLIBC ${BOLD}${glibc}${NC} — no tree-sitter CLI build runs here, and none is needed"
        info "Neovim 0.9/0.10 uses nvim-treesitter's ${BOLD}master${NC} branch, which only needs a C compiler"
        return 2
    fi

    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64) arch="arm64" ;;
        *) error "Unsupported architecture for tree-sitter CLI: $arch"; return 1 ;;
    esac
    url="https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter-linux-${arch}.gz"

    dest="$HOME/.local/bin"
    if [[ "$PRIV_MODE" == "root" ]]; then
        dest="/usr/local/bin"
    else
        mkdir -p "$dest"
    fi

    info "GLIBC ${BOLD}${glibc}${NC} — installing tree-sitter CLI ${BOLD}v${version}${NC} (${arch})"
    info "URL: ${url}"
    tmp=$(mktemp /tmp/tree-sitter-XXXXXX.gz)
    curl -fSL "$url" -o "$tmp" || { error "Failed to download the tree-sitter CLI"; rm -f "$tmp"; return 1; }
    gunzip -c "$tmp" > "${tmp}.bin" || { error "Failed to unpack the tree-sitter CLI"; rm -f "$tmp" "${tmp}.bin"; return 1; }
    rm -f "$tmp"
    chmod 755 "${tmp}.bin"

    # Run it before installing it. The whole reason this function exists is a
    # binary that downloads and unpacks perfectly and then cannot start, and an
    # executable bit says nothing about that.
    if ! "${tmp}.bin" --version >/dev/null 2>&1; then
        error "The tree-sitter CLI v${version} cannot run on this system:"
        "${tmp}.bin" --version 2>&1 | head -n2 | sed 's/^/  /'
        rm -f "${tmp}.bin"
        return 1
    fi

    _run mv "${tmp}.bin" "${dest}/tree-sitter" || { rm -f "${tmp}.bin"; return 1; }
    _run chmod 755 "${dest}/tree-sitter"
    return 0
}

# Deps mode: check and install system dependencies
if [[ "$use_deps" == true ]]; then
    bold "=== nvim-lite dependencies ==="
    echo ""

    # apt packages: command_name -> package_name (use | for alternative command names)
    APT_DEPS="gcc:gcc make:make cc-headers:libc6-dev rg:ripgrep fd|fdfind:fd-find git:git curl:curl"
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
        elif [[ "$cmd" == *"|"* ]]; then
            # Multiple possible command names (e.g. fd|fdfind)
            found_alt=false
            for alt in ${cmd//|/ }; do
                if command -v "$alt" &>/dev/null; then
                    success "$pkg found: $($alt --version 2>&1 | head -n1)"
                    found_alt=true
                    break
                fi
            done
            if [[ "$found_alt" == false ]]; then
                warn "$pkg not found (checked: ${cmd//|/, })"
                missing_apt+=("$pkg")
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

    # tree-sitter CLI: only nvim-treesitter's `main` branch needs it, but that
    # is what Neovim 0.11+ gets, and without it no parser is ever built.
    echo ""
    if command -v tree-sitter &>/dev/null && tree-sitter --version &>/dev/null; then
        success "tree-sitter CLI found: $(tree-sitter --version 2>&1 | head -1)"
    else
        if command -v tree-sitter &>/dev/null; then
            warn "tree-sitter CLI found but it cannot run here:"
            tree-sitter --version 2>&1 | head -n2 | sed 's/^/  /'
        else
            warn "tree-sitter CLI not found"
        fi
        _install_tree_sitter_cli
        case $? in
            0) success "tree-sitter CLI installed: $(tree-sitter --version 2>&1 | head -1)" ;;
            2) success "tree-sitter CLI not required on this system" ;;
            *) error "Failed to install the tree-sitter CLI" ;;
        esac
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
    nvim --headless "+Lazy! sync" +qa 2>&1 || warn "Lazy sync reported errors (may be non-fatal)"
    success "Plugins installed"

    info "Compiling treesitter parsers (if supported)..."
    # TSUpdateSync was removed in newer nvim-treesitter — ignore errors gracefully.
    # Lazy sync above already installs parsers declared in ensure_installed.
    nvim --headless "+lua pcall(function() vim.cmd('TSUpdateSync') end)" +qa 2>&1 || true
    success "Treesitter parsers step complete"

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
    # Remove lazy-lock.json so each host resolves plugins for its Neovim version.
    # On older Neovim (e.g. Debian 11 / Ubuntu 20), this is critical so the
    # LazyVim tag pin in lazy.lua actually gets applied instead of being
    # overridden by a lockfile generated on a newer system.
    if [[ -f "$TARGET_NVIM_LITE/lazy-lock.json" ]]; then
        rm -f "$TARGET_NVIM_LITE/lazy-lock.json"
        info "Removed copied lazy-lock.json so plugins resolve to this host's Neovim version"
    fi
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
