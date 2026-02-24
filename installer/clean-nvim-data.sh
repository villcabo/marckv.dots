#!/bin/bash

# Script to clean Neovim data directories before fresh nvim-lite install
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

DIRS=(
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

main() {
    bold "=== Neovim data cleaner ==="
    info "Scanning directories for NVIM_APPNAME=${BOLD}$APPNAME${NC}..."
    echo ""

    local found=()

    for dir in "${DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            found+=("$dir")
        fi
    done

    if [[ ${#found[@]} -eq 0 ]]; then
        success "Nothing to clean — no Neovim data directories found."
        exit 0
    fi

    bold "Directories to be deleted:"
    echo ""

    local total_size=0
    for dir in "${found[@]}"; do
        local size
        size=$(dir_size "$dir")
        local count
        count=$(dir_count "$dir")
        echo -e "  ${RED}${BOLD}${dir}${NC}"
        echo -e "    Size: ${YELLOW}${size}${NC}   Files: ${YELLOW}${count}${NC}"

        # Show top-level subdirectories for context
        if [[ -d "$dir" ]]; then
            local subdirs
            subdirs=$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
            if [[ -n "$subdirs" ]]; then
                while IFS= read -r subdir; do
                    local subname
                    subname=$(basename "$subdir")
                    local subsize
                    subsize=$(dir_size "$subdir")
                    echo -e "    ${BLUE}├─${NC} ${subname}/ ${BLUE}(${subsize})${NC}"
                done <<< "$subdirs"
            fi
        fi
        echo ""
    done

    warn "This action is irreversible. Make sure nvim-lite will be installed after this."
    echo ""
    read -p "Delete all listed directories? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted. Nothing was deleted."
        exit 0
    fi

    echo ""
    for dir in "${found[@]}"; do
        rm -rf "$dir"
        success "Deleted: $dir"
    done

    echo ""
    success "Done. Run nvim to install nvim-lite plugins from scratch."
}

main "$@"
