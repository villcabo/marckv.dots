#!/bin/bash
# Shared ground for every installer in this directory.
#
# It exists because there was none: colors, info/success/warn/error and
# SCRIPT_DIR were copy-pasted into eight scripts, which is why they drifted.
# Two helpers outside the numbered lifecycle had a preview and a -y flag; the
# five that the README says own that lifecycle had neither.
#
# Source it, then call installer_main:
#
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#     do_install()   { ... }
#     do_status()    { ... }
#     do_uninstall() { ... }
#     installer_main "$@"

# ---------------------------------------------------------------------------
# Colors
#
# Guarded, and the guard is not cosmetic. These used to be bare `$(tput …)`
# assignments and with `set -e` a tput that fails takes the script with it:
# with no $TERM, tput exits 2 and install-nvim.sh died before printing
# anything but "No value for $TERM". That is every non-interactive context —
# cron, CI, `docker exec -T`, `ssh host ./installer.sh`.
# ---------------------------------------------------------------------------
# Taken from install-bash-extensions-gradle-functions.sh, which had the most
# careful version of this in the repo while being the one script nobody counts
# as core. It honours NO_COLOR, stays plain when stdout is not a terminal, and
# asks how many colours the terminal actually has instead of assuming.
GREEN=""; BLUE=""; YELLOW=""; RED=""; DIM=""; BOLD=""; NC=""

_init_colors() {
    [[ -n "${NO_COLOR:-}" || ! -t 1 || "${TERM:-}" == "dumb" ]] && return 0
    if command -v tput >/dev/null 2>&1; then
        local ncolors
        ncolors="$(tput colors 2>/dev/null || echo 0)"
        if [[ "$ncolors" =~ ^[0-9]+$ ]] && (( ncolors >= 8 )); then
            GREEN="$(tput setaf 2)";  BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
            DIM="$(tput dim)";        BOLD="$(tput bold)"
            NC="$(tput sgr0)"
            return 0
        fi
    fi
    GREEN=$'\033[0;32m';  BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
    DIM=$'\033[2m';       BOLD=$'\033[1m'
    NC=$'\033[0m'
}
_init_colors

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }
die()     { error "$1"; exit 1; }

# ---------------------------------------------------------------------------
# Paths and privileges
# ---------------------------------------------------------------------------

# Resolved from the CALLER's location, not this file's: every installer sits in
# installer/ and expects MARCKV_DOTS_DIR to be the repo root.
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "${INSTALLER_DIR}/.." && pwd)"

if [[ $EUID -eq 0 ]]; then
    PRIV_MODE="root"
elif command -v sudo &>/dev/null; then
    PRIV_MODE="sudo"
else
    PRIV_MODE="user"
fi

# Run a command with whatever privilege this machine allows.
_run() {
    case "$PRIV_MODE" in
        root) "$@" ;;
        sudo) sudo "$@" ;;
        user)
            error "Cannot run: $*"
            info "No root or sudo. Run it yourself with: ${BOLD}sudo $*${NC}"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Preview and confirmation
#
# Borrowed from docker-aliases, which settled this already: show what is about
# to happen before it happens, and make the answer cost more than a reflex.
#
# One deliberate difference. There the preview goes to stderr, so a piped
# command's output stays clean. Here it goes to stdout, because an installer's
# output IS the record — `./01-install-bash.sh | tee install.log` should have
# the preview in the log, not swallow it.
# ---------------------------------------------------------------------------

ASSUME_YES=false

# preview_line <label> <value>  — one row of the preview block
preview_line() { printf "  ${DIM}%-14s${NC} %s\n" "$1" "$2"; }

# preview_open <action>  /  preview_close
preview_open() {
    echo
    bold "=== $1 ==="
    echo
}
preview_close() { echo; }

