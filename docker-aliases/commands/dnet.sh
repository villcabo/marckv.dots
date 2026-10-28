#!/usr/bin/env bash
# docker-aliases — dnet: networks, their subnets, and whether anything uses them.
#
# `docker network ls` gives a name, a driver and a scope. What you usually want
# is the subnet, and whether the network is doing anything at all — on a host
# that has run a few compose projects, most of them are leftovers.
#
# Design contract:
#   * "Nothing running on it" is NOT "unused", and the difference is the whole
#     reason this command exists. A network a STOPPED container still points at
#     survives `docker network prune`. Measured on a real host: 23 of 39
#     networks had no running container, and all 23 were held by stopped ones —
#     a command that called them "unused" and suggested a prune would have
#     promised 23 deletions and delivered zero.
#   * So USE has four values, and only one of them is prunable:
#       N running   something is on it now
#       stopped     only stopped containers point at it — remove those first
#       unused      nothing points at it: this is what a prune removes
#       built-in    bridge, host and none — docker will not remove these
#   * Three docker calls in total, never one per row.
#   * Read-only: a scope line, no preview, no confirmation.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dnet_help() {
    printf "${CB}${CCY}dnet${CR} — networks, their subnets, and what uses them\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dnet${CR} [${CYE}-u${CR}] [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-u${CR}                 Only the unused ones — what a prune would remove\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}THE USE COLUMN${CR}\n"
    printf "  ${CGR}N running${CR}     containers are on it now\n"
    printf "  ${CDIM}stopped${CR}       only ${CB}stopped${CR} containers point at it — a prune keeps it\n"
    printf "  ${CYE}unused${CR}        nothing points at it — the only kind a prune removes\n"
    printf "  ${CDIM}built-in${CR}      bridge, host, none — never removed\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dnet${CR}                  Every network\n"
    printf "  ${CGR}dnet -u${CR}               What could be cleaned up\n"
    printf "  ${CGR}dnet 10.100${CR}           Which network owns that range\n"
    printf "  ${CGR}dnet keycloak${CR}         By name or compose project\n"
}

# ---------------------------------------------------------------------------
# Colour for the USE cell — reached by the table as @netuse
# ---------------------------------------------------------------------------

_netuse_color_into() {
    case "$1" in
        *running) _DA_R="$CGR" ;;
        unused)   _DA_R="$CYE" ;;
        *)        _DA_R="$CDIM" ;;   # stopped, built-in
    esac
}

# ---------------------------------------------------------------------------
# dnet
# ---------------------------------------------------------------------------

