#!/bin/bash
#
# Appends a source line to ~/.bash_aliases that loads the Gradle helpers.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="install-bash-extensions-gradle-functions.sh"
INSTALLER_ABOUT="Loads the Gradle helper functions from ~/.bash_aliases."

ALIASES_FILE="$HOME/.bash_aliases"
GRADLE_SOURCE="$MARCKV_DOTS_DIR/bash-extensions/bash_gradle_functions.sh"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" ]] && source "$HOME/.marckv.dots/bash-extensions/bash_gradle_functions.sh" # Gradle functions'

is_installed() {
    [[ -f "$ALIASES_FILE" ]] && grep -Fq "$LOAD_LINE" "$ALIASES_FILE"
}

do_install() {
    [[ -f "$GRADLE_SOURCE" ]] || die "Not found: $GRADLE_SOURCE"

    if is_installed; then
        warn "Already installed in $ALIASES_FILE"
        return 0
    fi

    preview_open "Install Gradle functions"
    preview_line "source" "$GRADLE_SOURCE"
    preview_line "into"   "$ALIASES_FILE"
    preview_line "adds"   "1 source line at the end"
    [[ -s "$ALIASES_FILE" ]] && preview_line "backup" "${ALIASES_FILE}.backup.<timestamp>"
    preview_close

    confirm "Append the source line?" || { info "Cancelled."; return 0; }

    [[ -f "$ALIASES_FILE" ]] || touch "$ALIASES_FILE"
    if [[ -s "$ALIASES_FILE" ]]; then
        local backup="${ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ALIASES_FILE" "$backup"
        info "Backup: $backup"
        echo "" >> "$ALIASES_FILE"
    fi

    echo "$LOAD_LINE" >> "$ALIASES_FILE"
    success "Installed"
    echo
    info "Apply it with: ${YELLOW}source ~/.bash_aliases${NC}"
}

do_status() {
    if is_installed; then
        success "Installed in $ALIASES_FILE"
        preview_line "sources" "$GRADLE_SOURCE"
    else
        warn "Not installed"
    fi
}

do_uninstall() {
    if ! is_installed; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    preview_open "Remove Gradle functions"
    preview_line "from"    "$ALIASES_FILE"
    preview_line "removes" "the source line"
    preview_line "keeps"   "the repo, and everything else in ~/.bash_aliases"
    preview_line "backup"  "${ALIASES_FILE}.backup.<timestamp>"
    preview_close

    confirm "Remove the source line?" || { info "Cancelled."; return 0; }

    local backup="${ALIASES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ALIASES_FILE" "$backup"
    info "Backup: $backup"

    grep -vF "$LOAD_LINE" "$ALIASES_FILE" > "${ALIASES_FILE}.tmp"
    mv "${ALIASES_FILE}.tmp" "$ALIASES_FILE"

    success "Removed"
}

installer_main "$@"
