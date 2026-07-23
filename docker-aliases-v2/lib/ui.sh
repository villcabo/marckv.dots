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
            dir)      printf '' ;;   # nf-fa-folder
            volumes)  printf '' ;;   # nf-fa-trash
            warn)     printf '' ;;   # nf-fa-exclamation_triangle
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
            dir)      printf '[dir]' ;;
            volumes)  printf '[vol]' ;;
            warn)     printf '[!]' ;;
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
#   $6  volumes           space-separated named volumes about to be DESTROYED
#                         (may be empty). Rendered in red — this is the only
#                         irreversible thing any of these commands can do, so
#                         it gets its own line and its own color.
#
# The command line is not a reconstruction: callers build one command, execute
# that exact command, and pass a colored rendering of it here. What you read is
# what runs.
#
# Everything here goes to stderr. The preview is UI, not data — a command whose
# output you pipe (`dclt -o api | grep error`) must not have its preview land
# in the pipe.
# ---------------------------------------------------------------------------

_render_preview() {
    local action="${1:-}"
    local files="${2:-}"
    local services="${3:-}"
    local flags="${4:-}"
    local command_display="${5:-}"
    local volumes="${6:-}"

    local action_color
    action_color=$(_action_color "${action##* }")   # "up" from "compose up"

    {
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
        [[ -n "$volumes" ]]  && printf "  %s ${CRE}${CB}%s${CR}  ${CRE}← deleted, cannot be undone${CR}\n" \
                                      "$(_icon volumes)" "$volumes"
        [[ -n "$flags" ]]    && printf "  %s ${CYE}%s${CR}\n" "$(_icon flags)" "$flags"
        [[ -n "$command_display" ]] && printf "  %s %b${CR}\n" "$(_icon cmd)" "$command_display"

        _hr
    } >&2
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

    printf "  %s ${color}${CB}%s${CR} ${CDIM}[yes/N]${CR} " "$(_icon confirm)" "$message" >&2
    local response
    read -r response
    [[ "$response" == "yes" || "$response" == "YES" || "$response" == "Yes" ]]
}

# ---------------------------------------------------------------------------
# Port compaction
#
# `docker ps` renders ports at their most verbose, and it is what pushes the
# row past the width of a terminal:
#
#   8080/tcp, 8443/tcp, 0.0.0.0:9080->9080/tcp, 9000/tcp, 0.0.0.0:9443->9443/tcp
#
# Three kinds of noise live in there:
#
#   1. The same mapping listed once per address family — 0.0.0.0:3001->3000/tcp
#      and [::]:3001->3000/tcp are one port, printed twice.
#   2. Ports that are merely EXPOSEd, never published. 5432/tcp with no arrow
#      cannot be reached from the host at all, so it does not answer the
#      question you are asking when you run ps.
#   3. host->container pairs that are identical. 9080->9080 is just 9080.
#
# Stripping those turns the line above into "9080 9443" — 76 characters to 9.
# ---------------------------------------------------------------------------

# _compact_ports <ports string> [show_exposed]
_compact_ports() {
    local raw="$1"
    local show_exposed="${2:-false}"

    [[ -z "$raw" ]] && return 0

    local out="" entry hostpart container proto cport hport hip label

    while IFS= read -r entry || [[ -n "$entry" ]]; do
        entry="${entry# }"
        [[ -z "$entry" ]] && continue

        if [[ "$entry" != *"->"* ]]; then
            # Exposed only. Marked with ~ when asked for, so it never reads as
            # something you can connect to.
            [[ "$show_exposed" != true ]] && continue
            cport="${entry%%/*}"
            proto="${entry##*/}"
            label="~${cport}"
            [[ "$proto" != "tcp" ]] && label="${label}/${proto}"
        else
            hostpart="${entry%%->*}"
            container="${entry#*->}"
            proto="${container##*/}"
            cport="${container%%/*}"
            hport="${hostpart##*:}"
            hip="${hostpart%:*}"

            label="$hport"
            [[ "$hport" != "$cport" ]] && label="${hport}→${cport}"
            [[ "$proto" != "tcp" ]] && label="${label}/${proto}"
            # A localhost binding is NOT reachable from elsewhere, which is
            # worth seeing rather than inferring.
            case "$hip" in
                127.0.0.1|localhost) label="lo:${label}" ;;
            esac
        fi

        # Deduplicate on the rendered label. This collapses the v4/v6 pair
        # without assuming v4 is present — a port published only on IPv6 still
        # shows up exactly once.
        case " $out " in
            *" $label "*) continue ;;
        esac
        out+="${out:+ }${label}"
    done <<< "$(printf '%s\n' "$raw" | tr ',' '\n')"

    printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Table helpers
#
# Padding is computed on the PLAIN text and the color is wrapped around the
# result. Doing it the other way round makes printf count the escape sequences
# as if they were characters, and every column drifts.
# ---------------------------------------------------------------------------

