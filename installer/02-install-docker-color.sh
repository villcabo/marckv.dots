#!/bin/bash

# Script to install marckv.dots docker color aliases
# This script adds a reference to docker-color_aliases.sh in ~/.bash_aliases

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

# Confirmation function
_confirm_operation() {
    local message="${1:-Continue with operation?}"
    printf "${BOLD}${YELLOW}${message} [yes/N]: ${NC}"
    read -r response
    [[ "$response" == "yes" ]]
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
DOCKER_COLOR_ALIASES="$MARCKV_DOTS_DIR/docker-aliases/docker-color_aliases.sh"

# Line to be added to ~/.bash_aliases
LOAD_LINE='[[ -s "$HOME/.marckv.dots/docker-aliases/docker-color_aliases.sh" ]] && source "$HOME/.marckv.dots/docker-aliases/docker-color_aliases.sh"'

# Function to check/install docker-color-output binary
check_docker_color_binary() {
    info "Checking docker-color-output binary..."
    
    if command -v docker-color-output >/dev/null 2>&1; then
        local current_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "Unknown version")
        success "docker-color-output is available: $current_version"
        return 0
    fi
    
    warn "docker-color-output binary not found."
    info "Attempting to install docker-color-output..."
    
    # Determine installation directory and method
    local install_dir=""
    local use_sudo=false
    
    if [[ $EUID -eq 0 ]]; then
        # Running as root
        install_dir="/usr/local/bin"
        info "Running as root - installing to system-wide location: $install_dir"
    elif sudo -n true 2>/dev/null; then
        # User has sudo privileges
        install_dir="/usr/local/bin"
        use_sudo=true
        info "Sudo available - installing to system-wide location: $install_dir"
    else
        # Regular user without sudo - install to user directory
        install_dir="$HOME/.local/bin"
        info "Installing to user directory: $install_dir"
        
        # Create ~/.local/bin if it doesn't exist
        if [[ ! -d "$install_dir" ]]; then
            info "Creating directory: $install_dir"
            mkdir -p "$install_dir"
        fi
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$install_dir:"* ]]; then
            warn "$install_dir is not in your PATH"
            info "The binary will be installed but may not be immediately accessible"
            info "Your bash configuration should add ~/.local/bin to PATH automatically"
        fi
    fi
    
    # Detect architecture
    local arch=$(uname -m)
    local download_arch=""
    case "$arch" in
        x86_64|amd64)
            download_arch="amd64"
            ;;
        aarch64|arm64)
            download_arch="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            info "Supported architectures: x86_64, aarch64"
            return 1
            ;;
    esac
    
    # Download and install
    info "Downloading docker-color-output for $download_arch..."
    local download_url="https://github.com/devemio/docker-color-output/releases/latest/download/docker-color-output-linux-$download_arch"
    local temp_file="/tmp/docker-color-output"
    
    if wget -q "$download_url" -O "$temp_file"; then
        info "Installing to $install_dir/docker-color-output..."
        chmod +x "$temp_file"
        
        if [[ "$use_sudo" == true ]]; then
            sudo mv "$temp_file" "$install_dir/docker-color-output"
        else
            mv "$temp_file" "$install_dir/docker-color-output"
        fi
        
        # Verify installation
        if command -v docker-color-output >/dev/null 2>&1; then
            local installed_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "Unknown version")
            success "docker-color-output installed successfully: $installed_version"
            return 0
        else
            error "Installation failed - binary not found after installation"
            return 1
        fi
    else
        error "Failed to download docker-color-output"
        info "Please install manually from: https://github.com/devemio/docker-color-output/releases"
        return 1
    fi
}

