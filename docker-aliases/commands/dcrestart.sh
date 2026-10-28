#!/usr/bin/env bash
# docker-aliases — dcrestart: docker compose restart, with a preview that says
# what a restart will NOT do.
#
# `docker compose restart` has three behaviours nobody expects, each measured:
#
#   1. It STARTS stopped services too. "Restart" does not sound like "bring up
#      what was down", and on a project with a service stopped on purpose that
#      is a surprise with consequences.
#   2. It does NOT apply a changed compose file. The container comes back with
#      the configuration it was created with: edit an environment variable,
#      restart, and the old value is still there. `up` is what applies it.
#   3. A service that was never created is skipped in silence, exit code 0.
#
# The preview names each of those for the services they apply to, before the
# confirmation — so a restart that will not do what you meant is caught while
# it is still a question.
#
# The compose-file change is detected exactly, not guessed: compose stamps
# every container with the hash of the service config it was created from
# (com.docker.compose.config-hash), and `config --hash` gives today's.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcrestart_help() {
    printf "${CB}${CCY}dcrestart${CR} — restart compose services, and say what a restart will not do\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcrestart${CR} [${CYE}flags${CR}] [${CMA}service-pattern${CR}...]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-f${CR} ${CMA}file${CR}            Compose file ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}file${CR}            Env file ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}profile${CR}         Profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-t${CR} ${CMA}seconds${CR}         Grace period before SIGKILL ${CI}(docker's default: 10)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}WHAT A RESTART DOES NOT DO${CR} ${CI}(the preview warns about each)${CR}\n"
    printf "  ${CYE}●${CR} It does not apply a changed compose file — ${CGR}dcup${CR} does.\n"
    printf "  ${CYE}●${CR} It starts stopped services too, not only running ones.\n"
    printf "  ${CYE}●${CR} It skips, silently, a service that was never created.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcrestart${CR}                Every service of the project\n"
    printf "  ${CGR}dcrestart api${CR}            Services matching 'api'\n"
    printf "  ${CGR}dcrestart -t 30 kafka${CR}    Give kafka 30 seconds to stop cleanly\n"
}

# ---------------------------------------------------------------------------
# dcrestart
# ---------------------------------------------------------------------------

