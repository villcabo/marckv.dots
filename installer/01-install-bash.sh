#!/bin/bash
#
# Appends a source line to ~/.bashrc pointing at the repo's bash/.bashrc.
# No copy: edits in the repo are live.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="01-install-bash.sh"
INSTALLER_ABOUT="Loads the custom bash config from ~/.bashrc. Repo edits are live."

BASHRC_FILE="$HOME/.bashrc"
MARCK_BASHRC="$MARCKV_DOTS_DIR/bash/.bashrc"
MARKER="# marckv.dots custom bashrc"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash/.bashrc" ]] && source "$HOME/.marckv.dots/bash/.bashrc"'

is_installed() {
    [[ -f "$BASHRC_FILE" ]] && grep -Fq "$LOAD_LINE" "$BASHRC_FILE"
}

do_install() {
    [[ -f "$MARCK_BASHRC" ]] || die "Not found: $MARCK_BASHRC"

    if is_installed; then
        warn "Already installed in $BASHRC_FILE"
        return 0
    fi

    preview_open "Install bash config"
    preview_line "source"   "$MARCK_BASHRC"
    preview_line "into"     "$BASHRC_FILE"
    preview_line "adds"     "1 comment + 1 source line at the end"
    [[ -s "$BASHRC_FILE" ]] && preview_line "backup" "${BASHRC_FILE}.backup.<timestamp>"
    preview_close

    confirm "Append the source line?" || { info "Cancelled."; return 0; }

    [[ -f "$BASHRC_FILE" ]] || touch "$BASHRC_FILE"
    if [[ -s "$BASHRC_FILE" ]]; then
        local backup="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$BASHRC_FILE" "$backup"
        info "Backup: $backup"
    fi

    printf '\n%s\n%s\n' "$MARKER" "$LOAD_LINE" >> "$BASHRC_FILE"
    success "Installed"
    echo
    info "Apply it with: ${YELLOW}source ~/.bashrc${NC}"
}

do_status() {
    if is_installed; then
        success "Installed in $BASHRC_FILE"
        preview_line "sources" "$MARCK_BASHRC"
    else
        warn "Not installed"
        info "Install it with: ${BOLD}./${INSTALLER_NAME}${NC}"
    fi
}

do_uninstall() {
    if ! is_installed; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    preview_open "Remove bash config"
    preview_line "from"   "$BASHRC_FILE"
    preview_line "removes" "the source line and the comment above it"
    preview_line "keeps"  "the repo, and everything else in ~/.bashrc"
    preview_line "backup" "${BASHRC_FILE}.backup.<timestamp>"
    preview_close

    confirm "Remove the source line?" || { info "Cancelled."; return 0; }

    local backup="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BASHRC_FILE" "$backup"
    info "Backup: $backup"

    # The marker comment goes with it, so uninstalling twice leaves no litter.
    grep -vF "$LOAD_LINE" "$BASHRC_FILE" | grep -vxF "$MARKER" > "${BASHRC_FILE}.tmp"
    mv "${BASHRC_FILE}.tmp" "$BASHRC_FILE"

    success "Removed"
    info "The repo is untouched — reinstall with: ${BOLD}./${INSTALLER_NAME}${NC}"
}

installer_main "$@"
