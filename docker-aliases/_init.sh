#!/usr/bin/env bash
# Shared colors, styles, and utility functions for docker-aliases
#
# Configuration env vars:
#   DOCKER_COMPOSE_FILE       Override compose file (kept from Phase 1)
#   DOCKER_ALIASES_NERD_FONT  Set to 0 to force ASCII icons (default: 1 = use Nerd Font)
#   DOCKER_ALIASES_AUTO_YES   Set to 1 to skip all confirmation prompts (default: 0)
#   DOCKER_ALIASES_LOG_LINES  Default tail line count for dclt (default: 100)
#   DOCKER_ALIASES_CACHE_TTL  Completion cache TTL in seconds (default: 5)

# Color variables
CR="\033[0m"        # COLOR_RESET
CRE="\033[1;31m"    # COLOR_RED
CGR="\033[1;32m"    # COLOR_GREEN
CYE="\033[1;33m"    # COLOR_YELLOW
CBL="\033[1;34m"    # COLOR_BLUE
CMA="\033[1;35m"    # COLOR_MAGENTA
CCY="\033[1;36m"    # COLOR_CYAN
CWH="\033[1;37m"    # COLOR_WHITE

# Text styles
CB="\033[1m"        # BOLD
CI="\033[3m"        # ITALIC
CU="\033[4m"        # UNDERLINE

# Dim cyan for separators
CCY_DIM="\033[2;36m"

# ---------------------------------------------------------------------------
# Nerd Font detection
# ---------------------------------------------------------------------------

# Returns 0 if Nerd Font icons should be used
_use_nerd_font() {
    [[ "${DOCKER_ALIASES_NERD_FONT:-1}" == "0" ]] && return 1
    return 0
}

# Glyph helpers — return Nerd Font glyph or ASCII fallback.
# Usage: _icon docker   →  "" or "[docker]"
_icon() {
    if _use_nerd_font; then
        case "$1" in
            docker)   printf '' ;;   # nf-linux-docker
            file)     printf '' ;;   # nf-fa-file_text
            profile)  printf '' ;;   # nf-fa-tag
            services) printf '' ;;   # nf-fa-server
            flags)    printf '' ;;   # nf-fa-cog
            confirm)  printf '' ;;   # nf-fa-question_circle
            check)    printf '' ;;   # check
            cross)    printf '' ;;   # cross
            *)        printf '*' ;;
        esac
    else
        case "$1" in
            docker)   printf '[docker]' ;;
            file)     printf '[file]' ;;
            profile)  printf '[profile]' ;;
            services) printf '[svc]' ;;
            flags)    printf '[flags]' ;;
            confirm)  printf '[?]' ;;
            check)    printf 'OK' ;;
            cross)    printf 'X' ;;
            *)        printf '*' ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# Action color helper
# ---------------------------------------------------------------------------

# Returns the ANSI color escape for a given action name
_action_color() {
    case "$1" in
        up)           printf '%s' "$CGR" ;;   # green
        down)         printf '%s' "$CRE" ;;   # red
        build)        printf '%s' "$CCY" ;;   # cyan
        prune)        printf '%s' "$CYE" ;;   # yellow
        watch)        printf '%s' "$CMA" ;;   # magenta
        "swarm rm"|scale) printf '%s' "$CBL" ;;  # blue
        *)            printf '%s' "$CWH" ;;
    esac
}

# ---------------------------------------------------------------------------
# Preview renderer
# ---------------------------------------------------------------------------

# _render_preview action file_list services_list flags_list
#
# Renders the minimalist preview block:
#   <icon> <action title>          (colored per action)
#   <icon> <file>                  (one line per file)
#   <icon> <svc1>  <svc2>  ...     (space-separated)
#   <icon> <flag1>  <flag2>  ...   (only if flags non-empty)
#  ─
#
# Arguments:
#   $1  action name (e.g. "compose up")
#   $2  space-separated compose files (may be empty)
#   $3  space-separated services      (may be empty)
#   $4  space-separated flags         (may be empty)
_render_preview() {
    local action="${1:-}"
    local files="${2:-}"
    local services="${3:-}"
    local flags="${4:-}"

    local action_color
    action_color=$(_action_color "${action##* }")   # use last word for lookup (e.g. "up" from "compose up")

    # Line 1: action
    printf "  %s ${action_color}${CB}%s${CR}\n" "$(_icon docker)" "$action"

    # Line 2+: compose file(s)
    if [[ -n "$files" ]]; then
        for f in $files; do
            printf "  %s %s\n" "$(_icon file)" "$f"
        done
    fi

    # Line 3: services (only if non-empty)
    if [[ -n "$services" ]]; then
        printf "  %s %s\n" "$(_icon services)" "$services"
    fi

    # Line 4: flags (only if non-empty)
    if [[ -n "$flags" ]]; then
        printf "  %s %s\n" "$(_icon flags)" "$flags"
    fi

    # Separator
    printf "${CCY_DIM}─${CR}\n"
}

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------

# _confirm_operation [message] [action_color]
# Returns 0 (yes) or 1 (no/cancel).
# Honors DOCKER_ALIASES_AUTO_YES=1 → immediate yes.
# Default response on plain Enter is NO.
_confirm_operation() {
    local message="${1:-Continue?}"
    local color="${2:-$CB}"

    # Auto-yes env var
    if [[ "${DOCKER_ALIASES_AUTO_YES:-0}" == "1" ]]; then
        return 0
    fi

    printf "  %s ${color}${CB}%s [y/N] ${CR}" "$(_icon confirm)" "$message"
    local response
    read -r response
    [[ "$response" == "y" || "$response" == "Y" ]]
}

# ---------------------------------------------------------------------------
# Compose file detection
# Priority: $DOCKER_COMPOSE_FILE env var > .env setting > docker-compose.yml > docker-compose.yaml
# ---------------------------------------------------------------------------
_get_compose_file() {
    if [[ -n "$DOCKER_COMPOSE_FILE" && -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "$DOCKER_COMPOSE_FILE"
        return 0
    fi

    if [[ -f ".env" ]] && grep -q "^DOCKER_COMPOSE_FILE=" .env; then
        local env_file
        env_file=$(grep "^DOCKER_COMPOSE_FILE=" .env | cut -d'=' -f2)
        if [[ -f "$env_file" ]]; then
            echo "$env_file"
            return 0
        fi
    fi

    if [[ -f docker-compose.yml ]]; then
        echo "docker-compose.yml"
        return 0
    elif [[ -f docker-compose.yaml ]]; then
        echo "docker-compose.yaml"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Completion helpers — shared between bash and zsh completion modules
# ---------------------------------------------------------------------------
_get_docker_containers() {
    docker ps --format "{{.Names}}" 2>/dev/null
}

_get_compose_services() {
    local compose_file
    compose_file=$(_get_compose_file)
    if [[ $? -eq 0 ]]; then
        docker compose -f "$compose_file" config --services 2>/dev/null
    fi
}

_get_compose_profiles() {
    local compose_file
    compose_file=$(_get_compose_file) || return 1
    docker compose -f "$compose_file" config --profiles 2>/dev/null | sort -u
}

# ---------------------------------------------------------------------------
# Swarm completion helpers
# Return empty (graceful) when not in a swarm — completions degrade silently.
# ---------------------------------------------------------------------------
_get_swarm_stacks() {
    docker stack ls --format '{{.Name}}' 2>/dev/null
}

_get_swarm_services() {
    docker service ls --format '{{.Name}}' 2>/dev/null
}

_get_swarm_nodes() {
    docker node ls --format '{{.Hostname}}' 2>/dev/null
}
