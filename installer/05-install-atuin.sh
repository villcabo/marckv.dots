#!/bin/bash

# Script to install atuin (magical shell history) and link its configuration
# Downloads the release binary from GitHub and symlinks atuin/config.toml

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CONFIG="$MARCKV_DOTS_DIR/atuin/config.toml"
TARGET_CONFIG_DIR="$HOME/.config/atuin"
TARGET_CONFIG="$TARGET_CONFIG_DIR/config.toml"

# Install prefix: system-wide when running as root, per-user otherwise
if [[ $EUID -eq 0 ]]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi

ATUIN_VERSION=""   # empty = latest release

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            bold "marckv.dots atuin installer"
            echo ""
            echo -e "Installs ${YELLOW}atuin${NC} (shell history with fuzzy search) and links the"
            echo -e "repository config to ${YELLOW}~/.config/atuin/config.toml${NC}."
            echo ""
            echo -e "Sync is ${BOLD}disabled${NC} in the config: history never leaves the machine."
            echo ""
            echo -e "${BLUE}Usage:${NC} $0 [--version X.Y.Z]"
            echo ""
            exit 0
            ;;
        --version=*)
            ATUIN_VERSION="${arg#*=}"
            ;;
    esac
done

bold "=== marckv.dots atuin installer ==="

# Verify repo config exists
if [[ ! -f "$SOURCE_CONFIG" ]]; then
    error "Source config not found: $SOURCE_CONFIG"
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Binary
# ---------------------------------------------------------------------------
if command -v atuin >/dev/null 2>&1; then
    warn "atuin is already installed: $(atuin --version)"
    info "Skipping binary installation (remove it first to reinstall)."
else
    # Detect architecture
    case "$(uname -m)" in
        x86_64)  ARCH="x86_64" ;;
        aarch64) ARCH="aarch64" ;;
        *)       error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    # Resolve version
    if [[ -z "$ATUIN_VERSION" ]]; then
        info "Resolving latest release..."
        # Capture the response before parsing it: piping curl straight into
        # `grep -m1` closes the pipe early and curl reports
        # "(23) Failure writing output to destination".
        RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/atuinsh/atuin/releases/latest)"
        ATUIN_VERSION="$(printf '%s' "$RELEASE_JSON" | grep -m1 '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')"
        [[ -z "$ATUIN_VERSION" ]] && { error "Could not resolve the latest version"; exit 1; }
    fi

    TARBALL="atuin-${ARCH}-unknown-linux-gnu.tar.gz"
    URL="https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/${TARBALL}"
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Downloading atuin v${ATUIN_VERSION} (${ARCH})..."
    curl -fsSL -o "$TMP_DIR/$TARBALL" "$URL"

    info "Installing to $INSTALL_DIR..."
    tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$TMP_DIR"/atuin-*/atuin "$INSTALL_DIR/atuin"

    success "atuin installed: $("$INSTALL_DIR/atuin" --version)"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
        warn "$INSTALL_DIR is not in your PATH"
        echo -e "  Add it with: ${YELLOW}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Configuration
# ---------------------------------------------------------------------------
mkdir -p "$TARGET_CONFIG_DIR"

if [[ -L "$TARGET_CONFIG" && "$TARGET_CONFIG" -ef "$SOURCE_CONFIG" ]]; then
    warn "config.toml is already linked to the repository config"
elif [[ -e "$TARGET_CONFIG" || -L "$TARGET_CONFIG" ]]; then
    BACKUP="$TARGET_CONFIG.backup.$(date +%Y%m%d%H%M%S)"
    warn "Existing config found, backing it up"
    mv "$TARGET_CONFIG" "$BACKUP"
    info "Backup: $BACKUP"
    ln -s "$SOURCE_CONFIG" "$TARGET_CONFIG"
    success "Symlink created: $TARGET_CONFIG -> $SOURCE_CONFIG"
else
    ln -s "$SOURCE_CONFIG" "$TARGET_CONFIG"
    success "Symlink created: $TARGET_CONFIG -> $SOURCE_CONFIG"
fi

# ---------------------------------------------------------------------------
# 3. Shell integration
# ---------------------------------------------------------------------------
# bash/.bashrc sources bash/atuin.sh, which initialises atuin when present.
if grep -q "atuin.sh" "$MARCKV_DOTS_DIR/bash/.bashrc" 2>/dev/null; then
    success "Shell integration already present in bash/.bashrc"
else
    warn "bash/.bashrc does not source bash/atuin.sh - update the repository"
fi

echo ""
info "Next steps:"
echo -e "  1. Reload your shell: ${YELLOW}exec bash${NC}"
echo -e "  2. Search history:    ${YELLOW}Ctrl+R${NC}"
echo -e "  3. Import old history: ${YELLOW}atuin import auto${NC}"
echo ""
info "Sync is disabled: history stays on this machine."
