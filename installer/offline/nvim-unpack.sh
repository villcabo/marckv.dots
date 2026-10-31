#!/bin/bash
#
# Installs nvim-lite from an offline pack (nvim-pack.sh), on a host with no
# internet. Run it once per user — root first, then development or whoever —
# because the plugins and parsers live in each user's ~/.local/share/nvim.
#
# Nothing here is a new way of installing: each piece goes where the regular
# installers and Neovim already look, and those installers do the rest.
#   Neovim      -> the /tmp cache install-nvim.sh reads, then --version <tag>
#                  (system-wide with root or sudo, ~/.local without)
#   fzf, tree-sitter -> /usr/local/bin with root, ~/.local/bin without
#   plugins, parsers -> ~/.local/share/nvim (the previous one moved aside)
#   the config  -> 04-install-nvim-lite.sh, as usual

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

INSTALLER_NAME="offline/nvim-unpack.sh"
INSTALLER_ABOUT="Installs nvim-lite from an offline pack, for this user."

pack_file=""
use_copy=false

installer_flag() {
    case "$1" in
        -c|--copy) use_copy=true ;;
        -*) return 1 ;;
        *) [[ -z "$pack_file" ]] || return 1; pack_file="$1" ;;
    esac
    return 0
}

installer_usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    echo
    echo -e "  ${INSTALLER_ABOUT}"
    echo
    echo -e "${BLUE}Usage:${NC} installer/offline/nvim-unpack.sh <marckv-nvim-<tag>.tgz> [-c] [-y]"
    echo
    echo -e "  ${YELLOW}-c, --copy${NC}   Copy the nvim-lite config instead of linking it."
    echo -e "  ${YELLOW}-y, --yes${NC}    Skip the confirmation. The plan is still printed."
    echo
    echo -e "Run it once per user — root first. The pack comes from"
    echo -e "${BOLD}installer/offline/nvim-pack.sh${NC} on a machine with internet."
    echo
}

DATA_DIR="$HOME/.local/share/nvim"

# A name for the previous data dir that does not exist yet.
backup_name() {
    local b="${DATA_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    [[ -e "$b" ]] && b="${b}.$$"
    echo "$b"
}

manifest() { sed -n "s/^$1=//p" "$WORK/pack/MANIFEST"; }

