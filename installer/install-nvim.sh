#!/bin/bash

# Script to install Neovim system-wide
# Requires root/sudo permissions

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

# URLs and paths
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
NVIM_TAR="/tmp/nvim-linux-x86_64.tar.gz"
NVIM_PATH="/opt/nvim"
PROFILE_PATH="/etc/profile.d/nvim.sh"

# Logging functions
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Get the latest available Neovim release tag
get_latest_version() {
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_version" ]; then
        return 1
    fi

    echo "$latest_version"
    return 0
}

# Get the currently installed Neovim version
get_installed_version() {
    if [ -x "$NVIM_PATH/bin/nvim" ]; then
        local installed_version
        installed_version=$($NVIM_PATH/bin/nvim --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
        echo "$installed_version"
        return 0
    fi
    return 1
}

# Compare version strings
compare_versions() {
    local installed="$1"
    local latest="$2"

    # Strip leading 'v' for comparison
    local installed_clean=$(echo "$installed" | sed 's/^v//')
    local latest_clean=$(echo "$latest" | sed 's/^v//')

    # Use sort -V for version comparison
    local higher_version=$(printf '%s\n%s\n' "$installed_clean" "$latest_clean" | sort -V | tail -n1)

    if [ "$higher_version" = "$latest_clean" ] && [ "$installed_clean" != "$latest_clean" ]; then
        return 0  # A newer version is available
    else
        return 1  # Already up to date
    fi
}

# Check command exit status
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$2"
        exit 1
    fi
}

# Verify script is running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        info "Usage: ${BOLD}sudo $0${NC}"
        exit 1
    fi
}

# Check for an existing Neovim installation
check_existing_installation() {
    if [ -d "$NVIM_PATH" ] && [ -f "$PROFILE_PATH" ]; then
        warn "Neovim is already installed"
        info "Install path: ${BOLD}$NVIM_PATH${NC}"

        # Check current version
        if [ -x "$NVIM_PATH/bin/nvim" ]; then
            local current_version=$($NVIM_PATH/bin/nvim --version | head -n1)
            local installed_version=$(get_installed_version)
            info "Current version: ${BOLD}$current_version${NC}"

            # Check if a newer version is available
            info "Checking for available updates..."
            local latest_version=$(get_latest_version)

            if [ $? -eq 0 ] && [ -n "$latest_version" ]; then
                info "Latest available version: ${BOLD}$latest_version${NC}"

                if compare_versions "$installed_version" "$latest_version"; then
                    bold "\n🚀 NEW VERSION AVAILABLE!"
                    info "Installed version: ${YELLOW}$installed_version${NC}"
                    info "Available version: ${GREEN}$latest_version${NC}"
                    warn "Update recommended to get the latest fixes and improvements"

                    echo ""
                    read -p "Update to the latest version? (Y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Nn]$ ]]; then
                        info "Update cancelled"
                        exit 0
                    fi
                    success "Proceeding with update..."
                else
                    success "✅ You already have the latest version installed"
                    info "No update needed"
                    exit 0
                fi
            else
                warn "Could not verify the latest version"
                read -p "Reinstall Neovim anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Installation cancelled"
                    exit 0
                fi
                warn "Proceeding with reinstall..."
            fi
        else
            read -p "Reinstall Neovim? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Installation cancelled"
                exit 0
            fi
            warn "Proceeding with reinstall..."
        fi
    else
        # Not installed — check the latest available version
        info "Neovim is not installed"
        info "Checking the latest available version..."
        local latest_version=$(get_latest_version)

        if [ $? -eq 0 ] && [ -n "$latest_version" ]; then
            info "Will install the latest version: ${BOLD}${GREEN}$latest_version${NC}"
        else
            warn "Could not verify the latest version, proceeding with installation"
        fi
    fi
}

# Remove previous installation if present
cleanup_previous() {
    if [ -d "$NVIM_PATH" ]; then
        info "Removing previous Neovim installation..."
        rm -rf "$NVIM_PATH"
        check_status "Previous installation removed" "Failed to remove previous installation"
    fi

    # Also clean up legacy path if it exists
    if [ -d "/opt/nvim-linux-x86_64" ]; then
        info "Removing legacy installation path..."
        rm -rf "/opt/nvim-linux-x86_64"
        check_status "Legacy installation removed" "Failed to remove legacy installation"
    fi
}

