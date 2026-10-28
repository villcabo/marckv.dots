#!/usr/bin/env bash
# docker-aliases — dx: run a command (or open a shell) inside any container.
#
# The host-wide twin of dcx, and the half of that pair that was missing:
# dps/dcps, dlt/dclt and dver/dcver all ask one question at two scopes, and
# "give me a shell in that container" is the same kind of question. dcx needs
# you standing in the project; dx does not, which is the whole reason to want
# it — the same reason dcd exists.
#
# Design contract, inherited from dcx on purpose so the two read the same:
#   * With no command, dx opens a shell — asking for bash and settling for sh.
#   * Flag parsing STOPS at the pattern. Everything after it is the command,
#     so `dx api ls -la` hands -la to ls.
#   * A pattern that matches several containers is an error, not a guess.
#   * Only RUNNING containers are candidates. `docker exec` cannot enter a
#     stopped one, so offering it would only defer the error to the exec.
#   * Preview, but no confirmation: interactive, and used all day.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dx_help() {
    printf "${CB}${CCY}dx${CR} — run a command inside any running container\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dx${CR} [${CYE}flags${CR}] ${CMA}<pattern>${CR} [${CMA}command...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-u${CR} ${CMA}<user>${CR}          Run as this user ${CI}(e.g. root)${CR}\n"
    printf "  ${CYE}-w${CR} ${CMA}<dir>${CR}           Start in this directory\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Flags must come BEFORE the pattern. Everything after the pattern${CR}\n"
    printf "  ${CI}is the command, so ${CR}${CGR}dx api ls -la${CR}${CI} works as written.${CR}\n\n"

    printf "${CCY}SCOPE${CR}\n"
    printf "  Every ${CB}running${CR} container on this host, wherever you are standing.\n"
    printf "  ${CB}dcx${CR} is the same command scoped to the compose project here.\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  A ${CB}regular expression${CR} matched against container names. It must match\n"
    printf "  ${CB}exactly one${CR}: several is an error, and the error lists them.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dx keycloak${CR}                        Open a shell in it\n"
    printf "  ${CGR}dx '^nginx-1\$'${CR}                     Exactly that container\n"
    printf "  ${CGR}dx -u root grafana${CR}                 Shell in as root\n"
    printf "  ${CGR}dx redis redis-cli ping${CR}            Run one command and leave\n"
    printf "  ${CGR}dx api cat /etc/hosts | grep db${CR}    Pipe it — the TTY is dropped for you\n"
}

# ---------------------------------------------------------------------------
# dx
# ---------------------------------------------------------------------------

dx() {
    case "$1" in
        -h|--help) _dx_help; return 0 ;;
    esac

    # --- parse --------------------------------------------------------------
    # No clustering, for the same reason as dcx: -u and -w take values, and
    # everything after the pattern belongs to somebody else's argv.
    local user="" workdir="" pattern="" command_args=()

    while [[ $# -gt 0 ]]; do
        if [[ -n "$pattern" ]]; then
            command_args+=("$1")
            shift
            continue
        fi

        case "$1" in
            -h|--help) _dx_help; return 0 ;;
            -u)
                shift
                [[ $# -eq 0 ]] && { _err dx "-u requires a user"; return 1; }
                user="$1"
                ;;
            -w)
                shift
                [[ $# -eq 0 ]] && { _err dx "-w requires a directory"; return 1; }
                workdir="$1"
                ;;
            --) ;;
            -*) _err dx "unknown flag: $1  (flags go before the pattern)"; return 1 ;;
            *)  pattern="$1" ;;
        esac
        shift
    done

    if [[ -z "$pattern" ]]; then
        _err dx "a container pattern is required  (try: dx --help)"
        return 1
    fi

    # --- match exactly one running container --------------------------------
    local listing
    if ! listing=$(docker ps --format '{{.Names}}' 2>/dev/null); then
        _err dx "could not reach the docker daemon"
        return 1
    fi
    if [[ -z "$listing" ]]; then
        _err dx "no containers are running"
        return 1
    fi

    local names=() name matched=() exact=""
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        names+=("$name")
        [[ "$name" == "$pattern" ]] && exact="$name"
        [[ "$name" =~ $pattern ]] && matched+=("$name")
    done <<< "$listing"
    # A pattern that IS a name means that container, however many others it
    # also matches — otherwise `dx keycloak` dies on keycloak-db and you are
    # made to type ^keycloak$ for the most obvious request there is.
    [[ -n "$exact" ]] && matched=("$exact")

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err dx "no running container matched: $pattern"
        # One per line, not dcx's single line: a project has a handful of
        # services, a host has dozens of containers, and 28 names on one line
        # is a wall nobody scans for the one they meant.
        printf "  ${CDIM}running:${CR}\n" >&2
        printf "    ${CMA}%s${CR}\n" "${names[@]}" >&2
        return 1
    fi

    if [[ ${#matched[@]} -gt 1 ]]; then
        local first=""
        for name in "${matched[@]}"; do first="$name"; break; done
        _err dx "'$pattern' matched ${#matched[@]} containers"
        printf "  ${CMA}%s${CR}\n" "${matched[@]}" >&2
        printf "  ${CDIM}→ narrow the pattern, or use '^%s\$'${CR}\n" "$first" >&2
        return 1
    fi

    local target=""
    for name in "${matched[@]}"; do target="$name"; break; done

    # --- decide the command -------------------------------------------------
    if [[ ${#command_args[@]} -eq 0 ]]; then
        if docker exec "$target" sh -c 'command -v bash' >/dev/null 2>&1; then
            command_args=(bash)
        else
            command_args=(sh)
        fi
    fi

    # --- assemble -----------------------------------------------------------
    local cmd=(docker exec)
    local shown="${CDIM}docker${CR} ${CCY}${CB}exec${CR}"
    local flags_line="" item

    # -i always, -t only with a terminal on both ends.
    #
    # Unlike `docker compose exec`, plain `docker exec` keeps neither stdin nor
    # a TTY unless asked. -i is what lets `cat dump.sql | dx postgres psql`
    # reach psql at all — the first version of this gave -i only when stdin
    # was a TERMINAL, which is backwards: measured, a piped command arrived at
    # an empty stdin and nothing ran. -i on a closed stdin reads EOF and moves
    # on, so it costs nothing to always pass. -t is the one that must be
    # conditional: a TTY into a pipe is what makes `dx api ls | grep` misbehave.
    if [[ -t 0 && -t 1 ]]; then
        cmd+=(-it)
        shown+=" ${CYE}-it${CR}"
        flags_line+=" -it"
    else
        cmd+=(-i)
        shown+=" ${CYE}-i${CR}"
        flags_line+=" -i"
    fi
    if [[ -n "$user" ]]; then
        cmd+=(--user "$user")
        shown+=" ${CYE}--user ${user}${CR}"
        flags_line+=" --user $user"
    fi
    if [[ -n "$workdir" ]]; then
        cmd+=(--workdir "$workdir")
        shown+=" ${CYE}--workdir ${workdir}${CR}"
        flags_line+=" --workdir $workdir"
    fi

    cmd+=("$target")
    shown+=" ${CMA}${target}${CR}"

    for item in "${command_args[@]}"; do
        cmd+=("$item")
        shown+=" ${CWH}${item}${CR}"
    done

    # --- preview, then run --------------------------------------------------
    _render_preview "docker exec" "" "$target" "${flags_line# }" "$shown"

    "${cmd[@]}"
}

# Completion source: running containers only, since those are the only ones
# docker exec can enter.
_dx_candidates() {
    docker ps --format '{{.Names}}' 2>/dev/null | LC_ALL=C sort
}
