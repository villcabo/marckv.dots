#!/usr/bin/env bash
# docker-aliases v2 — presentation layer.
#
# Owns every byte the user sees: colors, icons, the preview block and the
# confirmation prompt. Commands build data; this file renders it.
#
# Configuration env vars:
#   DOCKER_ALIASES_NERD_FONT  Set to 0 to force ASCII icons (default: 1)
#   DOCKER_ALIASES_AUTO_YES   Set to 1 to bypass the confirmation prompt.
#                             TEST/CI ONLY — there is deliberately no CLI flag
#                             for this, because every v2 command that mutates
#                             state must be confirmed by a human.

# ---------------------------------------------------------------------------
# Colors and styles
# ---------------------------------------------------------------------------

CR="\033[0m"        # reset
CRE="\033[1;31m"    # red
CGR="\033[1;32m"    # green
CYE="\033[1;33m"    # yellow
CBL="\033[1;34m"    # blue
CMA="\033[1;35m"    # magenta
CCY="\033[1;36m"    # cyan
CWH="\033[1;37m"    # white

CB="\033[1m"        # bold
CI="\033[3m"        # italic
CU="\033[4m"        # underline
CDIM="\033[2m"      # dim
CCY_DIM="\033[2;36m"

# ---------------------------------------------------------------------------
# Icons — Nerd Font glyphs with an ASCII fallback
# ---------------------------------------------------------------------------

_use_nerd_font() {
    [[ "${DOCKER_ALIASES_NERD_FONT:-1}" == "0" ]] && return 1
    return 0
}

# _icon <name> → glyph on stdout
_icon() {
    if _use_nerd_font; then
        case "$1" in
            docker)   printf '' ;;   # nf-linux-docker
            file)     printf '' ;;   # nf-fa-file_text
            env)      printf '' ;;   # nf-fa-sliders
            profile)  printf '' ;;   # nf-fa-tag
            services) printf '' ;;   # nf-fa-server
            flags)    printf '' ;;   # nf-fa-cog
            cmd)      printf '' ;;   # nf-fa-terminal
            confirm)  printf '' ;;   # nf-fa-question_circle
            check)    printf '' ;;
            cross)    printf '' ;;
            *)        printf '*' ;;
        esac
    else
        case "$1" in
            docker)   printf '[docker]' ;;
            file)     printf '[file]' ;;
            env)      printf '[env]' ;;
            profile)  printf '[prof]' ;;
            services) printf '[svc]' ;;
            flags)    printf '[flags]' ;;
            cmd)      printf '$' ;;
            confirm)  printf '[?]' ;;
            check)    printf 'OK' ;;
            cross)    printf 'X' ;;
            *)        printf '*' ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# Action color — one color per verb, so a destructive action never looks
# like a harmless one.
# ---------------------------------------------------------------------------

_action_color() {
    case "$1" in
        up|start)      printf '%s' "$CGR" ;;   # green  — creates
        down|rm|prune) printf '%s' "$CRE" ;;   # red    — destroys
        restart)       printf '%s' "$CYE" ;;   # yellow — interrupts
        build)         printf '%s' "$CCY" ;;   # cyan   — produces
        logs|ps)       printf '%s' "$CBL" ;;   # blue   — reads
        *)             printf '%s' "$CWH" ;;
    esac
}

# ---------------------------------------------------------------------------
# Horizontal rule — adapts to terminal width, capped so it never wraps.
# ---------------------------------------------------------------------------

_hr() {
    # COLUMNS is unset or 0 in a non-interactive shell — fall back rather than
    # clamping down to a stub of a line.
    local width="${COLUMNS:-0}"
    case "$width" in
        ''|*[!0-9]*) width=0 ;;
    esac
    (( width <= 0 )) && width=80
    (( width > 74 )) && width=74
    (( width < 20 )) && width=20

    local line="" i=0
    while (( i < width )); do
        line+="─"
        i=$(( i + 1 ))
    done
    printf "${CCY_DIM}%s${CR}\n" "$line"
}

# ---------------------------------------------------------------------------
# Preview renderer
#
# Renders the block the user reads before confirming:
#
#    compose up
#    docker-compose.yml
#    api  worker  db
#    --force-recreate --pull always
#   $  docker compose -f docker-compose.yml up -d --force-recreate api worker
#   ──────────────────────────────────────────────
#
# Arguments:
#   $1  action title      e.g. "compose up"
#   $2  compose files     NEWLINE-separated, one per line (may be empty)
#   $3  services          space-separated (may be empty)
#   $4  flags             space-separated (may be empty)
#   $5  command to run    PRE-COLORED string — the caller owns its colors,
#                         because only the caller knows which token is a file,
#                         a flag or a service.
#
# The command line is not a reconstruction: callers build one command, execute
# that exact command, and pass a colored rendering of it here. What you read is
# what runs.
# ---------------------------------------------------------------------------

_render_preview() {
    local action="${1:-}"
    local files="${2:-}"
    local services="${3:-}"
    local flags="${4:-}"
    local command_display="${5:-}"

    local action_color
    action_color=$(_action_color "${action##* }")   # "up" from "compose up"

    printf "  %s ${action_color}${CB}%s${CR}\n" "$(_icon docker)" "$action"

    # Read line by line instead of relying on word splitting: zsh does not
    # split unquoted parameters the way bash does, and this also survives
    # paths containing spaces.
    if [[ -n "$files" ]]; then
        local f
        while IFS= read -r f; do
            [[ -n "$f" ]] && printf "  %s ${CWH}%s${CR}\n" "$(_icon file)" "$f"
        done <<< "$files"
    fi

    [[ -n "$services" ]] && printf "  %s ${CMA}%s${CR}\n" "$(_icon services)" "$services"
    [[ -n "$flags" ]]    && printf "  %s ${CYE}%s${CR}\n" "$(_icon flags)" "$flags"
    [[ -n "$command_display" ]] && printf "  %s %b${CR}\n" "$(_icon cmd)" "$command_display"

    _hr
}

# ---------------------------------------------------------------------------
# Confirmation
#
# Always asks. Always requires the full word "yes" — a stray "y" is not enough,
# because these commands recreate and restart running services.
# Plain Enter cancels.
# ---------------------------------------------------------------------------

_confirm_operation() {
    local message="${1:-Continue?}"
    local color="${2:-$CB}"

    # TEST/CI ONLY escape. No CLI flag maps to this on purpose.
    if [[ "${DOCKER_ALIASES_AUTO_YES:-0}" == "1" ]]; then
        return 0
    fi

    printf "  %s ${color}${CB}%s${CR} ${CDIM}[yes/N]${CR} " "$(_icon confirm)" "$message"
    local response
    read -r response
    [[ "$response" == "yes" || "$response" == "YES" || "$response" == "Yes" ]]
}

# ---------------------------------------------------------------------------
# Error reporting
# ---------------------------------------------------------------------------

# _err <command> <message>
_err() {
    printf "  ${CRE}${CB}%s${CR} ${CRE}%s${CR}\n" "$1:" "$2" >&2
}
