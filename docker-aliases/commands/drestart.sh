#!/usr/bin/env bash
# docker-aliases — drestart: restart running containers by name, host-wide.
#
# dcrestart is for the compose project you are standing in; this is for any
# running container on the host, wherever it came from.
#
# Design contract:
#   * A pattern is REQUIRED. There is no "restart everything" default; "." is
#     there for whoever means it, and the preview will count it out loud.
#   * Several matches restart them all — docker restart takes a list — and the
#     preview names every one. A pattern that IS a container's name means that
#     container alone: `drestart keycloak` leaves keycloak-db running.
#   * Running containers only. A stopped one that matches is named in the
#     error, with the command that starts it: restarting something that is not
#     running is a start in disguise, and a start deserves its own command.
#   * Preview, then `yes`. A restart interrupts whatever the container is
#     serving; one keystroke is too cheap for that.
#   * Containers from a compose project get one line of warning: a plain
#     restart keeps the configuration they were created with.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_drestart_help() {
    printf "${CB}${CCY}drestart${CR} — restart running containers by name, host-wide\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}drestart${CR} [${CYE}-t${CR} ${CMA}seconds${CR}] ${CMA}pattern${CR}\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-t${CR} ${CMA}seconds${CR}         Grace period before SIGKILL ${CI}(docker's default: 10)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}MATCHING${CR}\n"
    printf "  A regex over ${CB}running${CR} containers. Every match is restarted, and the\n"
    printf "  preview names each one first. A pattern that ${CB}is${CR} a container's name\n"
    printf "  means that container alone: ${CGR}drestart keycloak${CR} leaves keycloak-db be.\n\n"

    printf "${CCY}NOTE${CR}\n"
    printf "  A restart keeps the configuration a container was created with. If you\n"
    printf "  changed a compose file, ${CGR}dcup${CR} is what applies it.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}drestart keycloak${CR}        Just keycloak\n"
    printf "  ${CGR}drestart '^srv-'${CR}         Every container whose name starts with srv-\n"
    printf "  ${CGR}drestart -t 30 kafka${CR}     Give it 30 seconds to shut down cleanly\n"
}

# ---------------------------------------------------------------------------
# drestart
# ---------------------------------------------------------------------------

drestart() {
    local pattern="" timeout="" listing line tab=$'\t' name project service
    local exact="" stopped_out n composed=0
    local -a names matched shown_lines stopped_matches cmd

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _drestart_help; return 0 ;;
            -t)
                shift
                [[ $# -eq 0 ]] && { _err drestart "-t requires a number of seconds"; return 1; }
                [[ "$1" =~ ^[0-9]+$ ]] || { _err drestart "-t takes whole seconds, not: $1"; return 1; }
                timeout="$1"
                ;;
            -t[0-9]*)
                timeout="${1#-t}"
                [[ "$timeout" =~ ^[0-9]+$ ]] || { _err drestart "-t takes whole seconds, not: $timeout"; return 1; }
                ;;
            -*) _err drestart "unknown flag: $1  (try: drestart --help)"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err drestart "one pattern at a time"; return 1; }
                pattern="$1"
                ;;
        esac
        shift
    done

    if [[ -z "$pattern" ]]; then
        _err drestart "a pattern is required — there is no restart-everything default"
        printf "  ${CDIM}if you mean every running container, say so:${CR} ${CYE}drestart .${CR}\n" >&2
        return 1
    fi

    # --- match running containers, with their compose labels ----------------
    if ! listing=$(docker ps --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}' 2>/dev/null); then
        _err drestart "could not reach the docker daemon"
        return 1
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}"
        [[ "$name" == "$pattern" ]] && exact="$line"
        [[ "$name" =~ $pattern ]] && matched+=("$line")
    done <<< "$listing"
    [[ -n "$exact" ]] && matched=("$exact")

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err drestart "no running container matched: $pattern"
        # Is it there but stopped? Asked only on this error path.
        stopped_out=$(docker ps -a --filter status=exited --filter status=created --format '{{.Names}}' 2>/dev/null)
        while IFS= read -r n; do
            [[ -n "$n" && "$n" =~ $pattern ]] && stopped_matches+=("$n")
        done <<< "$stopped_out"
        if [[ ${#stopped_matches[@]} -gt 0 ]]; then
            printf "  ${CDIM}it matches stopped container(s) — drestart only restarts running ones:${CR}\n" >&2
            for n in "${stopped_matches[@]}"; do
                printf "    ${CMA}%s${CR}  ${CDIM}start it with${CR} ${CYE}docker start %s${CR}\n" "$n" "$n" >&2
            done
        fi
        return 1
    fi

    # --- build the command --------------------------------------------------
    cmd=(docker restart)
    local shown="${CDIM}docker${CR} ${CYE}${CB}restart${CR}"
    if [[ -n "$timeout" ]]; then
        cmd+=(-t "$timeout")
        shown+=" ${CYE}-t${CR} ${CMA}${timeout}${CR}"
    fi
    for line in "${matched[@]}"; do
        name="${line%%"$tab"*}"
        cmd+=("$name")
        shown+=" ${CWH}${name}${CR}"
    done

    # --- preview ------------------------------------------------------------
    # One line per container, with where it came from: a name alone does not
    # say that srv-debian belongs to bastion-lab and will come back with that
    # project's old config.
    {
        printf "  %s ${CYE}${CB}restart${CR}  ${CDIM}·${CR}  ${CB}%s${CR} ${CDIM}container(s)${CR}\n" \
            "$(_icon docker)" "${#matched[@]}"
        for line in "${matched[@]}"; do
            name="${line%%"$tab"*}"; line="${line#*"$tab"}"
            project="${line%%"$tab"*}"; service="${line#*"$tab"}"
            if [[ -n "$project" ]]; then
                composed=$(( composed + 1 ))
                printf "  %s ${CWH}%s${CR}  ${CDIM}%s/%s${CR}\n" "$(_icon services)" "$name" "$project" "$service"
            else
                printf "  %s ${CWH}%s${CR}\n" "$(_icon services)" "$name"
            fi
        done
        [[ -n "$timeout" ]] && printf "  %s ${CYE}-t %s${CR}  ${CDIM}seconds before SIGKILL${CR}\n" "$(_icon flags)" "$timeout"
        printf "  %s %s${CR}\n" "$(_icon cmd)" "$shown"
        _hr
    } >&2

    if (( composed > 0 )); then
        _note "$composed from compose: a restart keeps the config they were created with — dcup applies a changed compose file"
    fi

    # --- confirm and run ----------------------------------------------------
    _confirm_operation "Restart ${#matched[@]} container(s)?" "$(_action_color restart)" || {
        printf "  ${CB}${CYE}Cancelled${CR}\n" >&2
        return 1
    }
    "${cmd[@]}"
}

# Completion source: running containers.
_drestart_candidates() {
    docker ps --format '{{.Names}}' 2>/dev/null | LC_ALL=C sort
}
