#!/usr/bin/env bash
# docker-aliases — dcup: bring compose services up.
#
# Design contract for this command:
#   * The preview is not optional. It always renders before anything runs.
#   * The confirmation is not optional. There is no -y flag; you type "yes".
#     (DOCKER_ALIASES_AUTO_YES=1 exists for tests/CI only.)
#   * The command shown in the preview is the command that executes. It is
#     built once as an array, rendered from those same pieces, and run with
#     no eval — so quoting can never make the preview lie.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcup_help() {
    printf "${CB}${CCY}dcup${CR} — bring Docker Compose services up\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcup${CR} [${CYE}flags${CR}] [${CMA}service...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-r${CR}                 Force recreate containers    ${CDIM}--force-recreate${CR}\n"
    printf "  ${CYE}-p${CR}                 Pull images before starting  ${CDIM}--pull always${CR}\n"
    printf "  ${CYE}-b${CR}                 Build images before starting ${CDIM}--build${CR}\n"
    printf "  ${CYE}-l${CR}                 Follow logs after starting\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-rpl${CR} ${CI}is the same as${CR} ${CGR}-r -p -l${CR}\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcup${CR}                              Start every service\n"
    printf "  ${CGR}dcup api worker${CR}                   Start only these services\n"
    printf "  ${CGR}dcup -r${CR}                           Force recreate everything\n"
    printf "  ${CGR}dcup -rl${CR}                          Recreate, then follow logs\n"
    printf "  ${CGR}dcup -rpl api${CR}                     Recreate + pull + logs, for 'api'\n"
    printf "  ${CGR}dcup -f prod.yml -r${CR}               Custom compose file\n"
    printf "  ${CGR}dcup -f a.yml -f b.yml${CR}            Layer multiple compose files\n"
    printf "  ${CGR}dcup -e .env.prod${CR}                 Custom env file\n"
    printf "  ${CGR}dcup -P dev,debug${CR}                 Enable two profiles\n\n"

    printf "${CCY}CONFIRMATION${CR}\n"
    printf "  Every run shows a preview and asks ${CB}Continue? [yes/N]${CR}.\n"
    printf "  You must type the full word ${CB}yes${CR} — a bare ${CB}y${CR} is rejected, and\n"
    printf "  plain Enter cancels. This command recreates and restarts running\n"
    printf "  services, so there is no flag to skip the prompt.\n"
}

# ---------------------------------------------------------------------------
# dcup
# ---------------------------------------------------------------------------

dcup() {
    case "$1" in
        -h|--help) _dcup_help; return 0 ;;
    esac

    # --- expand clustered short flags: -rpl → -r -p -l ----------------------
    # A value-taking flag (-f/-e/-P) simply has to be last in its cluster,
    # which falls out naturally: "-rf prod.yml" becomes "-r -f prod.yml".
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
    local recreate=false pull=false build=false follow_logs=false
    local files=() env_files=() profiles=() services=()
    local profile_item

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcup_help; return 0 ;;
            -r) recreate=true ;;
            -p) pull=true ;;
            -b) build=true ;;
            -l) follow_logs=true ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcup "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcup "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcup "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dcup "unknown flag: $1  (try: dcup --help)"; return 1 ;;
            *)  services+=("$1") ;;
        esac
        shift
    done

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcup "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        # May be two lines: the base file and its override sibling.
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcup "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcup "env file not found: $file"; return 1; }
    done

    # --- build the command --------------------------------------------------
    # Two representations from one source of truth: an array that executes and
    # a colored string that renders. They are appended in lockstep.
    #
    # Position matters: --env-file and --profile are options of `docker
    # compose` itself, so they go BEFORE the `up` subcommand. Putting
    # --env-file after `up` makes docker reject the whole command.
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

    cmd+=(up -d)
    shown+=" ${CGR}${CB}up${CR} ${CYE}-d${CR}"

    local flags_line=""
    if [[ "$recreate" == true ]]; then
        cmd+=(--force-recreate); shown+=" ${CYE}--force-recreate${CR}"; flags_line+=" --force-recreate"
    fi
    if [[ "$pull" == true ]]; then
        cmd+=(--pull always);    shown+=" ${CYE}--pull always${CR}";    flags_line+=" --pull always"
    fi
    if [[ "$build" == true ]]; then
        cmd+=(--build);          shown+=" ${CYE}--build${CR}";          flags_line+=" --build"
    fi

    for item in "${services[@]}"; do
        cmd+=("$item")
        shown+=" ${CMA}${item}${CR}"
    done

    # --- preview ------------------------------------------------------------
    # With no services named, docker starts them all — so show what "all"
    # actually means right now instead of leaving the line blank.
    local preview_services="${services[*]}"
    if [[ ${#services[@]} -eq 0 ]]; then
        local discovered
        if discovered=$(_get_compose_services --profiles "${profiles[*]}" "${files[@]}" 2>/dev/null); then
            preview_services=$(printf '%s' "$discovered" | tr '\n' ' ')
        fi
    fi

    local files_display
    files_display=$(printf '%s\n' "${files[@]}")

    _render_preview "compose up" "$files_display" "$preview_services" "${flags_line# }" "$shown"

    # --- confirm ------------------------------------------------------------
    _confirm_operation "Continue?" "$(_action_color up)" || {
        printf "  ${CB}${CYE}Cancelled${CR}\n"
        return 1
    }

    # --- run ----------------------------------------------------------------
    "${cmd[@]}" || return $?

    if [[ "$follow_logs" == true ]]; then
        local log_cmd=(docker compose)
        for item in "${files[@]}";     do log_cmd+=(-f "$item"); done
        for item in "${env_files[@]}"; do log_cmd+=(--env-file "$item"); done
        for item in "${profiles[@]}";  do log_cmd+=(--profile "$item"); done
        log_cmd+=(logs -f)
        [[ ${#services[@]} -gt 0 ]] && log_cmd+=("${services[@]}")
        "${log_cmd[@]}"
    fi
}
