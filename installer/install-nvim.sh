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

# Paths
NVIM_PATH="/opt/nvim"
PROFILE_PATH="/etc/profile.d/nvim.sh"

# Version to install (empty = latest). Can be set via --version flag.
NVIM_VERSION=""

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

die() { error "$1"; exit 1; }

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            bold "marckv.dots Neovim installer"
            echo ""
            echo -e "Installs Neovim system-wide to ${ORANGE}$NVIM_PATH${NC}."
            echo -e "Requires ${ORANGE}root/sudo${NC}."
            echo ""
            echo -e "${BLUE}Usage:${NC} sudo $0 [--version <tag>]"
            echo ""
            echo -e "${BLUE}Flags:${NC}"
            echo -e "  ${YELLOW}--version <tag>${NC}   Install a specific version (e.g. v0.10.3)"
            echo -e "  ${YELLOW}--ls-remote${NC}       List installable versions with distro compatibility"
            echo -e "  ${YELLOW}-h, --help${NC}        Show this help"
            echo ""
            echo -e "${BLUE}GLIBC compatibility:${NC}"
            echo -e "  ${ORANGE}Debian 11${NC} (GLIBC 2.31): use ${YELLOW}--version v0.10.3${NC} or older"
            echo -e "  ${ORANGE}Debian 12+${NC} (GLIBC 2.36+): latest works"
            echo -e "  ${ORANGE}Ubuntu 20${NC} (GLIBC 2.31): use ${YELLOW}--version v0.10.3${NC} or older"
            echo -e "  ${ORANGE}Ubuntu 22+${NC} (GLIBC 2.35+): latest works"
            echo ""
            exit 0
            ;;
        --version)
            NVIM_VERSION="$2"
            [[ -z "$NVIM_VERSION" ]] && die "--version requires a tag argument (e.g. v0.10.3)"
            shift 2
            ;;
        --ls-remote)
            LS_REMOTE=true
            shift
            ;;
        *)
            error "Unknown argument: $1"
            info "Run with ${BOLD}--help${NC} for usage"
            exit 1
            ;;
    esac
done

# Build URLs based on version selection
# Older versions (<= v0.10.3) use nvim-linux64.tar.gz
# Newer versions (>= v0.10.4) use nvim-linux-x86_64.tar.gz
build_urls() {
    local version="$1"
    local archive_name

    if [[ -z "$version" ]]; then
        # Latest release — use new naming
        archive_name="nvim-linux-x86_64.tar.gz"
        NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${archive_name}"
    else
        # Specific version — determine archive name by version
        local ver="${version#v}"
        local major minor patch
        IFS='.' read -r major minor patch <<< "$ver"
        # v0.10.3 and older use nvim-linux64.tar.gz
        if [[ "$major" -eq 0 && "$minor" -le 10 && "$patch" -le 3 ]] || [[ "$major" -eq 0 && "$minor" -lt 10 ]]; then
            archive_name="nvim-linux64.tar.gz"
        else
            archive_name="nvim-linux-x86_64.tar.gz"
        fi
        NVIM_URL="https://github.com/neovim/neovim/releases/download/${version}/${archive_name}"
    fi
    NVIM_TAR="/tmp/${archive_name}"
    NVIM_ARCHIVE_DIR="${archive_name%.tar.gz}"
}

# Map a version tag to distro compatibility string.
# Based on the GLIBC requirement of Neovim's prebuilt binaries:
#   v0.10.4+  → GLIBC 2.34+ (Debian 12+, Ubuntu 22.04+)
#   v0.10.0-3 → GLIBC 2.31+ (Debian 11+, Ubuntu 20.04+)
#   v0.9.x-   → GLIBC 2.17+ (Debian 10+, Ubuntu 18.04+)
version_compat() {
    local ver="${1#v}"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    if [[ "$major" -ge 1 ]] || [[ "$major" -eq 0 && "$minor" -ge 11 ]]; then
        echo "Debian 12+, Ubuntu 22.04+"
    elif [[ "$major" -eq 0 && "$minor" -eq 10 ]]; then
        if [[ "${patch:-0}" -ge 4 ]]; then
            echo "Debian 12+, Ubuntu 22.04+"
        else
            echo "Debian 11+, Ubuntu 20.04+"
        fi
    else
        echo "Debian 10+, Ubuntu 18.04+"
    fi
}

