#!/bin/bash
#
# Installs vim-lite: the repo's vim/ directory as ~/.vim. A symlink by default
# (repo edits are live), or a copy with -c for a host that should not depend
# on the repo staying where it is.
#
# Nothing is downloaded. The one thing it may install is Vim itself, from apt,
# when the host has no Vim or only vim-tiny — and only with root or sudo;
# without them it says what to ask an admin for and installs the config anyway.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="06-install-vim.sh"
INSTALLER_ABOUT="Installs vim-lite (plain Vim, no plugins) as ~/.vim."

SOURCE_VIM="$MARCKV_DOTS_DIR/vim"
TARGET_VIM="$HOME/.vim"
TARGET_VIMRC="$HOME/.vimrc"

use_copy=false

installer_flag() {
    case "$1" in
        -c|--copy) use_copy=true ;;
        *) return 1 ;;
    esac
    return 0
}

installer_usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    echo
    echo -e "  ${INSTALLER_ABOUT}"
    echo
    echo -e "${BLUE}Usage:${NC} ./${INSTALLER_NAME} [install|status|uninstall] [-c] [-y]"
    echo
    echo -e "  ${YELLOW}install${NC}      Link ~/.vim to the repo's vim/. The default."
    echo -e "  ${YELLOW}status${NC}       Which Vim this host has, and whether vim-lite is in place."
    echo -e "  ${YELLOW}uninstall${NC}    Remove the link (a copy is moved to a backup, not deleted)."
    echo
    echo -e "  ${YELLOW}-c, --copy${NC}   Copy vim/ instead of linking it."
    echo -e "  ${YELLOW}-y, --yes${NC}    Skip the confirmation. The plan is still printed."
    echo
}

is_linked() { [[ -L "$TARGET_VIM" && "$TARGET_VIM" -ef "$SOURCE_VIM" ]]; }

# A copy this installer made: a real directory carrying vim-lite's own files.
is_our_copy() {
    [[ -d "$TARGET_VIM" && ! -L "$TARGET_VIM" && -f "$TARGET_VIM/plugin/lite.vim" && -f "$TARGET_VIM/VERSION" ]]
}

# full | tiny | none. vim-tiny has no +eval: it reads only the top of vimrc.
# A backup name that does not exist yet. Two backups in the same second used
# to share a name, and `mv ~/.vim <existing dir>` moves the copy INTO the
# earlier backup instead of next to it.
backup_name() {
    local b="${TARGET_VIM}.backup.$(date +%Y%m%d_%H%M%S)"
    [[ -e "$b" ]] && b="${b}.$$"
    echo "$b"
}

vim_kind() {
    local v
    command -v vim &>/dev/null || { echo none; return; }
    v=$(vim --version 2>/dev/null)
    [[ "$v" == *"+eval"* && "$v" == *"+syntax"* ]] && echo full || echo tiny
}

vim_version() { vim --version 2>/dev/null | head -n1 | sed -E 's/.*IMproved ([0-9.]+).*/\1/'; }

# Vim 9.1 with the patches the live pickers need, or something older.
vim_live_pickers() {
    vim -Nu NONE -es -c 'if !exists("*wildtrigger") || !exists("+findfunc") | cquit | endif' -c 'qa!' &>/dev/null
}

