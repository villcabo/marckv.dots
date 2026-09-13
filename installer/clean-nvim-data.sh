#!/bin/bash
#
# Wipes Neovim's data dirs (share/state/cache) so the next install starts from
# nothing. --config also removes the config dir; a symlinked config only loses
# the link, never what it points at.
#
# It shares lib/common.sh for colors, logging, preview and confirmation, but
# deliberately keeps its own argument parser instead of installer_main: this is
# a helper, not one of the numbered installers, and "install a cleaner" means
# nothing. Alignment is about the shared behaviour, not about forcing three
# verbs onto a script that only does one thing.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="clean-nvim-data.sh"

APPNAME="${NVIM_APPNAME:-nvim}"
CONFIG_DIR="$HOME/.config/$APPNAME"

DATA_DIRS=(
    "$HOME/.local/share/$APPNAME"
    "$HOME/.local/state/$APPNAME"
    "$HOME/.cache/$APPNAME"
)

usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    echo
    echo -e "  Removes Neovim's data dirs (share, state, cache) for NVIM_APPNAME=${BOLD}${APPNAME}${NC}."
    echo
    echo -e "${BLUE}Usage:${NC} ./${INSTALLER_NAME} [--config] [-y]"
    echo
    echo -e "  ${YELLOW}-c, --config${NC}   Also remove ${CONFIG_DIR}."
    echo -e "                 A symlink there loses the link only, not the target."
    echo -e "  ${YELLOW}-y, --yes${NC}      Skip the confirmation. The preview is still printed."
    echo
}

dir_size()  { du -sh "$1" 2>/dev/null | cut -f1; }
dir_count() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }

# One preview entry: the dir, its weight, and what is inside it. Richer than
# preview_line on purpose — the size is the number that changes the answer.
print_dir_entry() {
    local dir="$1"
    echo -e "  ${RED}${BOLD}${dir}${NC}"
    echo -e "    Size: ${YELLOW}$(dir_size "$dir")${NC}   Files: ${YELLOW}$(dir_count "$dir")${NC}"

    local subdirs
    subdirs=$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    if [[ -n "$subdirs" ]]; then
        while IFS= read -r subdir; do
            echo -e "    ${BLUE}├─${NC} $(basename "$subdir")/ ${BLUE}($(dir_size "$subdir"))${NC}"
        done <<< "$subdirs"
    fi
    echo
}

main() {
    local include_config=false
    local arg
    for arg in "$@"; do
        case "$arg" in
            -c|--config)     include_config=true ;;
            -y|--yes)        ASSUME_YES=true ;;
            -h|--help|help)  usage; exit 0 ;;
            *)
                error "Unknown argument: $arg"; echo; usage; exit 1
                ;;
        esac
    done

    local has_config=false config_is_symlink=false
    local found_data=()

    if [[ "$include_config" == true ]]; then
        if [[ -L "$CONFIG_DIR" ]]; then
            has_config=true; config_is_symlink=true
        elif [[ -d "$CONFIG_DIR" ]]; then
            has_config=true
        fi
    fi

    local dir
    for dir in "${DATA_DIRS[@]}"; do
        [[ -d "$dir" ]] && found_data+=("$dir")
    done

    if [[ "$has_config" == false && ${#found_data[@]} -eq 0 ]]; then
        success "Nothing to clean — no Neovim directories found for ${BOLD}${APPNAME}${NC}"
        exit 0
    fi

    preview_open "Delete Neovim data for ${APPNAME}"

    if [[ "$has_config" == true ]]; then
        if [[ "$config_is_symlink" == true ]]; then
            echo -e "  ${RED}${BOLD}${CONFIG_DIR}${NC}  ${BLUE}(symlink -> $(readlink "$CONFIG_DIR"))${NC}"
            echo -e "    Only the link goes. What it points at is untouched."
            echo
        else
            print_dir_entry "$CONFIG_DIR"
        fi
    fi

    for dir in "${found_data[@]}"; do
        print_dir_entry "$dir"
    done

    [[ "$include_config" == false ]] && preview_line "KEEPS" "$CONFIG_DIR  (pass --config to remove it too)"
    warn "Irreversible. Plugins and parsers are downloaded again on the next start."
    preview_close

    # Captured, not tested inline: inside `if ! cmd`, $? is the negation's.
    local answer=0
    confirm_destructive "Delete all of it?" || answer=$?
    if (( answer != 0 )); then
        (( answer == 2 )) && exit 2
        info "Nothing was deleted."
        exit 0
    fi

    echo
    if [[ "$has_config" == true ]]; then
        if [[ "$config_is_symlink" == true ]]; then
            rm "$CONFIG_DIR"
            success "Removed symlink: $CONFIG_DIR"
        else
            rm -rf "$CONFIG_DIR"
            success "Deleted: $CONFIG_DIR"
        fi
    fi

    for dir in "${found_data[@]}"; do
        rm -rf "$dir"
        success "Deleted: $dir"
    done

    echo
    success "Done. Start nvim to rebuild plugins from scratch."
    info "Installer: ${BOLD}./04-install-nvim-lite.sh${NC}"
}

main "$@"
