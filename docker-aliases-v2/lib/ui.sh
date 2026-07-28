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
#
# Codepoints are written as \u escapes, never as literal glyphs. Nerd Font
# icons live in the Unicode Private Use Area, and PUA characters do not survive
# every editor, transfer or encoding step — the first version of this file
# reached disk with every glyph silently replaced by an empty string, so every
# icon rendered as a blank space and nobody could tell the difference between
# "no icon" and "icon that failed". An escape sequence is plain ASCII and
# cannot be lost that way.
_icon() {
    if _use_nerd_font; then
        case "$1" in
            docker)   printf '' ;;   # nf-linux-docker
            file)     printf '' ;;   # nf-fa-file_text
            env)      printf '' ;;   # nf-fa-sliders
            profile)  printf '' ;;   # nf-fa-tag
            services) printf '' ;;   # nf-fa-server
            flags)    printf '' ;;   # nf-fa-cog
            cmd)      printf '' ;;   # nf-fa-terminal
            dir)      printf '' ;;   # nf-fa-folder
            volumes)  printf '' ;;   # nf-fa-trash
            warn)     printf '' ;;   # nf-fa-exclamation_triangle
            confirm)  printf '' ;;   # nf-fa-question_circle
            check)    printf '' ;;   # nf-fa-check
            cross)    printf '' ;;   # nf-fa-times
            health|health_bad|health_wait)
                      printf '' ;;   # nf-fa-heartbeat
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
            health)      printf '+' ;;
            health_bad)  printf '!' ;;
            health_wait) printf '~' ;;
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

# _short_duration <docker relative time> → 2-4 characters
#
# Docker writes "3 weeks ago", "About an hour ago", "20 minutes ago". As a
# column that is 11-18 characters of mostly English. As "3w", "1h", "20m" it is
# three, and reads just as fast.
#
# Note minutes and months both start with m: minutes become m, months mo.
_short_duration() {
    local t="$1"
    [[ -z "$t" ]] && { printf '—'; return 0; }

    t="${t% ago}"
    # Docker hedges with "About a minute" / "About an hour" / "About a year".
    t="${t#About }"
    t="${t#an }"
    t="${t#a }"

    local n="${t%% *}" unit="${t#* }"
    case "$n" in
        ''|*[!0-9]*) n=1 ;;      # what was "a minute" is one of them
    esac

    case "$unit" in
        second*)  printf '%ss'  "$n" ;;
        minute*)  printf '%sm'  "$n" ;;
        hour*)    printf '%sh'  "$n" ;;
        day*)     printf '%sd'  "$n" ;;
        week*)    printf '%sw'  "$n" ;;
        month*)   printf '%smo' "$n" ;;
        year*)    printf '%sy'  "$n" ;;
        *)        printf '%s'   "$1" ;;
    esac
}

# _short_status <docker status> → the same meaning, a third of the width
#
# "Up 4 hours (healthy)" is twenty characters to say two things. Health becomes
# a glyph; the duration is shortened the same way as everywhere else.
#
# Exit codes are KEPT. "Exited (137)" is an out-of-memory kill and "Exited (0)"
# is a clean stop — collapsing both to "Exited" throws away the only part that
# tells you which of those happened.
_short_status() {
    local s="$1" mark="" rest

    # One glyph for all three states — the COLOUR says which. That is why the
    # ASCII fallback does not follow suit: it is the degraded path, and whoever
    # lost the font may well have lost the colour too, so there it stays
    # explicit (+ ! ~).
    case "$s" in
        *"(healthy)"*)   mark=" $(_icon health)" ;;
        *"(unhealthy)"*) mark=" $(_icon health_bad)" ;;
        *"(starting)"*)  mark=" $(_icon health_wait)" ;;
    esac

    case "$s" in
        Up*)
            rest="${s#Up }"
            # The literal parts are quoted: in zsh an unquoted "(" inside an
            # expansion pattern opens a glob group, and "%% (*" is then an
            # unterminated one. bash reads the same paren as an ordinary
            # character, so this only ever breaks on one of the two shells.
            rest="${rest%%" ("*}"
            printf 'Up %s%s' "$(_short_duration "$rest")" "$mark"
            ;;
        Exited*)
            # Exited (137) 3 minutes ago
            rest="${s#"Exited ("}"
            local code="${rest%%")"*}"
            local when="${rest#*") "}"
            printf 'Exit %s · %s' "$code" "$(_short_duration "$when")"
            ;;
        Restarting*)
            rest="${s#"Restarting ("}"
            local rcode="${rest%%")"*}"
            local rwhen="${rest#*") "}"
            printf 'Restart %s · %s' "$rcode" "$(_short_duration "$rwhen")"
            ;;
        *) printf '%s' "$s" ;;
    esac
}