dcrestart() {
    case "$1" in
        -h|--help) _dcrestart_help; return 0 ;;
    esac

    # --- expand clustered short flags: -tP → -t -P (as dcdown does) ---------
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
    local files=() env_files=() profiles=() patterns=()
    local profile_item timeout=""

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcrestart_help; return 0 ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcrestart "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcrestart "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            # Above -P on purpose: -P's inner `while read … done` is where
            # completion.bats stops reading this loop for flags.
            -t)
                shift
                [[ $# -eq 0 ]] && { _err dcrestart "-t requires a number of seconds"; return 1; }
                [[ "$1" =~ ^[0-9]+$ ]] || { _err dcrestart "-t takes whole seconds, not: $1"; return 1; }
                timeout="$1"
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcrestart "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dcrestart "unknown flag: $1  (try: dcrestart --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcrestart "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcrestart "compose file not found: $file"; return 1; }
        done
    fi
    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcrestart "env file not found: $file"; return 1; }
    done

    # The compose arguments every call below shares — ps, config and restart
    # must all be looking at the same project.
    local cargs=() item
    for item in "${files[@]}";     do cargs+=(-f "$item"); done
    for item in "${env_files[@]}"; do cargs+=(--env-file "$item"); done
    for item in "${profiles[@]}";  do cargs+=(--profile "$item"); done

    # --- declared services, and match ---------------------------------------
    local declared=() svc
    _get_all_compose_services_into --profiles "$(_join_commas "${profiles[@]}")" "${files[@]}" || _DA_R=""
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && declared+=("$svc")
    done <<< "$_DA_R"
    if [[ ${#declared[@]} -eq 0 ]]; then
        _err dcrestart "no services found in the compose file"
        return 1
    fi

    local matched=() pat
    if [[ ${#patterns[@]} -gt 0 ]]; then
        for svc in "${declared[@]}"; do
            for pat in "${patterns[@]}"; do
                if [[ "$svc" =~ $pat ]]; then matched+=("$svc"); break; fi
            done
        done
        if [[ ${#matched[@]} -eq 0 ]]; then
            _err dcrestart "no service matched: ${patterns[*]}"
            printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${declared[*]}" >&2
            return 1
        fi
    fi
    local affected=()
    if [[ ${#matched[@]} -gt 0 ]]; then affected=("${matched[@]}"); else affected=("${declared[@]}"); fi

    # --- what is out there, and what it was built from ----------------------
    # One ps for state and creation hash, one config for today's hashes. A
    # failure in either means "could not tell", and the warnings are skipped
    # rather than guessed.
    local tab=$'\t' line state hash psout cfgout probe_ok=true
    typeset -A state_of hash_of want_of
    if psout=$(docker compose "${cargs[@]}" ps -a --format '{{.Service}}\t{{.State}}\t{{.Label "com.docker.compose.config-hash"}}' 2>/dev/null); then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            svc="${line%%"$tab"*}"; line="${line#*"$tab"}"
            state="${line%%"$tab"*}"; hash="${line#*"$tab"}"
            # A scaled service has several containers; one running is enough
            # to call the service running.
            [[ "${state_of[$svc]:-}" == "running" ]] || state_of[$svc]="$state"
            hash_of[$svc]="$hash"
        done <<< "$psout"
    else
        probe_ok=false
    fi
    if cfgout=$(docker compose "${cargs[@]}" config --hash '*' 2>/dev/null); then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            want_of[${line%% *}]="${line#* }"
        done <<< "$cfgout"
    fi

    local missing=() stopped=() drifted=()
    if $probe_ok; then
        for svc in "${affected[@]}"; do
            if [[ -z "${state_of[$svc]:-}" ]]; then
                missing+=("$svc")
                continue
            fi
            [[ "${state_of[$svc]}" != "running" ]] && stopped+=("$svc")
            if [[ -n "${want_of[$svc]:-}" && -n "${hash_of[$svc]:-}" \
                  && "${want_of[$svc]}" != "${hash_of[$svc]}" ]]; then
                drifted+=("$svc")
            fi
        done
    fi

    # Nothing to restart at all: say it instead of running a silent no-op.
    if $probe_ok && [[ ${#missing[@]} -eq ${#affected[@]} ]]; then
        _err dcrestart "no container exists for: ${missing[*]}"
        printf "  ${CDIM}restart only acts on containers that exist — create them with${CR} ${CYE}dcup${CR}\n" >&2
        return 1
    fi

    # --- build the command --------------------------------------------------
    local cmd=(docker compose "${cargs[@]}")
    local shown="${CDIM}docker compose${CR}"
    for item in "${files[@]}";     do shown+=" ${CDIM}-f${CR} ${CWH}${item}${CR}"; done
    for item in "${env_files[@]}"; do shown+=" ${CDIM}--env-file${CR} ${CWH}${item}${CR}"; done
    for item in "${profiles[@]}";  do shown+=" ${CDIM}--profile${CR} ${CBL}${item}${CR}"; done
    cmd+=(restart)
    shown+=" ${CYE}${CB}restart${CR}"
    local flags_line=""
    if [[ -n "$timeout" ]]; then
        cmd+=(-t "$timeout")
        shown+=" ${CYE}-t${CR} ${CMA}${timeout}${CR}"
        flags_line="-t $timeout"
    fi
    for item in "${matched[@]}"; do
        cmd+=("$item")
        shown+=" ${CMA}${item}${CR}"
    done

    # --- preview ------------------------------------------------------------
    local files_display
    files_display=$(printf '%s\n' "${files[@]}")
    _render_preview "compose restart" "$files_display" "${affected[*]}" "$flags_line" "$shown"

    if ! $probe_ok; then
        _note "could not ask docker what is running — the warnings below are missing, not clear"
    fi
    if [[ ${#drifted[@]} -gt 0 ]]; then
        printf "  %s ${CYE}${CB}%s${CR} ${CYE}changed in the compose file since it was created —${CR}\n" \
            "$(_icon warn)" "${drifted[*]}" >&2
        printf "     ${CYE}a restart brings back the OLD config. To apply the change:${CR} ${CGR}dcup %s${CR}\n" \
            "${drifted[*]}" >&2
    fi
    if [[ ${#stopped[@]} -gt 0 ]]; then
        _note "${stopped[*]} is stopped — a restart starts it too"
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        _note "${missing[*]} has no container — a restart skips it in silence; dcup creates it"
    fi

    # --- confirm and run ----------------------------------------------------
    _confirm_operation "Continue?" "$(_action_color restart)" || {
        printf "  ${CB}${CYE}Cancelled${CR}\n" >&2
        return 1
    }
    "${cmd[@]}"
}
