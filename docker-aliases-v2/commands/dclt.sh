#!/usr/bin/env bash
# docker-aliases v2 — dclt: tail compose logs for services matched by regex.
#
# Design contract for this command:
#   * Patterns are ALWAYS regex. `dclt api` matches api, api-worker and myapi
#     with no flag to remember. v1 required -r for this and matched exactly
#     otherwise, which meant forgetting -r silently matched nothing.
#   * A preview renders, but nothing is confirmed. This command only reads —
#     making you type "yes" to look at logs is friction with no payoff. The
#     preview still earns its place: with regex you want to see what matched
#     before the output fills the screen.
#   * The preview goes to stderr, so `dclt -o api | grep error` pipes cleanly.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dclt_help() {
    printf "${CB}${CCY}dclt${CR} — tail Docker Compose logs\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dclt${CR} [${CYE}flags${CR}] [${CMA}lines${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-n${CR} ${CMA}<N|all>${CR}         Lines to tail ${CI}(default 100)${CR}\n"
    printf "  ${CYE}-s${CR} ${CMA}<time>${CR}          Only logs since then ${CI}(10m, 1h, a timestamp)${CR}\n"
    printf "  ${CYE}-o${CR}                 Once: dump and exit instead of following\n"
    printf "  ${CYE}-t${CR}                 Prefix every line with its timestamp\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-ot${CR} ${CI}is the same as${CR} ${CGR}-o -t${CR}\n"
    printf "  ${CI}A bare number is the line count:${CR} ${CGR}dclt 500 api${CR} ${CI}=${CR} ${CGR}dclt -n 500 api${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against service names.\n"
    printf "  With no pattern, every service is followed.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dclt${CR}                              Follow every service\n"
    printf "  ${CGR}dclt api${CR}                          Anything matching 'api'\n"
    printf "  ${CGR}dclt 'api|db'${CR}                     Two patterns at once\n"
    printf "  ${CGR}dclt '^api\$'${CR}                      Exactly the service named 'api'\n"
    printf "  ${CGR}dclt 500 api${CR}                      Last 500 lines, then follow\n"
    printf "  ${CGR}dclt -n all api${CR}                   The whole log, then follow\n"
    printf "  ${CGR}dclt -s 10m${CR}                       Only the last 10 minutes\n"
    printf "  ${CGR}dclt -ot api${CR}                      Dump with timestamps, do not follow\n"
    printf "  ${CGR}dclt -o api | grep -i error${CR}       Pipe it — the preview stays on stderr\n"
}

# ---------------------------------------------------------------------------
# dclt
# ---------------------------------------------------------------------------

dclt() {
    case "$1" in
        -h|--help) _dclt_help; return 0 ;;
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
    local since="" follow=true timestamps=false
    local files=() env_files=() profiles=() patterns=()
    local profile_item

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dclt_help; return 0 ;;
            -o) follow=false ;;
            -t) timestamps=true ;;
            -n)
                shift
                [[ $# -eq 0 ]] && { _err dclt "-n requires a line count or 'all'"; return 1; }
                tail_lines="$1"
                ;;
            -s)
                shift
                [[ $# -eq 0 ]] && { _err dclt "-s requires a time (e.g. 10m, 1h)"; return 1; }
                since="$1"
                ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dclt "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dclt "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dclt "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dclt "unknown flag: $1  (try: dclt --help)"; return 1 ;;
            *)
                # A bare integer is the line count — this is what replaces the
                # old idea of separate dclt100 / dclt500 commands. Only pure
                # digits qualify, so 'all' still needs -n and can never be
                # confused with a service name.
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
            ''|*[!0-9]*) _err dclt "line count must be a number or 'all': $tail_lines"; return 1 ;;
        esac
    fi

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local detected
        detected=$(_get_compose_file) || {
            _err dclt "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        files+=("$detected")
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dclt "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dclt "env file not found: $file"; return 1; }
    done

    # --- match services -----------------------------------------------------
    local services=() svc
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && services+=("$svc")
    done <<< "$(_get_compose_services "${files[@]}")"

    if [[ ${#services[@]} -eq 0 ]]; then
        _err dclt "no services found in the compose file"
        return 1
    fi

    # Iterating services on the outside keeps them in compose order and makes
    # duplicates impossible, so no dedupe pass is needed: a service matched by
    # two patterns is still only added once.
    local matched=() pat
    if [[ ${#patterns[@]} -eq 0 ]]; then
        matched=("${services[@]}")
    else
        for svc in "${services[@]}"; do
            for pat in "${patterns[@]}"; do
                if [[ "$svc" =~ $pat ]]; then
                    matched+=("$svc")
                    break
                fi
            done
        done
    fi

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err dclt "no service matched: ${patterns[*]}"
        printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${services[*]}" >&2
        return 1
    fi

    # --- build the command --------------------------------------------------
    # Long flag names on purpose: the preview doubles as documentation, and
    # `--follow` reads better than a second `-f` next to the compose-file one.
    local cmd=(docker compose)
    local shown="${CDIM}docker compose${CR}"
    local item

    for item in "${files[@]}"; do
        cmd+=(-f "$item")
        shown+=" ${CDIM}-f${CR} ${CWH}${item}${CR}"
    done
    for item in "${env_files[@]}"; do
        cmd+=(--env-file "$item")
        shown+=" ${CDIM}--env-file${CR} ${CWH}${item}${CR}"
    done
    for item in "${profiles[@]}"; do
        cmd+=(--profile "$item")
        shown+=" ${CDIM}--profile${CR} ${CBL}${item}${CR}"
    done

    cmd+=(logs)
    shown+=" ${CBL}${CB}logs${CR}"

    local flags_line=""
    cmd+=(--tail "$tail_lines")
    shown+=" ${CYE}--tail ${tail_lines}${CR}"
    flags_line+=" --tail $tail_lines"

    if [[ "$follow" == true ]]; then
        cmd+=(--follow);      shown+=" ${CYE}--follow${CR}";     flags_line+=" --follow"
    fi
    if [[ "$timestamps" == true ]]; then
        cmd+=(--timestamps);  shown+=" ${CYE}--timestamps${CR}"; flags_line+=" --timestamps"
    fi
    if [[ -n "$since" ]]; then
        cmd+=(--since "$since")
        shown+=" ${CYE}--since ${since}${CR}"
        flags_line+=" --since $since"
    fi

    for item in "${matched[@]}"; do
        cmd+=("$item")
        shown+=" ${CMA}${item}${CR}"
    done

    # --- preview, then run --------------------------------------------------
    # No confirmation: reading logs changes nothing.
    local files_display
    files_display=$(printf '%s\n' "${files[@]}")

    _render_preview "compose logs" "$files_display" "${matched[*]}" "${flags_line# }" "$shown"

    "${cmd[@]}"
}