# List installable Neovim versions with distro compatibility
list_remote_versions() {
    bold "=== Available Neovim versions ==="
    echo ""
    info "Fetching releases from GitHub API..."
    echo ""

    local releases
    releases=$(curl -sf "https://api.github.com/repos/neovim/neovim/releases?per_page=20") \
        || die "Failed to fetch releases from GitHub"

    local tags
    tags=$(echo "$releases" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | grep -v 'nightly')

    printf "  ${BOLD}%-12s${NC}  ${BOLD}%s${NC}\n" "VERSION" "SUPPORTED DISTROS"
    printf "  %-12s  %s\n" "-------" "-----------------"

    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        local compat
        compat=$(version_compat "$tag")
        printf "  ${YELLOW}%-12s${NC}  %s\n" "$tag" "$compat"
    done <<< "$tags"

    echo ""
    info "Install with: ${BOLD}sudo $0 --version <tag>${NC}"
    echo ""
    exit 0
}

# Handle --ls-remote before root check (listing doesn't need root)
[[ "${LS_REMOTE:-false}" == true ]] && list_remote_versions

# Verify root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    info "Usage: ${BOLD}sudo $0${NC}"
    exit 1
fi

bold "=== Neovim installer ==="
build_urls "$NVIM_VERSION"
[[ -n "$NVIM_VERSION" ]] && info "Requested version: ${BOLD}$NVIM_VERSION${NC}"

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

# Determine target version
if [[ -n "$NVIM_VERSION" ]]; then
    target_version="$NVIM_VERSION"
else
    info "Fetching latest release from GitHub..."
    target_version=$(get_latest_version)
    [[ -z "$target_version" ]] && die "Failed to fetch latest version from GitHub"
fi

# Rebuild URLs now that we know the target version
build_urls "$target_version"

# Detect currently installed version (if any)
installed_version=""
if [ -d "$NVIM_PATH" ] && [ -f "$PROFILE_PATH" ]; then
    installed_version=$(get_installed_version)
fi

# Short-circuit if already on target version (unless user forced --version)
if [[ -z "$NVIM_VERSION" && -n "$installed_version" && "$installed_version" == "$target_version" ]]; then
    success "✅ Already on the latest version ($installed_version)"
    exit 0
fi

# Preview
echo ""
bold "=== INSTALLATION PREVIEW ==="
echo -e "${BLUE}Target version:${NC}       ${YELLOW}${BOLD}$target_version${NC}"
if [[ -n "$installed_version" ]]; then
    echo -e "${BLUE}Currently installed:${NC}  ${ORANGE}$installed_version${NC}"
else
    echo -e "${BLUE}Currently installed:${NC}  ${ORANGE}none${NC}"
fi
echo -e "${BLUE}Supported distros:${NC}    $(version_compat "$target_version")"
echo -e "${BLUE}Install path:${NC}         ${ORANGE}$NVIM_PATH${NC}"
echo -e "${BLUE}Profile script:${NC}       ${ORANGE}$PROFILE_PATH${NC}"
echo -e "${BLUE}Download URL:${NC}         ${ORANGE}$NVIM_URL${NC}"
echo ""

read -p "Type '${YELLOW}${BOLD}yes${NC}' to confirm installation: " -r
echo
if [[ "$REPLY" != "yes" ]]; then
    info "Cancelled."
    exit 0
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
[ -d "/opt/nvim-linux64" ] && rm -rf "/opt/nvim-linux64"

# Extract
info "Extracting to /opt..."
temp_dir="/tmp/nvim-extract"
rm -rf "$temp_dir"
mkdir -p "$temp_dir"
tar -C "$temp_dir" -xzf "$NVIM_TAR" || die "Failed to extract Neovim"

# Find the extracted directory (name varies by version)
extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name 'nvim-linux*' | head -1)
if [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
    mv "$extracted_dir" "$NVIM_PATH"
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
