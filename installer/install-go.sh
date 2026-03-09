#!/bin/bash

# Script to install Go following the official instructions from go.dev
# Based on: https://go.dev/doc/install
# Requires root/sudo

set -e

# === CONFIGURABLE VARIABLES ===
GO_VERSION=""   # Auto-detected
GO_ARCH=""      # Auto-detected
GO_INSTALL_DIR="/usr/local"
GO_TAR=""
GO_DOWNLOAD_URL=""

# Colors using tput
GREEN=$(tput setaf 114)
ORANGE=$(tput setaf 208)
BLUE=$(tput setaf 75)
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
            bold "marckv.dots Go installer"
            echo ""
            echo -e "Installs Go system-wide to ${ORANGE}/usr/local/go${NC}."
            echo -e "Detects the latest version automatically. Requires ${ORANGE}root/sudo${NC}."
            echo ""
            echo -e "${BLUE}Usage:${NC} sudo $0"
            echo ""
            exit 0
            ;;
    esac
done

# Validate environment
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    error "This script is designed for Linux/WSL, not Git Bash on Windows"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    info "Usage: sudo $0"
    exit 1
fi

bold "=== Go installer ==="

# Detect system architecture
detect_architecture() {
    local arch_type
    arch_type=$(uname -m)
    case $arch_type in
        x86_64|amd64)  echo "linux-amd64" ;;
        aarch64|arm64) echo "linux-arm64" ;;
        armv6l)        echo "linux-armv6l" ;;
        i386|i686)     echo "linux-386" ;;
        *)             echo "linux-amd64" ;;  # Fallback
    esac
}

# Get the latest Go version
get_latest_go_version() {
    local v
    v=$(curl -s https://go.dev/dl/ | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [ -z "$v" ] || [[ "$v" =~ [^0-9.] ]]; then
        echo "1.23.3"  # Known stable fallback
    else
        echo "$v"
    fi
}

# Compare version strings semantically
compare_versions() {
    local installed="$1" available="$2"
    [ -z "$installed" ] || [ -z "$available" ] && return 1
    local higher
    higher=$(printf '%s\n%s\n' "$installed" "$available" | sort -V | tail -n1)
    [ "$higher" = "$available" ] && [ "$installed" != "$available" ]
}

GO_ARCH=$(detect_architecture)
info "Detected architecture: $GO_ARCH"

# Check for existing installation
go_binary=""
installed_version=""

if command -v go >/dev/null 2>&1; then
    go_binary=$(command -v go)
    installed_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
elif [ -x "/usr/local/go/bin/go" ]; then
    go_binary="/usr/local/go/bin/go"
    installed_version=$(/usr/local/go/bin/go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
elif [ -x "/usr/bin/go" ]; then
    go_binary="/usr/bin/go"
    installed_version=$(/usr/bin/go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
fi

if [ -n "$go_binary" ] && [ -n "$installed_version" ]; then
    warn "Go is already installed: go$installed_version ($go_binary)"

    info "Checking for available updates..."
    latest_version=$(get_latest_go_version)
    info "Latest available: go$latest_version"

    if compare_versions "$installed_version" "$latest_version"; then
        bold "\n🚀 NEW VERSION AVAILABLE!"
        info "Installed: go$installed_version  →  Available: go$latest_version"
        read -p "Update to go$latest_version? (Y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            info "Update cancelled."
            exit 0
        fi
        GO_VERSION="$latest_version"
    else
        success "✅ Already on the latest version (go$installed_version)"
        exit 0
    fi
else
    info "Go is not installed — fetching latest version..."
    GO_VERSION=$(get_latest_go_version)
    info "Will install: go$GO_VERSION"
fi

GO_TAR="/tmp/go${GO_VERSION}.${GO_ARCH}.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"

echo ""
info "Downloading Go $GO_VERSION ($GO_ARCH)..."
curl -L --progress-bar -o "$GO_TAR" "$GO_DOWNLOAD_URL" || die "Failed to download Go"

info "Removing previous installation (if any)..."
rm -rf "$GO_INSTALL_DIR/go"

info "Extracting to $GO_INSTALL_DIR..."
tar -C "$GO_INSTALL_DIR" -xzf "$GO_TAR" || die "Failed to extract Go"
rm -f "$GO_TAR"

# Configure environment
cat > /etc/profile.d/go.sh << 'EOF'
# Go programming language configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF
chmod +x /etc/profile.d/go.sh

export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# Verify
if [ -x "$GO_INSTALL_DIR/go/bin/go" ]; then
    go_version=$("$GO_INSTALL_DIR/go/bin/go" version 2>/dev/null | awk '{print $3}')
    success "Go installed: $go_version"
    info "Location: $GO_INSTALL_DIR/go"
else
    die "Go binary not found after installation"
fi

echo ""
success "🎉 Go installation complete!"
info "To use Go in the current session, run:"
echo "   source /etc/profile.d/go.sh"
info "Or restart your terminal."
echo ""
