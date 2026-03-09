#!/bin/bash

# Script to install Node.js LTS system-wide
# Detects the latest LTS version automatically

set -e

# === CONFIGURABLE VARIABLES ===
NODE_DISTRO="linux-x64"
NODE_DIR="/opt/nodejs"
NODE_PROFILE="/etc/profile.d/node.sh"

# Colors using tput (256 colors)
GREEN=$(tput setaf 114)
ORANGE=$(tput setaf 208)
BLUE=$(tput setaf 75)
YELLOW=$(tput setaf 221)
RED=$(tput setaf 196)
BOLD=$(tput bold)
NC=$(tput sgr0)

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
            bold "marckv.dots Node.js installer"
            echo ""
            echo -e "Installs the latest Node.js LTS to ${ORANGE}$NODE_DIR${NC}."
            echo -e "Detects the latest version automatically."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0"
            echo ""
            exit 0
            ;;
    esac
done

bold "=== Node.js installer ==="

# Get the latest Node.js LTS version
get_latest_node_version() {
    local v
    if command -v python3 >/dev/null 2>&1; then
        v=$(curl -s https://nodejs.org/dist/index.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
lts = [d for d in data if d.get('lts')]
print(lts[0]['version'].lstrip('v')) if lts else sys.exit(1)
" 2>/dev/null)
    else
        v=$(curl -s https://nodejs.org/dist/index.json | \
            grep -v '"lts":false' | grep -o '"version":"v[^"]*"' | head -1 | \
            cut -d'"' -f4 | sed 's/v//')
    fi
    [ -n "$v" ] && echo "$v" || return 1
}

# Compare version strings
compare_versions() {
    local installed="$1" latest="$2"
    local higher
    higher=$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n1)
    [ "$higher" = "$latest" ] && [ "$installed" != "$latest" ]
}

# Check for existing installation
if command -v node >/dev/null 2>&1 && [ -f "$NODE_PROFILE" ]; then
    installed_version=$(node --version 2>/dev/null | sed 's/v//')
    warn "Node.js is already installed: v$installed_version"

    info "Checking for available updates..."
    if latest_version=$(get_latest_node_version); then
        info "Latest LTS available: v$latest_version"

        if compare_versions "$installed_version" "$latest_version"; then
            bold "\n🚀 NEW VERSION AVAILABLE!"
            info "Installed: v$installed_version  →  Available: v$latest_version"
            read -p "Update to v$latest_version? (Y/n): " -n 1 -r; echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                info "Update cancelled."
                exit 0
            fi
            NODE_VERSION="$latest_version"
        else
            success "✅ Already on the latest LTS (v$installed_version)"
            exit 0
        fi
    else
        warn "Could not verify latest version"
        read -p "Reinstall Node.js anyway? (y/N): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Cancelled."
            exit 0
        fi
        NODE_VERSION="$installed_version"
    fi
else
    info "Node.js is not installed — fetching latest LTS version..."
    if NODE_VERSION=$(get_latest_node_version); then
        info "Will install: v$NODE_VERSION"
    else
        warn "Could not fetch latest version, using fallback 22.0.0"
        NODE_VERSION="22.0.0"
    fi
fi

NODE_TAR="/tmp/node-v${NODE_VERSION}-${NODE_DISTRO}.tar.xz"
NODE_BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_DISTRO}.tar.xz"

echo ""

# Download
if [ -f "$NODE_TAR" ] && [ -s "$NODE_TAR" ]; then
    info "Using cached archive: $NODE_TAR"
else
    info "Downloading Node.js v$NODE_VERSION..."
    curl -L -o "$NODE_TAR" "$NODE_BASE_URL" || die "Failed to download Node.js"
fi

# Install xz-utils if needed
if ! command -v xz >/dev/null 2>&1; then
    info "Installing xz-utils..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq xz-utils || die "Failed to install xz-utils"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y xz || die "Failed to install xz"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y xz || die "Failed to install xz"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm xz || die "Failed to install xz"
    else
        die "No compatible package manager found to install xz-utils"
    fi
fi

# Extract and install
info "Extracting to $NODE_DIR..."
rm -rf "$NODE_DIR"
mkdir -p "$NODE_DIR"
tar -xf "$NODE_TAR" -C "$NODE_DIR" --strip-components=1 || die "Failed to extract Node.js"

# Configure PATH
echo "export PATH=\"\$PATH:$NODE_DIR/bin\"" > "$NODE_PROFILE"
chmod 644 "$NODE_PROFILE"
source "$NODE_PROFILE"

success "Node.js v$NODE_VERSION installed to $NODE_DIR"

echo ""
info "To use Node.js in new terminal sessions:"
echo -e "  ${YELLOW}${BOLD}1.${NC} Environment variables are already configured globally"
echo -e "  ${YELLOW}${BOLD}2.${NC} Restart your terminal, or run: ${YELLOW}${BOLD}source $NODE_PROFILE${NC}"
echo -e "  ${YELLOW}${BOLD}3.${NC} Verify with: ${YELLOW}${BOLD}node --version${NC}"
echo ""