# confirm <question> — true to go ahead
#
# -y answers it. So does a non-interactive stdin: a script piped into bash, or
# a container step, has nobody to ask, and stopping there to wait forever is
# worse than the prompt it replaces.
confirm() {
    local question="${1:-Continue?}"
    [[ "$ASSUME_YES" == true ]] && return 0
    if [[ ! -t 0 ]]; then
        info "Not a terminal — assuming yes. Pass ${BOLD}-y${NC} to say so explicitly."
        return 0
    fi
    local reply
    printf "  ${YELLOW}${BOLD}%s${NC} [y/N] " "$question"
    read -r reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# confirm_destructive <question> — confirm, but a pipe is a NO
#
# The difference is the whole point. `confirm` assumes yes when stdin is not a
# terminal, which is right for putting a symlink in place: nobody is there to
# ask and the worst case is undone by `uninstall`. Deleting has no uninstall.
# `./clean-nvim-data.sh < /dev/null` must refuse, not wipe ~/.config/nvim.
# Saying yes unattended stays possible — it just has to be said, with -y.
#
# Returns 1 when the answer was no, 2 when there was nobody to ask. The caller
# has to tell those apart: "you declined" is a success for whoever chained on
# it, "I could not ask" is not, and collapsing both into 1 is how a caller ends
# up believing a delete happened.
confirm_destructive() {
    local question="${1:-Continue?}"
    [[ "$ASSUME_YES" == true ]] && return 0
    if [[ ! -t 0 ]]; then
        error "Nothing to ask on: stdin is not a terminal."
        info "Say it explicitly with ${BOLD}-y${NC} if you meant to delete unattended."
        return 2
    fi
    local reply
    printf "  ${YELLOW}${BOLD}%s${NC} [y/N] " "$question"
    read -r reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ---------------------------------------------------------------------------
# Entry point
#
# `install` is the default so that every script keeps working when called with
# no arguments, which is how the README documents them today.
# ---------------------------------------------------------------------------

INSTALLER_NAME="${INSTALLER_NAME:-$(basename "${BASH_SOURCE[1]:-installer}")}"
INSTALLER_ABOUT="${INSTALLER_ABOUT:-}"

installer_usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    [[ -n "$INSTALLER_ABOUT" ]] && { echo; echo -e "  ${INSTALLER_ABOUT}"; }
    echo
    echo -e "${BLUE}Usage:${NC} ./${INSTALLER_NAME} [install|status|uninstall] [-y]"
    echo
    echo -e "  ${YELLOW}install${NC}      Put it in place. The default when no command is given."
    echo -e "  ${YELLOW}status${NC}       Say whether it is installed, and where."
    echo -e "  ${YELLOW}uninstall${NC}    Undo what install did, and nothing else."
    echo
    echo -e "  ${YELLOW}-y, --yes${NC}    Skip the confirmation. Every command previews first."
    echo
}

# installer_flag <arg> — override to accept flags only one installer has
#
# Return 0 when the argument was consumed, 1 to let installer_main reject it.
# Without this the shared parser rejected every script's own options:
# --version= on atuin, --copy/--sync/--deps on nvim-lite, --ls-remote on the
# Neovim binary installer. Sharing the parser has to mean extending it, not
# flattening every script into the same three commands.
installer_flag() { return 1; }

# The three are expected to return 0 when they did what they say and non-zero
# when they did not — `status` in particular means "installed and working", not
# "the script ran". Watch the last line of each: a bare `[[ ... ]] && cmd` there
# returns the test's status, which is how a healthy atuin install reported rc=1
# on any machine that had no history directory yet.
installer_main() {
    local cmd=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            install|status|uninstall) cmd="$arg" ;;
            -y|--yes)                 ASSUME_YES=true ;;
            -h|--help|help)           installer_usage; exit 0 ;;
            *)
                installer_flag "$arg" && continue
                error "Unknown argument: $arg"; echo; installer_usage; exit 1
                ;;
        esac
    done

    case "${cmd:-install}" in
        install)   do_install ;;
        status)    do_status ;;
        uninstall) do_uninstall ;;
    esac
}
