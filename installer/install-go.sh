#!/bin/bash

# Script to install Go following the official instructions from go.dev
# Based on: https://go.dev/doc/install

# === CONFIGURABLE VARIABLES ===
GO_VERSION=""  # Auto-detected
GO_ARCH=""     # Auto-detected
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

# Logging functions
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }

die() {
    error "$1"
    exit 1
}

# Verify script is running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        info "Usage: sudo $0"
        exit 1
    fi
}

# Detect system architecture
detect_architecture() {
    local os_type
    local arch_type

    # This script is designed for Linux/WSL
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        error "This script is designed for Linux/WSL, not Git Bash on Windows"
        info "Please run this script in WSL or a Linux system"
        exit 1
    fi

    os_type="linux"

    # Detect architecture
    arch_type=$(uname -m)
    case $arch_type in
        x86_64|amd64)
            arch_type="amd64"
            ;;
        aarch64|arm64)
            arch_type="arm64"
            ;;
        armv6l)
            arch_type="armv6l"
            ;;
        i386|i686)
            arch_type="386"
            ;;
        *)
            arch_type="amd64"  # Fallback
            ;;
    esac

    echo "${os_type}-${arch_type}"
}

# Get the latest Go version
get_latest_go_version() {
    local latest_version

    # Scrape the official downloads page
    latest_version=$(curl -s https://go.dev/dl/ | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

    # Fallback to a known stable version
    if [ -z "$latest_version" ] || [[ "$latest_version" =~ [^0-9.] ]]; then
        latest_version="1.23.3"
    fi

    echo "$latest_version"
}

# Compare version strings semantically
compare_versions() {
    local installed="$1"
    local available="$2"

    if [ -z "$installed" ] || [ -z "$available" ]; then
        return 1
    fi

    # Use sort -V for semantic comparison
    local higher=$(printf '%s\n%s\n' "$installed" "$available" | sort -V | tail -n1)

    if [ "$higher" = "$available" ] && [ "$installed" != "$available" ]; then
        return 0  # A newer version is available
    else
        return 1  # Already up to date
    fi
}

# Check for an existing Go installation
check_existing_installation() {
    # Detect system architecture
    GO_ARCH=$(detect_architecture)
    info "Detected architecture: $GO_ARCH"

    # Check multiple locations because sudo may change PATH
    local go_binary=""
    local installed_version=""

    # 1. Check current PATH
    if command -v go >/dev/null 2>&1; then
        go_binary=$(command -v go)
        installed_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
    # 2. Check standard install location
    elif [ -x "/usr/local/go/bin/go" ]; then
        go_binary="/usr/local/go/bin/go"
        installed_version=$(/usr/local/go/bin/go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
    # 3. Check /usr/bin
    elif [ -x "/usr/bin/go" ]; then
        go_binary="/usr/bin/go"
        installed_version=$(/usr/bin/go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
    fi

    if [ -n "$go_binary" ] && [ -n "$installed_version" ]; then
        warn "Go is already installed"
        info "Installed version: go$installed_version"
        info "Location: $go_binary"

        # Check if a newer version is available
        info "Checking for available updates..."
        local latest_version
        latest_version=$(get_latest_go_version)

        if [ -n "$latest_version" ]; then
            info "Latest available version: go$latest_version"

            if compare_versions "$installed_version" "$latest_version"; then
                success "🚀 New version available!"
                info "Installed version: go$installed_version"
                info "Available version: go$latest_version"

                read -p "Update to the latest version? (Y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    info "Update cancelled"
                    exit 0
                fi

                # Set variables for the new version
                GO_VERSION="$latest_version"
            else
                success "✅ You already have the latest version installed"
                info "No update needed"
                exit 0
            fi
        else
            warn "Could not verify the latest version"
            read -p "Reinstall Go anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Installation cancelled"
                exit 0
            fi
            GO_VERSION="1.23.3"  # Fallback version
        fi
    else
        # Go is not installed — get the latest version
        info "Go is not installed"
        GO_VERSION=$(get_latest_go_version)
        info "Will install the latest version: go$GO_VERSION"
    fi

    # Configure URLs after determining the version
    GO_TAR="/tmp/go${GO_VERSION}.${GO_ARCH}.tar.gz"
    GO_DOWNLOAD_URL="https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"

    # Show what will be installed
    echo ""
    info "📦 Preparing Go $GO_VERSION installation"
}

# Download Go
download_go() {
    info "Downloading Go $GO_VERSION..."

    if curl -L --progress-bar -o "$GO_TAR" "$GO_DOWNLOAD_URL"; then
        success "Go downloaded successfully"
    else
        die "Failed to download Go from: $GO_DOWNLOAD_URL"
    fi
}

# Install Go
install_go() {
    info "Removing previous Go installation (if any)..."
    rm -rf "$GO_INSTALL_DIR/go"

    info "Installing Go to $GO_INSTALL_DIR..."
    if tar -C "$GO_INSTALL_DIR" -xzf "$GO_TAR"; then
        success "Go installed successfully"
    else
        die "Failed to extract Go"
    fi

    # Remove temp file
    rm -f "$GO_TAR"
}

# Configure environment variables
setup_environment() {
    info "Configuring environment variables..."

    # Create configuration file in /etc/profile.d/
    cat > /etc/profile.d/go.sh << 'EOF'
# Go programming language configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF

    chmod +x /etc/profile.d/go.sh
    success "Environment variables configured in /etc/profile.d/go.sh"

    # Apply to current session
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
}

# Verify installation
verify_installation() {
    info "Verifying installation..."

    if [ ! -x "$GO_INSTALL_DIR/go/bin/go" ]; then
        die "Go binary not found at $GO_INSTALL_DIR/go/bin/go"
    fi

    local go_version
    go_version=$("$GO_INSTALL_DIR/go/bin/go" version 2>/dev/null | awk '{print $3}')

    if [ -n "$go_version" ]; then
        success "Go installed successfully: $go_version"
        info "Location: $GO_INSTALL_DIR/go"
        info "Environment configured in: /etc/profile.d/go.sh"
    else
        die "Go is not responding correctly"
    fi
}

# Show final information
show_final_info() {
    echo ""
    success "🎉 Go installation complete!"
    info "To use Go in the current session, run:"
    echo "   source /etc/profile.d/go.sh"
    info "Or restart your terminal/session"
    echo ""
    info "Useful commands:"
    echo "   go version      # Show installed version"
    echo "   go mod init     # Initialize a module"
    echo "   go run main.go  # Run a program"
    echo ""
}

# === MAIN FUNCTION ===
main() {
    info "🚀 Starting Go installer"

    # Validate environment first
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        error "This script must be run on Linux or WSL, not Git Bash"
        info "Options:"
        info "  1. Use WSL: wsl -d Ubuntu sudo bash install-go.sh"
        info "  2. Run on a real Linux system"
        exit 1
    fi

    check_root
    check_existing_installation
    download_go
    install_go
    setup_environment
    verify_installation
    show_final_info
}

# Run main function
main "$@"
