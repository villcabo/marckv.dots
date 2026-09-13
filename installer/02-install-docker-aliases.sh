#!/usr/bin/env bash
#
# Appends a source line to ~/.bash_aliases. That is the whole installation:
# the aliases are shell functions read straight from the repo, so editing them
# there takes effect in the next shell with nothing to re-run.
#
# It downloads nothing. The previous installer fetched the docker-color-output
# binary, which these aliases no longer use — they render their own tables, so
# they know what each column means and can colour it accordingly.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="02-install-docker-aliases.sh"
INSTALLER_ABOUT="Loads the docker aliases in every new shell. Works in bash and zsh.

  zsh does not read ~/.bash_aliases on its own. If yours does not source it
  yet, add this to ~/.zshrc AFTER compinit — the order matters, or compinit
  wipes the completions:

    [[ -f \"\$HOME/.bash_aliases\" ]] && source \"\$HOME/.bash_aliases\""

ALIASES_FILE="$HOME/.bash_aliases"
INIT_SCRIPT="$MARCKV_DOTS_DIR/docker-aliases/init.sh"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/docker-aliases/init.sh" ]] && source "$HOME/.marckv.dots/docker-aliases/init.sh"'
MARKER='docker-aliases/init.sh'
COMMENT='# marckv.dots Docker Aliases'

is_installed() {
    [[ -f "$ALIASES_FILE" ]] && grep -qF "$MARKER" "$ALIASES_FILE"
}

do_install() {
    [[ -f "$INIT_SCRIPT" ]] || die "Loader not found: $INIT_SCRIPT"

    if is_installed; then
        success "Already installed — nothing to do"
        return 0
    fi

    local n
    n=$(find "$MARCKV_DOTS_DIR/docker-aliases/commands" -name '*.sh' 2>/dev/null | wc -l)

    preview_open "Install docker aliases"
    preview_line "source"   "$INIT_SCRIPT"
    preview_line "commands" "$n"
    preview_line "into"     "$ALIASES_FILE"
    preview_line "adds"     "1 comment + 1 source line at the end"
    [[ -f "$ALIASES_FILE" ]] && preview_line "backup" "${ALIASES_FILE}.backup-<timestamp>"
    preview_close

    confirm "Append the source line?" || { info "Cancelled."; return 0; }

    if [[ ! -f "$ALIASES_FILE" ]]; then
        touch "$ALIASES_FILE"
    else
        local backup="${ALIASES_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$ALIASES_FILE" "$backup"
        info "Backup: $backup"
    fi

    printf '\n%s\n%s\n' "$COMMENT" "$LOAD_LINE" >> "$ALIASES_FILE"

    success "Source line added to $ALIASES_FILE"
    info "Open a new shell, or: ${YELLOW}source $ALIASES_FILE${NC}"
}

do_status() {
    if [[ -f "$INIT_SCRIPT" ]]; then
        success "Loader present: $INIT_SCRIPT"
        local n
        n=$(find "$MARCKV_DOTS_DIR/docker-aliases/commands" -name '*.sh' 2>/dev/null | wc -l)
        preview_line "commands" "$n"
    else
        error "Loader MISSING: $INIT_SCRIPT"
        return 1
    fi

    is_installed && success "Source line present in $ALIASES_FILE" \
                 || warn "Source line NOT in $ALIASES_FILE — run: ./${INSTALLER_NAME} install"

    # A stale line from the pre-rename layout would load nothing, silently.
    if [[ -f "$ALIASES_FILE" ]]; then
        grep -qF 'docker-aliases-v2/init.sh' "$ALIASES_FILE" \
            && warn "An old docker-aliases-v2 line is still there and points nowhere"
        grep -qF 'docker-color_aliases.sh' "$ALIASES_FILE" \
            && warn "An old docker-color_aliases line is still there and points nowhere"
    fi
    return 0
}

do_uninstall() {
    if ! is_installed; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    preview_open "Remove docker aliases"
    preview_line "from"    "$ALIASES_FILE"
    preview_line "removes" "the source line and the comment above it"
    preview_line "keeps"   "the repo, and everything else in ~/.bash_aliases"
    preview_line "backup"  "${ALIASES_FILE}.backup-<timestamp>"
    preview_close

    confirm "Remove the source line?" || { info "Cancelled."; return 0; }

    local backup="${ALIASES_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$ALIASES_FILE" "$backup"
    info "Backup: $backup"

    # The comment line above it goes too, so uninstalling twice leaves no litter.
    grep -vF "$MARKER" "$ALIASES_FILE" | grep -vxF "$COMMENT" > "${ALIASES_FILE}.tmp"
    mv "${ALIASES_FILE}.tmp" "$ALIASES_FILE"

    success "Source line removed"
    info "The repo directory is untouched — reinstall with: ${BOLD}./${INSTALLER_NAME}${NC}"
}

installer_main "$@"
