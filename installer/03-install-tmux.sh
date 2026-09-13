#!/bin/bash
#
# Symlinks ~/.tmux.conf to the repo's tmux/.tmux.conf and clones TPM.
# No copy: edits in the repo are live.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="03-install-tmux.sh"
INSTALLER_ABOUT="Links ~/.tmux.conf to the repo config and installs TPM."

SOURCE_TMUX_CONF="$MARCKV_DOTS_DIR/tmux/.tmux.conf"
TARGET_TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_URL="https://github.com/tmux-plugins/tpm"

is_linked() {
    [[ -L "$TARGET_TMUX_CONF" && "$TARGET_TMUX_CONF" -ef "$SOURCE_TMUX_CONF" ]]
}

do_install() {
    command -v tmux &>/dev/null || die "tmux is not installed — sudo apt install tmux"
    [[ -f "$SOURCE_TMUX_CONF" ]] || die "Not found: $SOURCE_TMUX_CONF"

    if is_linked && [[ -d "$TPM_DIR" ]]; then
        warn "Already installed"
        return 0
    fi

    # A config that is not our symlink belongs to whoever wrote it. Refuse
    # rather than back it up: a .tmux.conf is usually hand-tuned, and quietly
    # moving it aside is how someone loses a year of keybindings.
    if [[ ! -L "$TARGET_TMUX_CONF" ]] && [[ -e "$TARGET_TMUX_CONF" ]]; then
        error "~/.tmux.conf exists and was not created by this installer"
        info "Move it yourself if you want it replaced: ${YELLOW}mv ~/.tmux.conf ~/.tmux.conf.mine${NC}"
        return 1
    fi

    preview_open "Install tmux config"
    is_linked && preview_line "config" "already linked — unchanged" \
              || preview_line "symlink" "$TARGET_TMUX_CONF -> $SOURCE_TMUX_CONF"
    [[ -d "$TPM_DIR" ]] && preview_line "tpm" "already at $TPM_DIR — unchanged" \
                        || preview_line "clone" "$TPM_URL -> $TPM_DIR"
    preview_close

    confirm "Install it?" || { info "Cancelled."; return 0; }

    if is_linked; then
        info "Config already linked"
    else
        ln -s "$SOURCE_TMUX_CONF" "$TARGET_TMUX_CONF"
        success "Symlink created: $TARGET_TMUX_CONF -> $SOURCE_TMUX_CONF"
    fi

    if [[ -d "$TPM_DIR" ]]; then
        info "TPM already at $TPM_DIR"
    else
        git clone --quiet "$TPM_URL" "$TPM_DIR"
        success "TPM installed at $TPM_DIR"
    fi

    echo
    info "Open tmux, then press ${YELLOW}Ctrl+a  I${NC} (capital i) to install plugins"
}

do_status() {
    if is_linked; then
        success "Config linked to $SOURCE_TMUX_CONF"
    elif [[ -e "$TARGET_TMUX_CONF" ]]; then
        warn "~/.tmux.conf exists but is not ours"
    else
        warn "Config not installed"
    fi
    [[ -d "$TPM_DIR" ]] && success "TPM at $TPM_DIR" || warn "TPM not installed"
}

do_uninstall() {
    if ! is_linked && [[ ! -d "$TPM_DIR" ]]; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    preview_open "Remove tmux config"
    is_linked && preview_line "unlink" "$TARGET_TMUX_CONF" \
              || preview_line "config" "not ours — left alone"
    [[ -d "$TPM_DIR" ]] && preview_line "delete" "$TPM_DIR  (TPM and its plugins)" \
                        || preview_line "tpm" "not installed"
    preview_line "keeps" "the repo, and any plugin config in ~/.tmux.conf.local"
    preview_close

    confirm "Remove it?" || { info "Cancelled."; return 0; }

    # Only our own symlink. A real file there is someone else's work.
    if is_linked; then
        rm -f "$TARGET_TMUX_CONF"
        success "Symlink removed"
    fi
    if [[ -d "$TPM_DIR" ]]; then
        rm -rf "$TPM_DIR"
        success "TPM removed"
    fi
    info "The repo is untouched — reinstall with: ${BOLD}./${INSTALLER_NAME}${NC}"
}

installer_main "$@"
