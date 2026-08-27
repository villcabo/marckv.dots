#!/usr/bin/env bash
# docker-aliases — dlt: tail container logs, host-wide.
#
# dclt's counterpart outside a compose project, the way dps is dcps's and dver
# is dcver's: same flags, same regex matching, no compose file anywhere.
#
# Design contract:
#   * One docker logs per container, because that is all `docker logs` takes.
#     `docker compose logs` accepts many services and interleaves them itself;
#     the plain client does not, so dlt does that part.
#   * A single match streams RAW. No prefix, no wrapper process, docker's own
#     exit code — because with one container a prefix is noise on every line.
#   * Several matches are prefixed with the container name, coloured and padded
#     into a column, which is the only thing that makes interleaved output
#     readable.
#   * Reading logs changes nothing, so there is a preview and no confirmation.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dlt_help() {
    printf "${CB}${CCY}dlt${CR} — tail container logs, host-wide\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dlt${CR} [${CYE}flags${CR}] [${CMA}lines${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-n${CR} ${CMA}<N|all>${CR}         Lines to tail ${CI}(default 100)${CR}\n"
    printf "  ${CYE}-s${CR} ${CMA}<time>${CR}          Only logs since then ${CI}(10m, 1h, a timestamp)${CR}\n"
    printf "  ${CYE}-o${CR}                 Once: dump and exit instead of following\n"
    printf "  ${CYE}-t${CR}                 Prefix every line with its timestamp\n"
    printf "  ${CYE}-a${CR}                 Match stopped containers too\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-ot${CR} ${CI}is the same as${CR} ${CGR}-o -t${CR}\n"
    printf "  ${CI}A bare number is the line count:${CR} ${CGR}dlt 500 api${CR} ${CI}=${CR} ${CGR}dlt -n 500 api${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against container names,\n"
    printf "  as in ${CB}dps${CR} and ${CB}dver${CR}. With no pattern, every container is followed.\n\n"

    printf "${CCY}ONE CONTAINER vs SEVERAL${CR}\n"
    printf "  ${CB}docker logs${CR} takes exactly one container, so matching several means\n"
    printf "  running one per container and interleaving them here.\n\n"
    printf "  A ${CB}single${CR} match streams straight through — no prefix, no wrapper.\n"
    printf "  ${CB}Several${CR} get the container name in front of every line, so you can\n"
    printf "  tell which is which.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dlt${CR}                              Follow every running container\n"
    printf "  ${CGR}dlt api${CR}                          Anything matching 'api'\n"
    printf "  ${CGR}dlt 'api|db'${CR}                     Two patterns at once\n"
    printf "  ${CGR}dlt '^redmine\$'${CR}                  Exactly the container named 'redmine'\n"
    printf "  ${CGR}dlt 500 api${CR}                      Last 500 lines, then follow\n"
    printf "  ${CGR}dlt -n all api${CR}                   The whole log, then follow\n"
    printf "  ${CGR}dlt -s 10m${CR}                       Only the last 10 minutes\n"
    printf "  ${CGR}dlt -oa api${CR}                      Stopped ones too, dump and exit\n"
    printf "  ${CGR}dlt -o api | grep -i error${CR}       Pipe it — the preview stays on stderr\n\n"

    printf "${CCY}RELATED${CR}\n"
    printf "  ${CB}dclt${CR} is the same command inside a compose project, where it can ask\n"
    printf "  compose for the service list and let compose do the interleaving.\n"
}

# _dlt_color <n> → one of six colours, cycled
#
# Picked by a case rather than indexing a palette array: bash counts from 0 and
# zsh from 1, and there is no spelling of "the nth element" that means the same
# thing in both.
_dlt_color() {
    case $(( $1 % 6 )) in
        0) printf '%s' "$CCY" ;;
        1) printf '%s' "$CGR" ;;
        2) printf '%s' "$CYE" ;;
        3) printf '%s' "$CMA" ;;
        4) printf '%s' "$CBL" ;;
        *) printf '%s' "$CWH" ;;
    esac
}

# ---------------------------------------------------------------------------
# dlt
# ---------------------------------------------------------------------------