do_install() {
    [[ -n "$pack_file" ]] || { installer_usage; die "Which pack? Give the .tgz nvim-pack.sh wrote"; }
    [[ -f "$pack_file" ]] || die "Not found: $pack_file"

    WORK=$(mktemp -d "${TMPDIR:-/tmp}/marckv-nvim-unpack.XXXXXX")
    trap 'rm -rf "$WORK"' EXIT
    tar -xzf "$pack_file" -C "$WORK" || die "Not a pack: $pack_file"
    [[ -f "$WORK/pack/MANIFEST" ]] || die "Not a pack (no MANIFEST): $pack_file"

    local tag archive glibc have_glibc current bin_dir lua_tree repo_tree
    tag=$(manifest NVIM_TAG)
    archive=$(manifest NVIM_ARCHIVE)
    glibc=$(manifest GLIBC_NEEDED)
    have_glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    if [[ "$(printf '%s\n%s\n' "$glibc" "$have_glibc" | sort -V | tail -n1)" != "$have_glibc" ]]; then
        die "This pack needs GLIBC $glibc and this host has $have_glibc — it is for Ubuntu 22.04+ and Debian 12+"
    fi

    current=$(nvim --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || true)
    [[ "$PRIV_MODE" == user ]] && bin_dir="$HOME/.local/bin" || bin_dir="/usr/local/bin"

    # Plugins are built for one nvim-lite. Against a different one, lazy would
    # try to download what is missing — which, offline, is an error on every
    # start. Compared by the git tree of nvim-lite/lua, not by version number.
    lua_tree=$(manifest NVIM_LITE_LUA_TREE)
    repo_tree=$(git -C "$MARCKV_DOTS_DIR" rev-parse HEAD:nvim-lite/lua 2>/dev/null || true)

    preview_open "Install nvim-lite from an offline pack"
    preview_line "pack" "$(basename "$pack_file") — nvim-lite $(manifest NVIM_LITE_VERSION), built $(manifest BUILT)"
    if [[ "$current" == "$tag" ]]; then
        preview_line "neovim" "$tag already installed — unchanged"
    else
        preview_line "neovim" "$tag ${current:+(replacing $current) }— $([[ $PRIV_MODE == user ]] && echo "$HOME/.local" || echo "/opt/nvim, system-wide")"
    fi
    preview_line "tools" "fzf $(manifest FZF), tree-sitter $(manifest TREE_SITTER) -> $bin_dir (if missing)"
    [[ -e "$DATA_DIR" ]] && preview_line "move" "$DATA_DIR -> ${DATA_DIR}.backup.<date>"
    preview_line "unpack" "$DATA_DIR ($(manifest PARSERS) parsers, plugins)"
    preview_line "config" "04-install-nvim-lite.sh$([[ $use_copy == true ]] && echo " --copy")"
    if [[ -n "$repo_tree" && "$repo_tree" != "$lua_tree" ]]; then
        preview_line "warning" "built for a different nvim-lite than ~/.marckv.dots has — rebuild the pack"
    fi
    preview_close

    confirm "Install it?" || { info "Cancelled — nothing was changed."; return 0; }

    if [[ "$current" != "$tag" ]]; then
        # install-nvim.sh caches downloads at /tmp/nvim-<tag>-<archive>: with
        # the file already there it installs without the network.
        # When root unpacked first, the file is there already and is root's: a
        # user cannot overwrite it, and has no need to when it is the same one.
        local cache="/tmp/$archive"
        cmp -s "$WORK/pack/$archive" "$cache" 2>/dev/null || cp "$WORK/pack/$archive" "$cache"
        if [[ "$PRIV_MODE" == user ]]; then
            "$INSTALLER_DIR/install-nvim.sh" --version "$tag" -y
        else
            _run "$INSTALLER_DIR/install-nvim.sh" --version "$tag" -y
        fi
    else
        success "Neovim $tag already installed"
    fi

    local tool
    for tool in fzf tree-sitter; do
        if command -v "$tool" &>/dev/null && "$tool" --version &>/dev/null; then
            info "$tool already on PATH: $(command -v "$tool")"
            continue
        fi
        if [[ "$bin_dir" == "$HOME"/* ]]; then
            mkdir -p "$bin_dir" && install -m 755 "$WORK/pack/bin/$tool" "$bin_dir/$tool"
        else
            _run install -m 755 "$WORK/pack/bin/$tool" "$bin_dir/$tool"
        fi
        success "$tool installed in $bin_dir"
    done

    if [[ -e "$DATA_DIR" ]]; then
        local backup; backup=$(backup_name)
        mv "$DATA_DIR" "$backup"
        info "Previous plugins and parsers moved to $backup"
    fi
    mkdir -p "$(dirname "$DATA_DIR")"
    tar -xzf "$WORK/pack/share-nvim.tar.gz" -C "$(dirname "$DATA_DIR")"
    cp "$WORK/pack/MANIFEST" "$DATA_DIR/marckv-pack.manifest"
    success "Plugins and parsers unpacked in $DATA_DIR"

    local args=(-y)
    [[ "$use_copy" == true ]] && args+=(--copy)
    "$INSTALLER_DIR/04-install-nvim-lite.sh" "${args[@]}"

    echo
    success "nvim-lite is ready, offline."
    info "A new Neovim is on PATH from your next login — or now with: ${YELLOW}exec bash -l${NC}"
}

do_status() {
    if [[ -f "$DATA_DIR/marckv-pack.manifest" ]]; then
        success "Installed from an offline pack:"
        sed 's/^/  /' "$DATA_DIR/marckv-pack.manifest"
    else
        info "Not installed from an offline pack (no $DATA_DIR/marckv-pack.manifest)"
    fi
}

do_uninstall() {
    info "Use ${BOLD}installer/04-install-nvim-lite.sh uninstall${NC} — the pack only placed files"
    info "where the regular installers look, and 04 knows how to remove them."
}

installer_main "$@"
