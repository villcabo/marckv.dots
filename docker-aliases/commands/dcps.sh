#!/usr/bin/env bash
# docker-aliases — dcps: list the services of the current compose project.
#
# Replaces v1's dcps, dcps -c and dcps -p. Those variants existed only because
# the PORTS column blew out the row: -c dropped it, -p showed nothing else.
# With ports compacted there is one useful view, so there is one command.
#
# Design contract:
#   * SERVICE first. Inside a project that is the name you actually type — it
#     is what dclt, dcx and dcup all take.
#   * Ports are compacted, never truncated. See _compact_ports in lib/ui.sh.
#   * The table is the output; the scope gets a header line, not a preview.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcps_help() {
    printf "${CB}${CCY}dcps${CR} — list this project's services\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcps${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Include stopped services\n"
    printf "  ${CYE}-x${CR}                 Also show exposed-but-unpublished ports ${CI}(marked ~)${CR}\n"
    printf "  ${CYE}-t${CR}                 Show the creation date instead of how long ago\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-axt${CR} ${CI}is the same as${CR} ${CGR}-a -x${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against service names,\n"
    printf "  as in ${CB}dclt${CR} and ${CB}dcdown${CR}. With no pattern, every service is listed.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcps${CR}                          Everything running here\n"
    printf "  ${CGR}dcps api${CR}                      Only services matching 'api'\n"
    printf "  ${CGR}dcps -a${CR}                       Include stopped services\n"
    printf "  ${CGR}dcps -x${CR}                       Exposed ports too\n"
}

# ---------------------------------------------------------------------------
# dcps
# ---------------------------------------------------------------------------

dcps() {
    case "$1" in
        -h|--help) _dcps_help; return 0 ;;
    esac

    # --- expand clustered short flags: -ax → -a -x --------------------------
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
    local all=false show_exposed=false absolute=false
    local files=() env_files=() profiles=() patterns=()
    local profile_item

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcps_help; return 0 ;;
            -a) all=true ;;
            -x) show_exposed=true ;;
            -t) absolute=true ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcps "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcps "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcps "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dcps "unknown flag: $1  (try: dcps --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcps "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcps "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcps "env file not found: $file"; return 1; }
    done

    # --- collect ------------------------------------------------------------
    local cmd=(docker compose)
    local item
    for item in "${files[@]}";     do cmd+=(-f "$item"); done
    for item in "${env_files[@]}"; do cmd+=(--env-file "$item"); done
    for item in "${profiles[@]}";  do cmd+=(--profile "$item"); done
    cmd+=(ps --format '{{.Service}}	{{.ID}}	{{.Image}}	{{.Status}}	{{.RunningFor}}	{{.CreatedAt}}	{{.Ports}}')
    [[ "$all" == true ]] && cmd+=(-a)

    local raw
    raw=$("${cmd[@]}" 2>/dev/null) || {
        _err dcps "could not list services — is the docker daemon reachable?"
        return 1
    }

    local rows="" nl='
'
    local total=0 shown=0
    local service cid image cstatus since created_at raw_ports compacted when pat keep

    while IFS=$'\t' read -r service cid image cstatus since created_at raw_ports || [[ -n "$service" ]]; do
        [[ -z "$service" ]] && continue
        total=$(( total + 1 ))

        if [[ ${#patterns[@]} -gt 0 ]]; then
            keep=false
            for pat in "${patterns[@]}"; do
                if [[ "$service" =~ $pat ]]; then keep=true; break; fi
            done
            [[ "$keep" == false ]] && continue
        fi

        compacted=$(_compact_ports "$raw_ports" "$show_exposed")
        if [[ "$absolute" == true ]]; then
            when=$(_short_timestamp "$created_at")
        else
            when=$(_short_duration "$since")
        fi
        rows+="${rows:+$nl}${cid}	${image}	${when}	$(_short_status "$cstatus")	${compacted:-—}	${service}"
        shown=$(( shown + 1 ))
    done <<< "$raw"

    # --- render -------------------------------------------------------------
    _render_container_table "compose ps" "$shown" "$total" "${patterns[*]}" \
        "CONTAINER ID" "IMAGE" "CREATED" "STATUS" "PORTS" "SERVICE" "$rows"
}

# Completion source: service names of the current project.
# Completion source: service names, honouring any -P already typed.
_dcps_candidates() {
    _get_compose_services --profiles "$(_profiles_from_words "$@")" 2>/dev/null
}
