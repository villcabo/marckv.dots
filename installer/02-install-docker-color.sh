#!/bin/bash

# Script to install marckv.dots docker aliases + docker-color-output binary
# Appends a source line to ~/.bash_aliases and installs the binary

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
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
BASH_ALIASES_FILE="$HOME/.bash_aliases"
DOCKER_COLOR_ALIASES="$MARCKV_DOTS_DIR/docker-aliases/docker-color_aliases.sh"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/docker-aliases/docker-color_aliases.sh" ]] && source "$HOME/.marckv.dots/docker-aliases/docker-color_aliases.sh"'

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots docker aliases installer"
            echo ""
            echo -e "Installs ${YELLOW}docker-color-output${NC} binary and appends a source line to ${YELLOW}~/.bash_aliases${NC}."
            echo -e "Provides ${CYAN}d${NC} and ${CYAN}dc${NC} shortcuts with colored output and tab completion."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0"
            echo ""
            exit 0
            ;;
    esac
done

bold "=== marckv.dots docker aliases installer ==="

# Verify marckv.dots directory and aliases loader exist
if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
    error "Directory $MARCKV_DOTS_DIR does not exist."
    exit 1
fi

if [[ ! -f "$DOCKER_COLOR_ALIASES" ]]; then
    error "File $DOCKER_COLOR_ALIASES not found"
    exit 1
fi

info "marckv.dots directory: $MARCKV_DOTS_DIR"

# --- Step 1: docker-color-output binary ---
info "Checking docker-color-output binary..."

if command -v docker-color-output >/dev/null 2>&1; then
    current_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "unknown version")
    success "docker-color-output already available: $current_version"
else
    warn "docker-color-output not found — installing..."

    # Determine install directory based on privileges
    if [[ $EUID -eq 0 ]]; then
        install_dir="/usr/local/bin"
        use_sudo=false
        info "Running as root — installing to $install_dir"
    elif sudo -n true 2>/dev/null; then
        install_dir="/usr/local/bin"
        use_sudo=true
        info "Sudo available — installing to $install_dir"
    else
        install_dir="$HOME/.local/bin"
        use_sudo=false
        info "No sudo — installing to $install_dir"
        mkdir -p "$install_dir"
    fi

    # Detect architecture
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  download_arch="amd64" ;;
        aarch64|arm64) download_arch="arm64" ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    download_url="https://github.com/devemio/docker-color-output/releases/latest/download/docker-color-output-linux-$download_arch"
    temp_file="/tmp/docker-color-output"

    info "Downloading docker-color-output ($download_arch)..."
    if wget -q "$download_url" -O "$temp_file"; then
        chmod +x "$temp_file"
        if [[ "$use_sudo" == true ]]; then
            sudo mv "$temp_file" "$install_dir/docker-color-output"
        else
            mv "$temp_file" "$install_dir/docker-color-output"
        fi

        if command -v docker-color-output >/dev/null 2>&1; then
            installed_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "unknown version")
            success "docker-color-output installed: $installed_version"
        else
            warn "Binary installed to $install_dir but not yet in PATH"
            info "It will be available after sourcing ~/.bash_aliases or restarting terminal"
        fi
    else
        error "Failed to download docker-color-output"
        info "Install manually: https://github.com/devemio/docker-color-output/releases"
        exit 1
    fi
fi

echo ""

# --- Step 2: docker aliases ---
info "Installing Docker aliases..."

# Create ~/.bash_aliases if it does not exist
if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
    info "Creating ~/.bash_aliases..."
    touch "$BASH_ALIASES_FILE"
fi

# Check if already installed
if grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
    warn "Docker aliases already installed in $BASH_ALIASES_FILE"
    info "No changes needed."
else
    # Back up if not empty
    if [[ -s "$BASH_ALIASES_FILE" ]]; then
        backup_file="${BASH_ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup: $backup_file"
        cp "$BASH_ALIASES_FILE" "$backup_file"
    fi

    info "Adding source line to ~/.bash_aliases..."
    echo "" >> "$BASH_ALIASES_FILE"
    echo "# marckv.dots Docker Color Aliases" >> "$BASH_ALIASES_FILE"
    echo "$LOAD_LINE" >> "$BASH_ALIASES_FILE"

    success "Docker aliases installed!"
fi

echo ""
bold "To apply changes:"
echo -e "  ${YELLOW}source ~/.bash_aliases${NC}  ${BLUE}# or restart terminal${NC}"
echo ""
info "Shortcuts available: ${CYAN}d${NC} (docker), ${CYAN}dc${NC} (compose), ${CYAN}dcup${NC}, ${CYAN}dcps${NC}, ${CYAN}dcl${NC}, ..."
