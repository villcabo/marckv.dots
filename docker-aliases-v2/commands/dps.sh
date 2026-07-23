#!/usr/bin/env bash
# docker-aliases v2 — dps: list containers across the whole host.
#
# Replaces v1's dps / dps1 / dpsp. Those three existed for one reason: the
# PORTS column overflowed the row, so you needed a variant that omitted it and
# another that showed nothing else. Compact the ports and the reason evaporates
# — one command, one view, ports included.
#
# Design contract:
#   * Ports are compacted, never truncated. Truncation hides information;
#     compaction removes only what was duplicated or unreachable.
#   * The table is the output. A preview block would say the same thing twice,
#     so the scope gets one header line instead.
#   * Colored here rather than piped through docker-color-output: we choose the
#     format, so we are the only ones who know which column means what.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dps_help() {
    printf "${CB}${CCY}dps${CR} — list containers on this host\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dps${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Include stopped containers\n"
    printf "  ${CYE}-x${CR}                 Also show exposed-but-unpublished ports ${CI}(marked ~)${CR}\n"
    printf "  ${CYE}-t${CR}                 Show the creation date instead of how long ago\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-axt${CR} ${CI}is the same as${CR} ${CGR}-a -x${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against container names,\n"
    printf "  as in ${CB}dclt${CR} and ${CB}dcd${CR}. With no pattern, everything is listed.\n\n"

    printf "${CCY}PORTS${CR}\n"
    printf "  Published ports only, compacted:\n"
    printf "    ${CDIM}0.0.0.0:9080->9080/tcp${CR}                 →  ${CGR}9080${CR}\n"
    printf "    ${CDIM}0.0.0.0:3001->3000/tcp, [::]:3001->...${CR} →  ${CGR}3001→3000${CR}\n"
    printf "    ${CDIM}127.0.0.1:5432->5432/tcp${CR}               →  ${CGR}lo:5432${CR}\n"
    printf "    ${CDIM}5432/tcp${CR} ${CI}(exposed, not published)${CR}       →  ${CI}hidden, -x to show${CR}\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dps${CR}                           Everything running\n"
    printf "  ${CGR}dps redmine${CR}                   Only what matches 'redmine'\n"
    printf "  ${CGR}dps -a${CR}                        Include stopped containers\n"
    printf "  ${CGR}dps -ax 'db|cache'${CR}            Stopped too, exposed ports too\n"
    printf "  ${CGR}dps -t${CR}                        Exact creation dates\n\n"

    printf "${CCY}STATUS vs CREATED${CR}\n"
    printf "  They answer different questions. ${CB}STATUS${CR} is how long it has been\n"
    printf "  running; ${CB}CREATED${CR} is when the container was made. A container created\n"
    printf "  ${CB}3w${CR} ago showing ${CB}Up 5h${CR} restarted five hours ago — which is usually\n"
    printf "  the thing you were trying to find out.\n"
}

# ---------------------------------------------------------------------------
# dps
# ---------------------------------------------------------------------------

dps() {
    case "$1" in
        -h|--help) _dps_help; return 0 ;;
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
    local all=false show_exposed=false absolute=false patterns=()

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dps_help; return 0 ;;
            -a) all=true ;;
            -x) show_exposed=true ;;
            -t) absolute=true ;;
            -*) _err dps "unknown flag: $1  (try: dps --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- collect ------------------------------------------------------------
    local ps_args=(ps --format '{{.Names}}	{{.ID}}	{{.Image}}	{{.Status}}	{{.RunningFor}}	{{.CreatedAt}}	{{.Ports}}')
    [[ "$all" == true ]] && ps_args+=(-a)

    local raw
    raw=$(docker "${ps_args[@]}" 2>/dev/null) || {
        _err dps "could not reach the docker daemon"
        return 1
    }

    local rows="" nl='
'
    local total=0 shown=0
    local name cid image cstatus since created_at raw_ports compacted when pat keep

    while IFS=$'\t' read -r name cid image cstatus since created_at raw_ports || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue
        total=$(( total + 1 ))

        if [[ ${#patterns[@]} -gt 0 ]]; then
            keep=false
            for pat in "${patterns[@]}"; do
                if [[ "$name" =~ $pat ]]; then keep=true; break; fi
            done
            [[ "$keep" == false ]] && continue
        fi

        compacted=$(_compact_ports "$raw_ports" "$show_exposed")
        if [[ "$absolute" == true ]]; then
            when=$(_short_timestamp "$created_at")
        else
            when=$(_short_duration "$since")
        fi
        rows+="${rows:+$nl}${name}	${cid}	${image}	$(_short_status "$cstatus")	${when}	${compacted:-—}"
        shown=$(( shown + 1 ))
    done <<< "$raw"

    # --- render -------------------------------------------------------------
    _render_container_table "docker ps" "$shown" "$total" "${patterns[*]}" \
        "NAME" "ID" "IMAGE" "STATUS" "CREATED" "PORTS" "$rows"
}

# Completion source: container names across the host.
_dps_candidates() { _list_containers 2>/dev/null; }