# Download Neovim
download_neovim() {
    if [ -f "$NVIM_TAR" ] && [ -s "$NVIM_TAR" ]; then
        info "Using already downloaded Neovim archive at $NVIM_TAR."
    else
        info "Downloading Neovim from GitHub..."
        bold "URL: $NVIM_URL"
        curl -L -o "$NVIM_TAR" "$NVIM_URL"
        check_status "Neovim downloaded successfully" "Failed to download Neovim"
    fi
}

# Extract and install Neovim
install_neovim() {
    info "Extracting Neovim to /opt..."

    # Extract to a temporary directory first
    local temp_dir="/tmp/nvim-extract"
    mkdir -p "$temp_dir"

    tar -C "$temp_dir" -xzf "$NVIM_TAR"
    check_status "Neovim extracted to temp directory" "Failed to extract Neovim"

    # Move contents to /opt/nvim
    if [ -d "$temp_dir/nvim-linux-x86_64" ]; then
        mv "$temp_dir/nvim-linux-x86_64" "$NVIM_PATH"
        check_status "Neovim moved to $NVIM_PATH" "Failed to move Neovim to final path"
    else
        error "Unexpected tar archive structure"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Clean up temp directory
    rm -rf "$temp_dir"

    # Verify installation
    if [ ! -d "$NVIM_PATH" ]; then
        error "Installation directory was not created"
        exit 1
    fi

    if [ ! -x "$NVIM_PATH/bin/nvim" ]; then
        error "Neovim executable not found"
        exit 1
    fi
}

# Configure PATH for all users
setup_path() {
    info "Configuring PATH for all users..."

    echo "export PATH=\"\$PATH:$NVIM_PATH/bin\"" > "$PROFILE_PATH"
    check_status "Profile file created" "Failed to create profile file"

    chmod 644 "$PROFILE_PATH"
    check_status "Permissions set" "Failed to set permissions"
}

# Verify installation
verify_installation() {
    info "Verifying installation..."

    if [ -x "$NVIM_PATH/bin/nvim" ]; then
        local version=$($NVIM_PATH/bin/nvim --version | head -n1)
        success "Neovim installed successfully"
        bold "Installed version: $version"
        bold "Location: $NVIM_PATH/bin/nvim"
    else
        error "Installation verification failed"
        exit 1
    fi
}

# Reload shell environment
reload_shell_environment() {
    info "Reloading environment variables..."

    # Reload Neovim profile
    if [ -f "$PROFILE_PATH" ]; then
        source "$PROFILE_PATH"
        success "Neovim environment variables loaded."
    fi

    # Verify Neovim is available in the current PATH
    if command -v nvim >/dev/null 2>&1; then
        local nvim_version=$(nvim --version | head -n1)
        success "Neovim is available: $nvim_version"

        # Show executable path
        local nvim_path=$(which nvim)
        info "Executable found at: $nvim_path"
    else
        warn "Neovim is not available in the current PATH."
        info "Run: ${YELLOW}${BOLD}source $PROFILE_PATH${NC}"
        info "Or restart your terminal to apply changes."
    fi
}

# Show post-install information
show_post_install_info() {
    local installed_version=$(get_installed_version)

    echo
    info "To use Neovim in new terminal sessions:"
    echo -e "  ${YELLOW}${BOLD}1.${NC} Environment variables are already configured globally"
    echo -e "  ${YELLOW}${BOLD}2.${NC} Restart your terminal, or run: ${YELLOW}${BOLD}source $PROFILE_PATH${NC}"
    echo -e "  ${YELLOW}${BOLD}3.${NC} Verify with: ${YELLOW}${BOLD}nvim --version${NC}"

    bold "\n=== INSTALLATION COMPLETE ==="
    success "Neovim has been installed successfully for all users."
}

# Main function
main() {
    bold "=== NEOVIM INSTALLER ==="
    info "This script will install Neovim system-wide"

    # Initial checks
    check_root
    check_existing_installation

    # Installation process
    cleanup_previous
    download_neovim
    install_neovim
    setup_path
    verify_installation

    # Reload environment to recognise Neovim
    reload_shell_environment

    show_post_install_info

    success "\nInstallation completed successfully!"
}

# Run main function
main "$@"
