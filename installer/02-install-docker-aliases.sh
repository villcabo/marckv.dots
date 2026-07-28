#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# marckv.dots — Docker aliases installer
#
# Appends a source line to ~/.bash_aliases. That is the whole installation:
# the aliases are shell functions read straight from the repo, so editing them
# there takes effect in the next shell with nothing to re-run.
#
# It downloads nothing. The previous installer fetched the docker-color-output
# binary, which these aliases no longer use — they render their own tables, so
# they know what each column means and can colour it accordingly.
#
# Usage: ./02-install-docker-aliases.sh [install|status|uninstall]
# ---------------------------------------------------------------------------
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ALIASES_FILE="$HOME/.bash_aliases"
INIT_SCRIPT="$MARCKV_DOTS_DIR/docker-aliases/init.sh"
LOAD_LINE='[[ -s "$HOME/.marckv.dots/docker-aliases/init.sh" ]] && source "$HOME/.marckv.dots/docker-aliases/init.sh"'
MARKER='docker-aliases/init.sh'

usage() {
    bold "marckv.dots — Docker aliases"
    echo
    echo "  Adds a source line to ~/.bash_aliases so the docker aliases load in"
    echo "  every new shell. Works in bash and zsh."
    echo
    echo -e "  ${YELLOW}install${NC}     Add the source line (default)"
    echo -e "  ${YELLOW}status${NC}      Report whether it is installed"
    echo -e "  ${YELLOW}uninstall${NC}   Remove the source line"
    echo
    echo "  zsh does not read ~/.bash_aliases on its own. If yours does not"
    echo "  source it yet, add this to ~/.zshrc AFTER compinit — the order"
    echo "  matters, or compinit wipes the completions:"
    echo
    echo '    [[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"'
}

is_installed() {
    [[ -f "$ALIASES_FILE" ]] && grep -qF "$MARKER" "$ALIASES_FILE"
}

do_status() {
    bold "Docker aliases"
    echo

    if [[ -f "$INIT_SCRIPT" ]]; then
        success "Loader present: $INIT_SCRIPT"
        local n
        n=$(find "$MARCKV_DOTS_DIR/docker-aliases/commands" -name '*.sh' 2>/dev/null | wc -l)
        info  "Commands available: $n"
    else
        error "Loader MISSING: $INIT_SCRIPT"
        return 1
    fi

    if is_installed; then
        success "Source line present in $ALIASES_FILE"
    else
        warn "Source line NOT in $ALIASES_FILE — run: $0 install"
    fi

    # A stale line from the pre-rename layout would load nothing, silently.
    if [[ -f "$ALIASES_FILE" ]] && grep -qF 'docker-aliases-v2/init.sh' "$ALIASES_FILE"; then
        warn "An old docker-aliases-v2 line is still there and points nowhere"
    fi
    if [[ -f "$ALIASES_FILE" ]] && grep -qF 'docker-color_aliases.sh' "$ALIASES_FILE"; then
        warn "An old docker-color_aliases line is still there and points nowhere"
    fi
}

do_install() {
    bold "Installing docker aliases"
    echo

    if [[ ! -f "$INIT_SCRIPT" ]]; then
        error "Loader not found: $INIT_SCRIPT"
        exit 1
    fi

    if is_installed; then
        success "Already installed — nothing to do"
        return 0
    fi

    if [[ ! -f "$ALIASES_FILE" ]]; then
        info "Creating $ALIASES_FILE"
        touch "$ALIASES_FILE"
    else
        local backup="${ALIASES_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$ALIASES_FILE" "$backup"
        info "Backup: $backup"
    fi

    {
        echo ""
        echo "# marckv.dots Docker Aliases"
        echo "$LOAD_LINE"
    } >> "$ALIASES_FILE"

    success "Source line added to $ALIASES_FILE"
    info "Open a new shell, or: source $ALIASES_FILE"
}

do_uninstall() {
    bold "Removing docker aliases"
    echo

    if ! is_installed; then
        warn "Not installed — nothing to remove"
        return 0
    fi

    local backup="${ALIASES_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$ALIASES_FILE" "$backup"
    info "Backup: $backup"

    # The comment line above it goes too, so uninstalling twice leaves no litter.
    grep -vF "$MARKER" "$ALIASES_FILE" \
        | grep -vxF "# marckv.dots Docker Aliases" > "${ALIASES_FILE}.tmp"
    mv "${ALIASES_FILE}.tmp" "$ALIASES_FILE"

    success "Source line removed"
    info "The repo directory is untouched — reinstall with: $0 install"
}

case "${1:-install}" in
    install)       do_install ;;
    status)        do_status ;;
    uninstall)     do_uninstall ;;
    -h|--help|help) usage ;;
    *) error "Unknown command: $1"; echo; usage; exit 1 ;;
esac