# _short_timestamp <docker CreatedAt> → yyyy-mm-dd hh:mm
#
# Docker appends the offset twice — "2026-07-22 23:08:56 -0400 -04". Seconds
# and both copies of the zone are dropped.
_short_timestamp() {
    local t="$1"
    [[ -z "$t" ]] && { printf '—'; return 0; }
    printf '%s' "${t:0:16}"
}

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

# _color_named <name> <cell> → the escape a named colour resolves to
#
# "@status" defers to _status_color so the cell decides its own colour.
_color_named() {
    case "$1" in
        dim)    printf '%s' "$CDIM" ;;
        cyan)   printf '%s' "$CCY" ;;
        green)  printf '%s' "$CGR" ;;
        yellow) printf '%s' "$CYE" ;;
        blue)   printf '%s' "$CBL" ;;
        magenta) printf '%s' "$CMA" ;;
        red)    printf '%s' "$CRE" ;;
        white)  printf '%s' "$CWH" ;;
        @status) _status_color "$2" ;;
        *)      printf '%s' "$CWH" ;;
    esac
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
    local h1="$5" h2="$6" h3="$7" h4="$8" h5="$9" h6="${10}"
    local rows="${11}"
    # Per-column colours, comma separated. "@status" means run the cell through
    # _status_color. Defaults to what dps/dcps want; dcver overrides it, because
    # the same table shape can carry columns that mean quite different things.
    local colors="${12:-dim,cyan,dim,@status,green,white}"

    local _c1 _c2 _c3 _c4 _c5 _c6 _ci=0 _cname
    while IFS= read -r _cname; do
        _ci=$(( _ci + 1 ))
        case "$_ci" in
            1) _c1="$_cname" ;; 2) _c2="$_cname" ;; 3) _c3="$_cname" ;;
            4) _c4="$_cname" ;; 5) _c5="$_cname" ;; 6) _c6="$_cname" ;;
        esac
    done <<< "$(_split_commas "$colors")"

    # Nothing is capped any more. The column order follows `docker ps`, which
    # puts the name LAST — and a last column needs no padding, so it can run as
    # long as it likes without pushing anything out of line. The image is left
    # whole on purpose: a tag is what tells you WHICH build is running, and
    # "…support:v1.0.0" does not.

    local c1 c2 c3 c4 c5 c6
    local w1=${#h1} w2=${#h2} w3=${#h3} w4=${#h4} w5=${#h5}

    if [[ -n "$rows" ]]; then
        while IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 || [[ -n "$c1" ]]; do
            [[ -z "$c1" ]] && continue
            (( ${#c1} > w1 )) && w1=${#c1}
            (( ${#c2} > w2 )) && w2=${#c2}
            (( ${#c3} > w3 )) && w3=${#c3}
            (( ${#c4} > w4 )) && w4=${#c4}
            (( ${#c5} > w5 )) && w5=${#c5}
        done <<< "$rows"
    fi

    # Scope line instead of a preview block: for a command whose whole output is
    # a table, a preview would just say everything twice.
    printf "  %s ${CBL}${CB}%s${CR}  ${CDIM}·${CR}  ${CDIM}%s of %s${CR}" \
        "$(_icon docker)" "$title" "$shown" "$total"
    [[ -n "$filter" ]] && printf "  ${CDIM}·${CR}  ${CDIM}filter:${CR} ${CMA}%s${CR}" "$filter"
    printf "\n"

    printf "  ${CDIM}%s  %s  %s  %s  %s  %s${CR}\n" \
        "$(_pad_to "$h1" "$w1")" "$(_pad_to "$h2" "$w2")" "$(_pad_to "$h3" "$w3")" \
        "$(_pad_to "$h4" "$w4")" "$(_pad_to "$h5" "$w5")" "$h6"

    if [[ -z "$rows" ]]; then
        printf "  ${CDIM}(nothing to show)${CR}\n"
        return 0
    fi

    local k1 k2 k3 k4 k5 k6
    while IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 || [[ -n "$c1" ]]; do
        [[ -z "$c1" ]] && continue
        k1=$(_color_named "$_c1" "$c1"); k2=$(_color_named "$_c2" "$c2")
        k3=$(_color_named "$_c3" "$c3"); k4=$(_color_named "$_c4" "$c4")
        k5=$(_color_named "$_c5" "$c5"); k6=$(_color_named "$_c6" "$c6")
        printf "  ${k1}%s${CR}  ${k2}%s${CR}  ${k3}%s${CR}  ${k4}%s${CR}  ${k5}%s${CR}  ${k6}%s${CR}\n" \
            "$(_pad_to "$c1" "$w1")" "$(_pad_to "$c2" "$w2")" \
            "$(_pad_to "$c3" "$w3")" "$(_pad_to "$c4" "$w4")" \
            "$(_pad_to "$c5" "$w5")" "$c6"
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
