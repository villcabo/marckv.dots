#!/usr/bin/env bash
# docker-aliases — dip: which container has this IP.
#
# The question it answers comes up in a log: nginx says 172.18.0.5 timed out,
# and you want the container behind that address. Doing it by hand is a
# `docker inspect` per container and a grep through nested JSON.
#
# Design contract:
#   * One `docker inspect` for every running container, never one per row.
#   * A full IPv4 matches EXACTLY. As a substring, 172.18.0.5 also matches
#     172.18.0.50 — the classic way an IP search lies. A partial address
#     (172.18.0) matches as a prefix on an octet boundary, so it is a subnet.
#     Anything that is not an address is a regex against name and network.
#   * One row per container per network: a container on three networks has
#     three addresses, and the one you are looking for may be any of them.
#   * Read-only: no preview block, no confirmation. A scope line, like dps.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dip_help() {
    printf "${CB}${CCY}dip${CR} — which container has this IP\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dip${CR} [${CMA}address | pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}MATCHING${CR}\n"
    printf "  ${CB}172.18.0.5${CR}      a full address matches ${CB}exactly${CR} — never 172.18.0.50\n"
    printf "  ${CB}172.18.0${CR}        a partial one is a subnet: everything in 172.18.0.*\n"
    printf "  ${CB}nginx${CR}           anything else is a regex against name and network\n"
    printf "  ${CI}(nothing)${CR}       every address on the host, one row per network\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dip 172.18.0.5${CR}        Who is behind the address in that log line\n"
    printf "  ${CGR}dip 10.100${CR}            Everything on that subnet\n"
    printf "  ${CGR}dip keycloak${CR}          Every address keycloak holds\n"
    printf "  ${CGR}dip _backend${CR}          Who is attached to the backend network\n"
}

# ---------------------------------------------------------------------------
# Matching
# ---------------------------------------------------------------------------

# _dip_kind <query> → full | partial | text
_dip_kind() {
    case "$1" in
        *[!0-9.]*|'') printf 'text' ;;
        # A trailing dot is a subnet being typed, never a full address: the
        # glob below would otherwise read "172.18.0." as four octets, the last
        # one empty, and demand an exact match nothing can satisfy.
        *.)           printf 'partial' ;;
        *.*.*.*)      printf 'full' ;;
        *)            printf 'partial' ;;
    esac
}

# ---------------------------------------------------------------------------
# dip
# ---------------------------------------------------------------------------

dip() {
    local query=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dip_help; return 0 ;;
            -*) _err dip "unknown flag: $1"; return 1 ;;
            *)
                [[ -n "$query" ]] && { _err dip "one address or pattern at a time"; return 1; }
                query="$1"
                ;;
        esac
        shift
    done

    # --- collect: one ps, one inspect ---------------------------------------
    local listing
    if ! listing=$(docker ps --format '{{.Names}}' 2>/dev/null); then
        _err dip "could not reach the docker daemon"
        return 1
    fi
    if [[ -z "$listing" ]]; then
        _err dip "no containers are running"
        return 1
    fi

    local names=() n
    while IFS= read -r n; do
        [[ -n "$n" ]] && names+=("$n")
    done <<< "$listing"

    # {{"\t"}} and not \t. docker ps --format turns \t into a tab; docker
    # inspect runs the raw Go template and does NOT — measured, a literal
    # backslash-t came back, and every row would have split wrong.
    local raw
    raw=$(docker inspect --format '{{.Name}}{{"\t"}}{{index .Config.Labels "com.docker.compose.project"}}{{"\t"}}{{index .Config.Labels "com.docker.compose.service"}}{{"\t"}}{{.State.Status}}{{range $n, $c := .NetworkSettings.Networks}}{{"\t"}}{{$n}}={{$c.IPAddress}}{{end}}' \
        "${names[@]}" 2>/dev/null) || {
        _err dip "could not inspect the running containers"
        return 1
    }

    # --- expand to one row per network, and filter --------------------------
    local kind="" prefix=""
    if [[ -n "$query" ]]; then
        kind=$(_dip_kind "$query")
        # A partial address is matched on an octet boundary: "172.18" means
        # 172.18.*, and must not also catch 172.180.*.
        [[ "$kind" == partial ]] && prefix="${query%.}."
    fi

    local rows="" total=0 shown=0
    # `state`, never `status`: in zsh status is $? and read-only, so assigning
    # it aborts the function. bash accepts it silently, which is how this
    # passed every bash test and failed every zsh one.
    local name project service state rest pair net ip keep
    local tab=$'\t' nl=$'\n'
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}";    rest="${line#*"$tab"}"
        project="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        service="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        if [[ "$rest" == *"$tab"* ]]; then
            state="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        else
            state="$rest"; rest=""
        fi
        name="${name#/}"
        [[ -z "$project" ]] && project="—"
        [[ -z "$service" ]] && service="—"

        # A container on no network at all still deserves a row: "it has no
        # address" is an answer, and an absent row would look like a miss.
        [[ -z "$rest" ]] && rest="none="

        while [[ -n "$rest" ]]; do
            if [[ "$rest" == *"$tab"* ]]; then
                pair="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
            else
                pair="$rest"; rest=""
            fi
            net="${pair%%=*}"
            ip="${pair#*=}"
            # The host network reports its address as the literal text
            # "invalid IP", not as empty — measured on docker 29. Shown as a
            # dash, so it can never be read as an address or matched as one.
            case "$ip" in ''|'invalid IP'|'<no value>') ip="—" ;; esac

            total=$(( total + 1 ))
            keep=1
            if [[ -n "$query" ]]; then
                case "$kind" in
                    full)    [[ "$ip" == "$query" ]] || keep=0 ;;
                    partial) [[ "$ip" == "$prefix"* ]] || keep=0 ;;
                    text)    [[ "$name" =~ $query || "$net" =~ $query ]] || keep=0 ;;
                esac
            fi
            (( keep )) || continue

            shown=$(( shown + 1 ))
            rows+="${ip}${tab}${net}${tab}${project}${tab}${service}${tab}${state}${tab}${name}${nl}"
        done
    done <<< "$raw"

    _render_container_table "docker ip" "$shown" "$total" "$query" \
        "IP" "NETWORK" "PROJECT" "SERVICE" "STATUS" "NAME" "${rows%"$nl"}" \
        "white,cyan,dim,magenta,@status,white"

    # A lookup that found nothing is a failure a script can test for:
    # `dip 10.0.0.9 || echo free` should work.
    if [[ -n "$query" && $shown -eq 0 ]]; then
        return 1
    fi
    return 0
}
