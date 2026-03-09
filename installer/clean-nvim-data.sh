#!/bin/bash

# Script to clean Neovim config and data directories before a fresh install
# Shows a preview of what will be deleted and asks for confirmation

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Directories to clean (default nvim appname)
APPNAME="${NVIM_APPNAME:-nvim}"

CONFIG_DIR="$HOME/.config/$APPNAME"

DATA_DIRS=(
    "$HOME/.local/share/$APPNAME"
    "$HOME/.local/state/$APPNAME"
    "$HOME/.cache/$APPNAME"
)

# Human-readable size of a directory
dir_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# Count files in a directory
dir_count() {
    find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Print directory entry with subdirs
print_dir_entry() {
    local dir="$1"
    local size count
    size=$(dir_size "$dir")
    count=$(dir_count "$dir")
    echo -e "  ${RED}${BOLD}${dir}${NC}"
    echo -e "    Size: ${YELLOW}${size}${NC}   Files: ${YELLOW}${count}${NC}"

    local subdirs
    subdirs=$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    if [[ -n "$subdirs" ]]; then
        while IFS= read -r subdir; do
            local subname subsize
            subname=$(basename "$subdir")
            subsize=$(dir_size "$subdir")
            echo -e "    ${BLUE}├─${NC} ${subname}/ ${BLUE}(${subsize})${NC}"
        done <<< "$subdirs"
    fi
    echo ""
}

main() {
    bold "=== Neovim full cleaner ==="
    info "Scanning directories for NVIM_APPNAME=${BOLD}$APPNAME${NC}..."
    echo ""

    local has_config=false
    local config_is_symlink=false
    local found_data=()

    # Check config directory
    if [[ -L "$CONFIG_DIR" ]]; then
        has_config=true
        config_is_symlink=true
    elif [[ -d "$CONFIG_DIR" ]]; then
        has_config=true
    fi

    # Check data directories
    for dir in "${DATA_DIRS[@]}"; do
        [[ -d "$dir" ]] && found_data+=("$dir")
    done

    if [[ "$has_config" == false && ${#found_data[@]} -eq 0 ]]; then
        success "Nothing to clean — no Neovim directories found."
        exit 0
    fi

    bold "Directories to be deleted:"
    echo ""

    # Show config directory
    if [[ "$has_config" == true ]]; then
        if [[ "$config_is_symlink" == true ]]; then
            local symlink_target
            symlink_target=$(readlink "$CONFIG_DIR")
            echo -e "  ${RED}${BOLD}${CONFIG_DIR}${NC}  ${BLUE}(symlink → ${symlink_target})${NC}"
            echo ""
        else
            print_dir_entry "$CONFIG_DIR"
        fi
    fi

    # Show data directories
    for dir in "${found_data[@]}"; do
        print_dir_entry "$dir"
    done

    warn "This action is irreversible. Run the installer again after this to set up a fresh config."
    echo ""
    read -p "Delete all listed directories? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted. Nothing was deleted."
        exit 0
    fi

    echo ""

    # Delete config
    if [[ "$has_config" == true ]]; then
        if [[ "$config_is_symlink" == true ]]; then
            rm "$CONFIG_DIR"
            success "Removed symlink: $CONFIG_DIR"
        else
            rm -rf "$CONFIG_DIR"
            success "Deleted: $CONFIG_DIR"
        fi
    fi

    # Delete data directories
    for dir in "${found_data[@]}"; do
        rm -rf "$dir"
        success "Deleted: $dir"
    done

    echo ""
    success "Done. Run the installer and then nvim to install plugins from scratch."
    info "Installer: ${BOLD}./04-install-nvim-lite.sh${NC}"
}

main "$@"