dlt() {
    case "$1" in
        -h|--help) _dlt_help; return 0 ;;
    esac

    # --- expand clustered short flags: -ot → -o -t --------------------------
    local expanded=() arg rest char i
    for arg in "$@"; do
        if [[ "$arg" == --* ]]; then
            expanded+=("$arg")
        elif [[ "$arg" == -?* ]]; then
            rest="${arg#-}"
            i=0
            while (( i < ${#rest} )); do
                char="${rest:$i:1}"
                expanded+=("-$char")
                i=$(( i + 1 ))
            done
        else
            expanded+=("$arg")
        fi
    done

    # --- parse --------------------------------------------------------------
    local tail_lines="${DOCKER_ALIASES_LOG_LINES:-100}"
    local since="" follow=true timestamps=false all=false
    local patterns=()

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dlt_help; return 0 ;;
            -o) follow=false ;;
            -t) timestamps=true ;;
            -a) all=true ;;
            -n)
                shift
                [[ $# -eq 0 ]] && { _err dlt "-n requires a line count or 'all'"; return 1; }
                tail_lines="$1"
                ;;
            -s)
                shift
                [[ $# -eq 0 ]] && { _err dlt "-s requires a time (e.g. 10m, 1h)"; return 1; }
                since="$1"
                ;;
            -*) _err dlt "unknown flag: $1  (try: dlt --help)"; return 1 ;;
            *)
                # A bare integer is the line count, same rule as dclt. Only
                # pure digits qualify, so 'all' still needs -n and can never be
                # mistaken for a container name.
                case "$1" in
                    ''|*[!0-9]*) patterns+=("$1") ;;
                    *)           tail_lines="$1" ;;
                esac
                ;;
        esac
        shift
    done

    if [[ "$tail_lines" != "all" ]]; then
        case "$tail_lines" in
            ''|*[!0-9]*) _err dlt "line count must be a number or 'all': $tail_lines"; return 1 ;;
        esac
    fi

    # --- match containers ---------------------------------------------------
    local ps_args=(ps --format '{{.Names}}')
    [[ "$all" == true ]] && ps_args+=(-a)

    local listing
    listing=$(docker "${ps_args[@]}" 2>/dev/null) || {
        _err dlt "could not reach the docker daemon"
        return 1
    }

    local names=() matched=() name pat keep
    while IFS= read -r name || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue
        names+=("$name")
        if [[ ${#patterns[@]} -eq 0 ]]; then
            matched+=("$name")
            continue
        fi
        keep=false
        for pat in "${patterns[@]}"; do
            if [[ "$name" =~ $pat ]]; then keep=true; break; fi
        done
        [[ "$keep" == true ]] && matched+=("$name")
    done <<< "$listing"

    if [[ ${#names[@]} -eq 0 ]]; then
        if [[ "$all" == true ]]; then
            _err dlt "there are no containers on this host"
        else
            _err dlt "no containers are running  (try: dlt -a)"
        fi
        return 1
    fi

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err dlt "no container matched: ${patterns[*]}"
        printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${names[*]}" >&2
        return 1
    fi

    # --- build the command --------------------------------------------------
    # Long flag names on purpose: the preview doubles as documentation.
    local dflags=() flags_line="" shown_flags=""

    dflags+=(--tail "$tail_lines")
    shown_flags+=" ${CYE}--tail ${tail_lines}${CR}"
    flags_line+=" --tail $tail_lines"

    if [[ "$follow" == true ]]; then
        dflags+=(--follow);     shown_flags+=" ${CYE}--follow${CR}";     flags_line+=" --follow"
    fi
    if [[ "$timestamps" == true ]]; then
        dflags+=(--timestamps); shown_flags+=" ${CYE}--timestamps${CR}"; flags_line+=" --timestamps"
    fi
    if [[ -n "$since" ]]; then
        dflags+=(--since "$since")
        shown_flags+=" ${CYE}--since ${since}${CR}"
        flags_line+=" --since $since"
    fi

    local shown="${CDIM}docker${CR} ${CBL}${CB}logs${CR}${shown_flags}"
    local item
    for item in "${matched[@]}"; do
        shown+=" ${CMA}${item}${CR}"
    done

    _render_preview "docker logs" "" "${matched[*]}" "${flags_line# }" "$shown"

    # --- one container: hand it straight to docker --------------------------
    # `set --` rather than reaching for element 0 or 1: bash indexes arrays
    # from 0 and zsh from 1, and there is no spelling that means the same in
    # both. The positional parameters do.
    if [[ ${#matched[@]} -eq 1 ]]; then
        set -- "${matched[@]}"
        docker logs "${dflags[@]}" "$1"
        return $?
    fi

    # --- several: one docker logs each, interleaved here ---------------------
    #
    # What gets recorded is the PID of `docker logs`, NOT the one `$!` reports
    # for the pipeline. Measured in both shells: killing the PID that `$!`
    # gives for `{ a | b; } &` leaves a AND b running, so every Ctrl-C would
    # strand a `docker logs --follow` per container. Killing the producer
    # closes awk's stdin instead, and awk leaves on its own — verified to end
    # with zero survivors in bash and in zsh.
    local tmp
    tmp=$(mktemp -d) || { _err dlt "could not create a temp directory"; return 1; }

    local width=0 c
    for c in "${matched[@]}"; do
        (( ${#c} > width )) && width=${#c}
    done

    local ci=0 color pfx _DA_R
    for c in "${matched[@]}"; do
        ci=$(( ci + 1 ))
        color=$(_dlt_color "$ci")
        _pad_into "$c" "$width"
        # Resolved through printf before awk sees it. Not because awk would
        # otherwise print the escape — `awk -v` performs escape processing on
        # the value it assigns, which POSIX requires, so "\033[" would come out
        # as a real ESC either way; measured identical on both forms. It is
        # resolved here so the prefix is already the bytes we mean, and does
        # not quietly depend on that.
        pfx=$(printf "${color}%s${CR} ${CDIM}|${CR} " "$_DA_R")
        {
            docker logs "${dflags[@]}" "$c" 2>&1 &
            printf '%s\n' "$!" >> "$tmp/pids"
            wait
        } | awk -v p="$pfx" '{ print p $0; fflush() }' &
    done

    # `wait` with no argument returns when every child has, which for --follow
    # means when the user interrupts. The trap fires first and stops the
    # producers, so the awks reach EOF and the wait returns rather than hanging.
    trap '_dlt_stop "$tmp"' INT TERM
    wait
    trap - INT TERM
    _dlt_stop "$tmp"
    return 0
}

# _dlt_stop <tmpdir> — stop every docker logs this run started, then clean up
_dlt_stop() {
    local dir="$1" p
    if [[ -f "$dir/pids" ]]; then
        while IFS= read -r p || [[ -n "$p" ]]; do
            [[ -n "$p" ]] && kill "$p" 2>/dev/null
        done < "$dir/pids"
    fi
    rm -rf "$dir"
}

# Completion source: container names across the host.
_dlt_candidates() { _list_containers 2>/dev/null; }
