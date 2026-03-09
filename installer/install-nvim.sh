#!/bin/bash

# Script to install Neovim system-wide
# Requires root/sudo

set -e

# Colors using tput (256 colors)
GREEN=$(tput setaf 114)
ORANGE=$(tput setaf 208)
BLUE=$(tput setaf 75)
YELLOW=$(tput setaf 221)
RED=$(tput setaf 196)
BOLD=$(tput bold)
NC=$(tput sgr0)

# URLs and paths
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
NVIM_TAR="/tmp/nvim-linux-x86_64.tar.gz"
NVIM_PATH="/opt/nvim"
PROFILE_PATH="/etc/profile.d/nvim.sh"

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

die() { error "$1"; exit 1; }

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots Neovim installer"
            echo ""
            echo -e "Installs Neovim system-wide to ${ORANGE}$NVIM_PATH${NC}."
            echo -e "Always installs the latest stable release. Requires ${ORANGE}root/sudo${NC}."
            echo ""
            echo -e "${BLUE}Usage:${NC} sudo $0"
            echo ""
            exit 0
            ;;
    esac
done

# Verify root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    info "Usage: ${BOLD}sudo $0${NC}"
    exit 1
fi

bold "=== Neovim installer ==="

# Get the latest Neovim release tag
get_latest_version() {
    curl -s https://api.github.com/repos/neovim/neovim/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Get currently installed version
get_installed_version() {
    [ -x "$NVIM_PATH/bin/nvim" ] && \
        $NVIM_PATH/bin/nvim --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+'
}

# Compare version strings
compare_versions() {
    local installed="$1" latest="$2"
    local ic lc higher
    ic=$(echo "$installed" | sed 's/^v//')
    lc=$(echo "$latest" | sed 's/^v//')
    higher=$(printf '%s\n%s\n' "$ic" "$lc" | sort -V | tail -n1)
    [ "$higher" = "$lc" ] && [ "$ic" != "$lc" ]
}

# Check for existing installation
if [ -d "$NVIM_PATH" ] && [ -f "$PROFILE_PATH" ]; then
    installed_version=$(get_installed_version)
    warn "Neovim is already installed: $installed_version ($NVIM_PATH)"

    info "Checking for available updates..."
    latest_version=$(get_latest_version)

    if [ -n "$latest_version" ]; then
        info "Latest available: $latest_version"

        if [ -n "$installed_version" ] && compare_versions "$installed_version" "$latest_version"; then
            bold "\n🚀 NEW VERSION AVAILABLE!"
            info "Installed: $installed_version  →  Available: $latest_version"
            read -p "Update to $latest_version? (Y/n): " -n 1 -r; echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                info "Update cancelled."
                exit 0
            fi
        else
            success "✅ Already on the latest version ($installed_version)"
            exit 0
        fi
    else
        warn "Could not verify latest version"
        read -p "Reinstall Neovim anyway? (y/N): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Cancelled."
            exit 0
        fi
    fi
else
    info "Neovim is not installed — fetching latest release..."
    latest_version=$(get_latest_version)
    [ -n "$latest_version" ] && info "Will install: $latest_version" \
        || info "Could not verify version — installing latest available"
fi

echo ""

# Download
if [ -f "$NVIM_TAR" ] && [ -s "$NVIM_TAR" ]; then
    info "Using cached archive: $NVIM_TAR"
else
    info "Downloading Neovim from GitHub..."
    curl -L -o "$NVIM_TAR" "$NVIM_URL" || die "Failed to download Neovim"
fi

# Remove previous installation
[ -d "$NVIM_PATH" ] && { info "Removing previous installation..."; rm -rf "$NVIM_PATH"; }
[ -d "/opt/nvim-linux-x86_64" ] && rm -rf "/opt/nvim-linux-x86_64"

# Extract
info "Extracting to /opt..."
temp_dir="/tmp/nvim-extract"
mkdir -p "$temp_dir"
tar -C "$temp_dir" -xzf "$NVIM_TAR" || die "Failed to extract Neovim"

if [ -d "$temp_dir/nvim-linux-x86_64" ]; then
    mv "$temp_dir/nvim-linux-x86_64" "$NVIM_PATH"
else
    rm -rf "$temp_dir"
    die "Unexpected archive structure"
fi
rm -rf "$temp_dir"

[ -x "$NVIM_PATH/bin/nvim" ] || die "Neovim executable not found after extraction"

# Configure PATH
echo "export PATH=\"\$PATH:$NVIM_PATH/bin\"" > "$PROFILE_PATH"
chmod 644 "$PROFILE_PATH"
source "$PROFILE_PATH"

# Verify
version=$($NVIM_PATH/bin/nvim --version | head -n1)
success "Neovim installed: $version"
info "Location: $NVIM_PATH/bin/nvim"

echo ""
info "To use Neovim in new terminal sessions:"
echo -e "  ${YELLOW}${BOLD}1.${NC} Environment variables are already configured globally"
echo -e "  ${YELLOW}${BOLD}2.${NC} Restart your terminal, or run: ${YELLOW}${BOLD}source $PROFILE_PATH${NC}"
echo -e "  ${YELLOW}${BOLD}3.${NC} Verify with: ${YELLOW}${BOLD}nvim --version${NC}"
echo ""
success "Installation complete!"