# Function to install only aliases
install_aliases_only() {
    info "Installing Docker Color Aliases..."
    
    # Verificar que existe el directorio marckv.dots
    if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
        error "Directory $MARCKV_DOTS_DIR does not exist."
        error "Make sure the volume is properly mounted in the container."
        exit 1
    fi
    
    # Verificar que existe el archivo docker-color_aliases.sh
    if [[ ! -f "$DOCKER_COLOR_ALIASES" ]]; then
        error "File $DOCKER_COLOR_ALIASES not found"
        exit 1
    fi
    
    info "marckv.dots directory found: $MARCKV_DOTS_DIR"
    info "Docker color aliases file: $DOCKER_COLOR_ALIASES"
    
    # Crear ~/.bash_aliases si no existe
    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        info "Creating ~/.bash_aliases since it doesn't exist..."
        touch "$BASH_ALIASES_FILE"
    fi
    
    # Verificar si ya está instalado
    if grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        warn "Docker color aliases are already installed in $BASH_ALIASES_FILE"
        info "No changes needed."
        return 0
    fi
    
    # Hacer backup del ~/.bash_aliases si no está vacío
    if [[ -s "$BASH_ALIASES_FILE" ]]; then
        local backup_file="${BASH_ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup of ~/.bash_aliases in $backup_file"
        cp "$BASH_ALIASES_FILE" "$backup_file"
    fi
    
    # Agregar la línea de carga al final del ~/.bash_aliases
    info "Adding Docker color aliases loading to ~/.bash_aliases..."
    echo "" >> "$BASH_ALIASES_FILE"
    echo "# marckv.dots Docker Color Aliases" >> "$BASH_ALIASES_FILE"
    echo "$LOAD_LINE" >> "$BASH_ALIASES_FILE"
    
    success "Docker color aliases installed successfully!"
    echo ""
    bold "To apply changes:"
    echo -e "  ${YELLOW}source ~/.bash_aliases${NC}  ${BLUE}# or restart terminal${NC}"
    echo ""
    info "Docker aliases (d, dc) and color output are now available."
}

# Function for complete installation (binary + aliases)
install_docker_color() {
    bold "=== marckv.dots Docker Color Complete Setup ==="
    
    # Show complete installation preview
    echo ""
    bold "=== Installation Preview ==="
    
    # Check current status for preview
    local binary_status="Will be installed"
    local binary_location=""
    local install_method=""
    
    if command -v docker-color-output >/dev/null 2>&1; then
        local current_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "Unknown version")
        binary_status="Already installed ($current_version)"
    else
        # Determine where it would be installed
        if [[ $EUID -eq 0 ]]; then
            binary_location="/usr/local/bin/docker-color-output"
            install_method="Direct installation (running as root)"
        elif sudo -n true 2>/dev/null; then
            binary_location="/usr/local/bin/docker-color-output"
            install_method="Using sudo for system installation"
        else
            binary_location="$HOME/.local/bin/docker-color-output"
            install_method="User installation (no special privileges needed)"
        fi
    fi
    
    # Check aliases status
    local aliases_status="Will be installed"
    if [[ -f "$BASH_ALIASES_FILE" ]] && grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        aliases_status="Already installed (will skip)"
    fi
    
    info "Component 1: docker-color-output binary"
    info "  Status: $binary_status"
    if [[ -n "$binary_location" ]]; then
        info "  Location: $binary_location"
        info "  Method: $install_method"
    fi
    info "  Architecture: $(uname -m)"
    echo ""
    
    info "Component 2: Docker Color Aliases"
    info "  Status: $aliases_status"
    info "  Location: $BASH_ALIASES_FILE"
    info "  Source: $DOCKER_COLOR_ALIASES"
    echo ""
    
    info "Features that will be available:"
    info "  • Docker shortcuts: d ps, d logs, d x"
    info "  • Compose shortcuts: dc up, dc down, dc logs"
    info "  • Smart confirmations for destructive operations"
    info "  • Enhanced autocompletion for containers and services"
    info "  • Color-coded output integration"
    info "  • Quick execution functions: dq, dcq"
    echo ""
    
    # Ask for confirmation for the complete installation
    if ! _confirm_operation "Continue with complete Docker Color setup?"; then
        echo -e "${BOLD}${YELLOW}Installation cancelled${NC} ⚠️"
        return 1
    fi
    
    echo ""
    
    # Step 1: Check/Install docker-color-output binary
    info "Step 1/2: Docker Color Output Binary"
    check_docker_color_binary
    
    echo ""
    
    # Step 2: Install aliases
    info "Step 2/2: Docker Aliases"
    install_aliases_only
    
    # Final summary
    echo ""
    bold "=== Installation Complete ==="
    if command -v docker-color-output >/dev/null 2>&1; then
        success "✅ docker-color-output binary: Available (enhanced colored output)"
    else
        warn "⚠️  docker-color-output binary: Not available (standard output)"
    fi
    success "✅ Docker aliases: Installed (d, dc shortcuts)"
}