dnet() {
    local only_unused=false pattern="" arg i ch
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -h|--help) _dnet_help; return 0 ;;
            -u) only_unused=true ;;
            -[a-zA-Z]*)
                # Short flags combine, as in dps and di.
                for (( i = 1; i < ${#arg}; i++ )); do
                    ch="${arg:$i:1}"
                    case "$ch" in
                        u) only_unused=true ;;
                        h) _dnet_help; return 0 ;;
                        *) _err dnet "unknown flag: -$ch"; return 1 ;;
                    esac
                done
                ;;
            -*) _err dnet "unknown flag: $arg"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dnet "one pattern at a time"; return 1; }
                pattern="$arg"
                ;;
        esac
        shift
    done

    # --- collect: three calls, whatever the number of networks --------------
    local listing
    if ! listing=$(docker network ls --format '{{.Name}}' 2>/dev/null); then
        _err dnet "could not reach the docker daemon"
        return 1
    fi

    local names=() n
    while IFS= read -r n; do
        [[ -n "$n" ]] && names+=("$n")
    done <<< "$listing"
    [[ ${#names[@]} -eq 0 ]] && { _err dnet "no networks found"; return 1; }

    # {{"\t"}}, not \t: docker inspect runs the raw template and keeps \t literal.
    local raw
    raw=$(docker network inspect --format '{{.Name}}{{"\t"}}{{.Driver}}{{"\t"}}{{range $i, $c := .IPAM.Config}}{{if $i}},{{end}}{{$c.Subnet}}{{end}}{{"\t"}}{{range $i, $c := .IPAM.Config}}{{if $i}},{{end}}{{$c.Gateway}}{{end}}{{"\t"}}{{len .Containers}}{{"\t"}}{{index .Labels "com.docker.compose.project"}}{{"\t"}}{{.Internal}}' \
        "${names[@]}" 2>/dev/null) || {
        _err dnet "could not inspect the networks"
        return 1
    }

    # Every network ANY container points at, running or stopped, in one call.
    # This is what separates "stopped" from "unused". Wrapped in commas so a
    # lookup is one pattern match instead of a loop: ",a,b," contains ",a,".
    local refs
    refs=",$(docker ps -a --format '{{.Networks}}' 2>/dev/null | tr '\n' ',' ),"

    # --- build rows ---------------------------------------------------------
    local tab=$'\t' nl=$'\n' rows="" total=0 shown=0
    local c_run=0 c_stop=0 c_unused=0 c_builtin=0
    local name driver subnet gateway running project internal rest use keep
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}";     rest="${line#*"$tab"}"
        driver="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        subnet="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        gateway="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        running="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        project="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        internal="$rest"

        case "$name" in
            bridge|host|none)
                use="built-in"; c_builtin=$(( c_builtin + 1 )) ;;
            *)
                if (( running > 0 )); then
                    use="$running running"; c_run=$(( c_run + 1 ))
                elif [[ "$refs" == *",$name,"* ]]; then
                    use="stopped"; c_stop=$(( c_stop + 1 ))
                else
                    use="unused"; c_unused=$(( c_unused + 1 ))
                fi
                ;;
        esac

        [[ -z "$subnet" ]]  && subnet="—"
        [[ -z "$gateway" ]] && gateway="—"
        [[ -z "$project" ]] && project="—"
        # An internal network has no route out. Worth seeing at a glance: it is
        # why a container on it cannot reach the internet, and it is set on
        # purpose more often than not.
        [[ "$internal" == "true" ]] && driver="$driver, internal"

        total=$(( total + 1 ))
        keep=1
        if $only_unused && [[ "$use" != "unused" ]]; then keep=0; fi
        if (( keep )) && [[ -n "$pattern" ]]; then
            [[ "$name" =~ $pattern || "$subnet" =~ $pattern || "$project" =~ $pattern ]] || keep=0
        fi
        (( keep )) || continue

        shown=$(( shown + 1 ))
        rows+="${subnet}${tab}${gateway}${tab}${driver}${tab}${use}${tab}${project}${tab}${name}${nl}"
    done <<< "$raw"

    local filter="$pattern"
    $only_unused && filter="${filter:+$filter, }unused only"

    _render_container_table "docker networks" "$shown" "$total" "$filter" \
        "SUBNET" "GATEWAY" "DRIVER" "USE" "PROJECT" "NAME" "${rows%"$nl"}" \
        "cyan,dim,dim,@netuse,dim,white"

    # The tally is the actual answer to "can I clean this up?". It always
    # counts the whole host, not just the filtered rows, so a filter can never
    # make the leftovers look smaller than they are.
    printf "  ${CDIM}%s running · %s held by stopped containers · ${CR}" "$c_run" "$c_stop" >&2
    if (( c_unused > 0 )); then
        printf "${CYE}%s unused${CR}${CDIM} — dprune removes them${CR}\n" "$c_unused" >&2
    else
        printf "${CDIM}0 unused${CR}\n" >&2
    fi
    if (( c_stop > 0 && c_unused == 0 )); then
        printf "  ${CDIM}the stopped ones go once their containers do — see${CR} ${CYE}dps -a${CR}\n" >&2
    fi

    if [[ -n "$pattern" || "$only_unused" == true ]] && (( shown == 0 )); then
        return 1
    fi
    return 0
}

# Completion source: network names.
_dnet_candidates() {
    docker network ls --format '{{.Name}}' 2>/dev/null
}