# _ellipsize <text> <max> → text, shortened from the middle if it must be
#
# Middle rather than end, because container names are usually
# <project>-<service>-<n> and both ends carry meaning — cutting the tail throws
# away exactly the part that distinguishes one container from its siblings.
#
# Shortening is deliberately VISIBLE. Stripping the redundant project prefix
# would read better, but it would produce a name that looks real and is not —
# paste it into `docker exec` and it fails. An ellipsis cannot be mistaken for
# a name.
_ellipsize() {
    local text="$1" max="$2"
    local len=${#1}

    (( len <= max )) && { printf '%s' "$text"; return 0; }
    (( max < 5 )) && { printf '%s' "${text:0:$max}"; return 0; }

    local head=$(( (max - 1) / 2 ))
    local tail=$(( max - 1 - head ))
    printf '%s…%s' "${text:0:$head}" "${text:$(( len - tail ))}"
}

# _pad_to <text> <width> → text followed by spaces up to width
_pad_to() {
    local text="$1" width="$2"
    local len=${#1}
    printf '%s' "$text"
    while (( len < width )); do
        printf ' '
        len=$(( len + 1 ))
    done
}

# _status_color <status text> → the color that status deserves
#
# Health is read out of the status string rather than left buried in it: a
# container that is up but unhealthy looks exactly like a healthy one otherwise.
_status_color() {
    case "$1" in
        *"(unhealthy)"*) printf '%s' "$CRE" ;;
        *"(starting)"*)  printf '%s' "$CYE" ;;
        *"(healthy)"*)   printf '%s' "$CGR" ;;
        Up*|up*|running*) printf '%s' "$CGR" ;;
        Restarting*|restarting*|Paused*|paused*) printf '%s' "$CYE" ;;
        *) printf '%s' "$CRE" ;;
    esac
}

# ---------------------------------------------------------------------------
# Container table
#
# _render_container_table <title> <shown> <total> <filter> \
#                         <head1> <head2> <head3> <head4> <rows>
#
# `rows` is newline-separated, each line four TAB-separated fields. Rows travel
# as text rather than as arrays because passing arrays by name needs indirect
# expansion, and that is spelled ${!v[@]} in bash and ${(P)v} in zsh — one of
# the few things with no portable form.
#
# Widths are measured in a first pass so the last row lines up with the first.
# ---------------------------------------------------------------------------

_render_container_table() {
    local title="$1" shown="$2" total="$3" filter="$4"
    local h1="$5" h2="$6" h3="$7" h4="$8"
    local rows="$9"

    # Caps, so one pathological name cannot stretch the table past the screen —
    # which is the very thing compacting the ports was meant to fix. Columns
    # still shrink below these when the content is short.
    local cap1=32 cap2=22 cap3=22

    local c1 c2 c3 c4
    local w1=${#h1} w2=${#h2} w3=${#h3}

    if [[ -n "$rows" ]]; then
        while IFS=$'\t' read -r c1 c2 c3 c4 || [[ -n "$c1" ]]; do
            [[ -z "$c1" ]] && continue
            (( ${#c1} > w1 )) && w1=${#c1}
            (( ${#c2} > w2 )) && w2=${#c2}
            (( ${#c3} > w3 )) && w3=${#c3}
        done <<< "$rows"
        (( w1 > cap1 )) && w1=$cap1
        (( w2 > cap2 )) && w2=$cap2
        (( w3 > cap3 )) && w3=$cap3
    fi

    # Scope line instead of a preview block: for a command whose whole output is
    # a table, a preview would just say everything twice.
    printf "  %s ${CBL}${CB}%s${CR}  ${CDIM}·${CR}  ${CDIM}%s of %s${CR}" \
        "$(_icon docker)" "$title" "$shown" "$total"
    [[ -n "$filter" ]] && printf "  ${CDIM}·${CR}  ${CDIM}filter:${CR} ${CMA}%s${CR}" "$filter"
    printf "\n"

    printf "  ${CDIM}%s  %s  %s  %s${CR}\n" \
        "$(_pad_to "$h1" "$w1")" "$(_pad_to "$h2" "$w2")" \
        "$(_pad_to "$h3" "$w3")" "$h4"

    if [[ -z "$rows" ]]; then
        printf "  ${CDIM}(nothing to show)${CR}\n"
        return 0
    fi

    local scolor
    while IFS=$'\t' read -r c1 c2 c3 c4 || [[ -n "$c1" ]]; do
        [[ -z "$c1" ]] && continue
        scolor=$(_status_color "$c3")
        printf "  ${CWH}%s${CR}  ${CDIM}%s${CR}  ${scolor}%s${CR}  ${CGR}%s${CR}\n" \
            "$(_pad_to "$(_ellipsize "$c1" "$w1")" "$w1")" \
            "$(_pad_to "$(_ellipsize "$c2" "$w2")" "$w2")" \
            "$(_pad_to "$(_ellipsize "$c3" "$w3")" "$w3")" "$c4"
    done <<< "$rows"
}

# ---------------------------------------------------------------------------
# Typed confirmation
#
# For operations that destroy data, "yes" is the wrong prompt — not because it
# is too short, but because it is the SAME answer every other prompt takes. Type
# it often enough and you stop reading the question.
#
# Demanding a different, situation-specific token (the project name) breaks that
# reflex: you cannot answer without looking at what you are about to destroy.
# ---------------------------------------------------------------------------

# _confirm_typed <expected> <warning message> [color]
_confirm_typed() {
    local expected="$1"
    local message="$2"
    local color="${3:-$CRE}"

    # TEST/CI ONLY escape, same as _confirm_operation.
    if [[ "${DOCKER_ALIASES_AUTO_YES:-0}" == "1" ]]; then
        return 0
    fi

    printf "  %s ${color}${CB}%s${CR}\n" "$(_icon warn)" "$message" >&2
    printf "  %s ${color}${CB}[%s]${CR}${CDIM}:${CR} " "$(_icon confirm)" "$expected" >&2

    local response
    read -r response
    [[ "$response" == "$expected" ]]
}

# ---------------------------------------------------------------------------
# Notices
# ---------------------------------------------------------------------------

# _note <message> — a neutral heads-up that is not an error
_note() {
    printf "  %s ${CDIM}%s${CR}\n" "$(_icon warn)" "$1" >&2
}

# ---------------------------------------------------------------------------
# Error reporting
# ---------------------------------------------------------------------------

# _err <command> <message>
_err() {
    printf "  ${CRE}${CB}%s${CR} ${CRE}%s${CR}\n" "$1:" "$2" >&2
}
