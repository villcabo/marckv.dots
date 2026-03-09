#!/bin/bash

# === CONFIGURABLE VARIABLES ===
NODE_VERSION="22.0.0"
NODE_DISTRO="linux-x64"
NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
NODE_TAR="/tmp/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
NODE_DIR="/opt/nodejs"
NODE_PROFILE="/etc/profile.d/node.sh"

# Colors using tput (256 colors)
PINK=$(tput setaf 204)
PURPLE=$(tput setaf 141)
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

die() {
    error "$1"
    exit 1
}

# Get the latest Node.js LTS version
get_latest_node_version() {
    local latest_version
    # Filter by "lts" field not false to get only LTS versions
    if command -v python3 >/dev/null 2>&1; then
        latest_version=$(curl -s https://nodejs.org/dist/index.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
lts = [d for d in data if d.get('lts')]
print(lts[0]['version'].lstrip('v')) if lts else sys.exit(1)
" 2>/dev/null)
    else
        # Fallback: find the first entry where lts is not false
        latest_version=$(curl -s https://nodejs.org/dist/index.json | \
            grep -v '"lts":false' | grep -o '"version":"v[^"]*"' | head -1 | \
            cut -d'"' -f4 | sed 's/v//')
    fi

    if [ -z "$latest_version" ]; then
        return 1
    fi

    echo "$latest_version"
    return 0
}

# Get the currently installed Node.js version
get_installed_node_version() {
    if command -v node >/dev/null 2>&1; then
        local installed_version
        installed_version=$(node --version 2>/dev/null | sed 's/v//')
        if [ -n "$installed_version" ]; then
            echo "$installed_version"
            return 0
        fi
    fi
    return 1
}

# Compare version strings
compare_node_versions() {
    local installed="$1"
    local latest="$2"

    # Use sort -V for version comparison
    local higher_version=$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n1)

    if [ "$higher_version" = "$latest" ] && [ "$installed" != "$latest" ]; then
        return 0  # A newer version is available
    else
        return 1  # Already up to date
    fi
}

# Check for an existing Node.js installation
check_existing_node_installation() {
    if command -v node >/dev/null 2>&1 && [ -f "$NODE_PROFILE" ]; then
        warn "Node.js is already installed"
        local current_version=$(node --version)
        local installed_version=$(get_installed_node_version)
        info "Current version: ${BOLD}$current_version${NC}"

        # Check if a newer version is available
        info "Checking for available updates..."
        local latest_version=$(get_latest_node_version)

        if [ $? -eq 0 ] && [ -n "$latest_version" ]; then
            info "Latest available version: ${BOLD}v$latest_version${NC}"

            if compare_node_versions "$installed_version" "$latest_version"; then
                bold "\n🚀 NEW VERSION AVAILABLE!"
                info "Installed version: ${YELLOW}v$installed_version${NC}"
                info "Available version: ${GREEN}v$latest_version${NC}"
                warn "Update recommended to get the latest fixes and improvements"

                echo ""
                read -p "Update to the latest version? (Y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    info "Update cancelled"
                    exit 0
                fi
                success "Proceeding with update..."
                # Update variables to use the latest version
                NODE_VERSION="$latest_version"
                NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
                NODE_TAR="/tmp/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
            else
                success "✅ You already have the latest version installed"
                info "No update needed"
                exit 0
            fi
        else
            warn "Could not verify the latest version"
            read -p "Reinstall Node.js anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Installation cancelled"
                exit 0
            fi
            warn "Proceeding with reinstall..."
        fi
    else
        info "Node.js is not installed"
        info "Checking the latest available version..."
        local latest_version=$(get_latest_node_version)

        if [ $? -eq 0 ] && [ -n "$latest_version" ]; then
            info "Will install the latest version: ${BOLD}${GREEN}v$latest_version${NC}"
            # Update variables to use the latest version
            NODE_VERSION="$latest_version"
            NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
            NODE_TAR="/tmp/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
        else
            warn "Could not verify the latest version, falling back to default: $NODE_VERSION"
        fi
    fi
}

install_node() {
    if [ ! -f "$NODE_TAR" ] || [ ! -s "$NODE_TAR" ]; then
        info "Downloading Node.js $NODE_VERSION to $NODE_TAR..."
        curl -L -o "$NODE_TAR" "$NODE_BASE_URL" || die "Failed to download Node.js."
    else
        info "Using already downloaded Node.js archive at $NODE_TAR."
    fi
    # Install xz-utils if not present
    if ! command -v xz >/dev/null 2>&1; then
        info "Installing xz-utils to decompress .tar.xz..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y xz-utils || die "Failed to install xz-utils."
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y xz || die "Failed to install xz."
        elif command -v yum >/dev/null 2>&1; then
            yum install -y xz || die "Failed to install xz."
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm xz || die "Failed to install xz."
        else
            die "No compatible package manager found to install xz-utils."
        fi
    fi
    info "Extracting Node.js to $NODE_DIR..."
    rm -rf "$NODE_DIR"
    mkdir -p "$NODE_DIR"
    tar -xf "$NODE_TAR" -C "$NODE_DIR" --strip-components=1 || die "Failed to extract Node.js."
    info "Configuring global PATH for Node.js..."
    echo "export PATH=\"\$PATH:$NODE_DIR/bin\"" > "$NODE_PROFILE"
    chmod 644 "$NODE_PROFILE"
    success "Node.js $NODE_VERSION installed to $NODE_DIR."
}

reload_shell_environment() {
    info "Reloading environment variables..."

    # Reload Node.js profile
    if [ -f "$NODE_PROFILE" ]; then
        source "$NODE_PROFILE"
        success "Node.js environment variables loaded."
    fi

    # Verify Node.js is available
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        success "Node.js is available: $node_version"

        # Check npm as well
        if command -v npm >/dev/null 2>&1; then
            local npm_version=$(npm --version)
            success "npm is available: v$npm_version"
        fi
    else
        warn "Node.js is not available in the current PATH."
        info "Run: ${YELLOW}${BOLD}source $NODE_PROFILE${NC}"
        info "Or restart your terminal to apply changes."
    fi
}

bold "=== Node.js $NODE_VERSION installer ==="

# Check for existing installation
check_existing_node_installation

install_node

# Reload environment to recognise Node.js
reload_shell_environment

echo
info "To use Node.js in new terminal sessions:"
echo -e "  ${YELLOW}${BOLD}1.${NC} Environment variables are already configured globally"
echo -e "  ${YELLOW}${BOLD}2.${NC} Restart your terminal, or run: ${YELLOW}${BOLD}source $NODE_PROFILE${NC}"
echo -e "  ${YELLOW}${BOLD}3.${NC} Verify with: ${YELLOW}${BOLD}node --version${NC}"

success "Done: Node.js $NODE_VERSION installed and configured."