# Function to uninstall
uninstall_docker_color() {
    bold "=== Docker Color Aliases uninstaller ==="
    
    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        warn "~/.bash_aliases doesn't exist, nothing to uninstall."
        return 0
    fi
    
    if ! grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        warn "Docker color aliases are not installed."
        return 0
    fi
    
    # Crear backup antes de modificar
    local backup_file="${BASH_ALIASES_FILE}.uninstall_backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup in $backup_file"
    cp "$BASH_ALIASES_FILE" "$backup_file"
    
    # Remove lines related to marckv.dots Docker Color Aliases
    info "Removing marckv.dots Docker Color Aliases configuration from ~/.bash_aliases..."
    sed -i '/# marckv.dots Docker Color Aliases/d' "$BASH_ALIASES_FILE"
    sed -i '\|'"$LOAD_LINE"'|d' "$BASH_ALIASES_FILE"
    
    # Remove empty lines at the end
    sed -i '${/^[[:space:]]*$/d;}' "$BASH_ALIASES_FILE"
    
    success "Docker color aliases uninstalled successfully!"
    info "Backup created in: $backup_file"
}

# Function to install docker-color-output binary
install_docker_color_binary() {
    bold "=== Docker Color Output Binary installer ==="
    check_docker_color_binary
}

# Function to show status
status_docker_color() {
    bold "=== Docker Color Aliases status ==="
    
    if [[ ! -d "$MARCKV_DOTS_DIR" ]]; then
        error "marckv.dots directory not found: $MARCKV_DOTS_DIR"
        return 1
    else
        success "marckv.dots directory: $MARCKV_DOTS_DIR"
    fi
    
    if [[ ! -f "$DOCKER_COLOR_ALIASES" ]]; then
        error "Docker color aliases not found: $DOCKER_COLOR_ALIASES"
        return 1
    else
        success "Docker color aliases: $DOCKER_COLOR_ALIASES"
    fi
    
    if [[ ! -f "$BASH_ALIASES_FILE" ]]; then
        warn "~/.bash_aliases doesn't exist"
    elif grep -Fq "$LOAD_LINE" "$BASH_ALIASES_FILE"; then
        success "Docker color aliases are INSTALLED in ~/.bash_aliases"
    else
        warn "Docker color aliases are NOT installed in ~/.bash_aliases"
    fi
    
    # Check if docker is available
    if command -v docker >/dev/null 2>&1; then
        success "Docker command available: $(docker --version)"
    else
        warn "Docker command not found"
    fi
    
    # Check if docker compose is available
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        success "Docker Compose available: $(docker compose version --short 2>/dev/null || echo 'available')"
    else
        warn "Docker Compose not available"
    fi
    
    # Check if docker-color-output is available
    if command -v docker-color-output >/dev/null 2>&1; then
        local docker_color_version=$(docker-color-output --version 2>/dev/null | head -1 || echo "Unknown version")
        local docker_color_path=$(which docker-color-output)
        success "docker-color-output available: $docker_color_version"
        info "Location: $docker_color_path"
    else
        warn "docker-color-output not found (standard Docker output will be used)"
        info "Use '$0 binary' to install docker-color-output for enhanced colored output"
    fi
    
    echo ""
    info "System: $(uname -sr)"
    if command -v lsb_release >/dev/null 2>&1; then
        info "Distribution: $(lsb_release -d | cut -f2)"
    fi
    info "Current shell: $SHELL"
}

# Main menu
case "${1:-install}" in
    install|i)
        install_docker_color
        ;;
    aliases|a)
        bold "=== Docker Color Aliases installer ==="
        install_aliases_only
        ;;
    binary|bin)
        install_docker_color_binary
        ;;
    uninstall|u)
        uninstall_docker_color
        ;;
    status|s)
        status_docker_color
        ;;
    *)
        bold "🐳 marckv.dots Docker Color Aliases installer"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo -e "  ${GREEN}$0 [install|i]${NC}    - Install complete setup (binary + aliases)"
        echo -e "  ${GREEN}$0 aliases|a${NC}       - Install only Docker aliases"
        echo -e "  ${GREEN}$0 binary|bin${NC}       - Check docker-color-output binary status"
        echo -e "  ${GREEN}$0 uninstall|u${NC}    - Uninstall Docker color aliases"
        echo -e "  ${GREEN}$0 status|s${NC}       - Show installation status"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  ${CYAN}$0${NC}                 # Install complete setup (binary + aliases)"
        echo -e "  ${CYAN}$0 install${NC}         # Install complete setup (binary + aliases)"
        echo -e "  ${CYAN}$0 aliases${NC}         # Install only aliases"
        echo -e "  ${CYAN}$0 binary${NC}          # Check docker-color-output binary status"
        echo -e "  ${CYAN}$0 uninstall${NC}       # Uninstall aliases"
        echo -e "  ${CYAN}$0 status${NC}          # Check status"
        echo ""
        ;;
esac