do_install() {
    [[ -d "$SOURCE_VIM" ]] || die "Not found: $SOURCE_VIM"

    local kind; kind=$(vim_kind)

    if [[ -e "$TARGET_VIMRC" || -L "$TARGET_VIMRC" ]]; then
        # Vim reads ~/.vimrc INSTEAD of ~/.vim/vimrc. Installing past it would
        # report success and change nothing.
        error "~/.vimrc exists, and Vim reads it instead of ~/.vim/vimrc"
        info "Move it yourself if you want vim-lite: ${YELLOW}mv ~/.vimrc ~/.vimrc.mine${NC}"
        return 1
    fi
    if [[ -e "$TARGET_VIM" || -L "$TARGET_VIM" ]] && ! is_linked && ! is_our_copy; then
        error "~/.vim exists and was not created by this installer"
        info "Move it yourself if you want it replaced: ${YELLOW}mv ~/.vim ~/.vim.mine${NC}"
        return 1
    fi

    if [[ "$use_copy" == false ]] && is_linked && [[ "$kind" == full ]]; then
        warn "Already installed"
        return 0
    fi

    preview_open "Install vim-lite"
    if [[ "$use_copy" == true ]]; then
        is_our_copy && preview_line "replace" "$TARGET_VIM (previous copy, moved to a backup first)"
        preview_line "copy" "$SOURCE_VIM -> $TARGET_VIM"
    else
        is_linked && preview_line "config" "already linked — unchanged" \
                  || preview_line "symlink" "$TARGET_VIM -> $SOURCE_VIM"
    fi
    case "$kind" in
        full) preview_line "vim" "$(vim_version), full — nothing to install" ;;
        *)    if [[ "$PRIV_MODE" == user ]]; then
                  preview_line "vim" "${kind} — needs root to install; will be reported, not installed"
              else
                  preview_line "apt" "vim (this host has ${kind/none/no Vim})"
              fi ;;
    esac
    preview_line "state" "~/.local/state/vim (swap, backup, undo — created on first start)"
    preview_close

    confirm "Install it?" || { info "Cancelled."; return 0; }

    if [[ "$kind" != full ]]; then
        if [[ "$PRIV_MODE" == user ]]; then
            warn "Vim is ${kind/none/missing}, and installing it needs root"
            info "Ask an admin to run: ${BOLD}sudo apt-get install -y vim${NC} — the config below will be ready for it"
        else
            info "Installing Vim from apt"
            _run apt-get update -qq && _run apt-get install -y -qq vim \
                && success "Vim installed: $(vim_version)" \
                || warn "Could not install Vim from apt — the config is installed anyway"
        fi
    fi

    if [[ "$use_copy" == true ]]; then
        if is_linked; then
            rm -f "$TARGET_VIM"
        elif is_our_copy; then
            local backup; backup=$(backup_name)
            mv "$TARGET_VIM" "$backup"
            info "Previous copy moved to $backup"
        fi
        cp -a "$SOURCE_VIM" "$TARGET_VIM"
        success "Copied: $SOURCE_VIM -> $TARGET_VIM"
    elif is_linked; then
        info "Config already linked"
    else
        if is_our_copy; then
            local backup; backup=$(backup_name)
            mv "$TARGET_VIM" "$backup"
            info "Previous copy moved to $backup"
        fi
        ln -s "$SOURCE_VIM" "$TARGET_VIM"
        success "Symlink created: $TARGET_VIM -> $SOURCE_VIM"
    fi

    if [[ "$(vim_kind)" == full ]] && ! vim_live_pickers; then
        info "Vim $(vim_version) predates the live pickers: <Space><Space> and <Space>/ work as plain :find and :Grep"
    fi
    echo
    info "Open ${YELLOW}vim${NC} with no file for the key list, or press ${YELLOW}Space ?${NC} inside it"
}

do_status() {
    local kind; kind=$(vim_kind)
    case "$kind" in
        full) if vim_live_pickers; then
                  success "Vim $(vim_version), full, with the live pickers"
              else
                  info "Vim $(vim_version), full — no live pickers (needs 9.1 with findfunc and wildtrigger)"
              fi ;;
        tiny) warn "Only vim-tiny: no syntax, no plugins — install the full ${BOLD}vim${NC} package" ;;
        none) warn "Vim is not installed" ;;
    esac

    if is_linked; then
        success "Config linked to $SOURCE_VIM"
    elif is_our_copy; then
        info "Config copied to $TARGET_VIM (version $(<"$TARGET_VIM/VERSION"))"
    elif [[ -e "$TARGET_VIM" ]]; then
        warn "~/.vim exists but is not ours"
    else
        warn "Config not installed"
    fi
    [[ -e "$TARGET_VIMRC" ]] && warn "~/.vimrc exists: Vim reads it instead of ~/.vim/vimrc"
    return 0
}

do_uninstall() {
    if ! is_linked && ! is_our_copy; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    preview_open "Remove vim-lite"
    is_linked && preview_line "unlink" "$TARGET_VIM"
    is_our_copy && preview_line "move" "$TARGET_VIM -> ${TARGET_VIM}.backup.<date>"
    preview_line "keeps" "Vim itself, and ~/.local/state/vim (undo history)"
    preview_close

    confirm "Remove it?" || { info "Cancelled."; return 0; }

    if is_linked; then
        rm -f "$TARGET_VIM"
        success "Symlink removed"
    else
        local backup; backup=$(backup_name)
        mv "$TARGET_VIM" "$backup"
        success "Copy moved to $backup"
    fi
    info "The repo is untouched — reinstall with: ${BOLD}./${INSTALLER_NAME}${NC}"
}

installer_main "$@"
