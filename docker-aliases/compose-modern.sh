#!/usr/bin/env bash
# Docker Compose modern commands — compose v2-native features
#
# Provides: dcw (compose watch), dcrun (one-shot run --rm)
# Requires: _init.sh (colors, _get_compose_file, _render_preview,
#           _confirm_operation, _action_color) and compose-core.sh
#           (_dc_parse_args, _dc_resolve_file, _dc_build_extra_flags)

# ---------------------------------------------------------------------------
# dcw — docker compose watch
#
# Usage: dcw [-f <file>] [-P <profile>] [-y] [service...]
# ---------------------------------------------------------------------------
dcw() {
    case "$1" in
        -h|--help)
            echo -e "${CB}${CCY}dcw${CR} — Docker Compose Watch  ${CI}(docker compose watch)${CR}\n"

            echo -e "${CCY}USAGE${CR}"
            echo -e "  ${CB}dcw${CR} [${CYE}flags${CR}] [${CMA}service...${CR}]\n"

            echo -e "${CCY}FLAGS${CR}"
            echo -e "  ${CYE}-h${CR}, ${CYE}--help${CR}           Show this help"
            echo -e "  ${CYE}-f${CR} ${CMA}<file>${CR}             Use a specific compose file (repeatable)"
            echo -e "  ${CYE}-P${CR} ${CMA}<profile>${CR}          Compose profile (comma-separated for multiple)"
            echo -e "  ${CYE}-y${CR}, ${CYE}--yes${CR}            Skip confirmation prompt\n"

            echo -e "${CCY}EXAMPLES${CR}"
            echo -e "  ${CGR}dcw${CR}                        Watch all services"
            echo -e "  ${CGR}dcw api${CR}                    Watch only 'api' service"
            echo -e "  ${CGR}dcw -f dev.yml${CR}             Custom compose file"
            echo -e "  ${CGR}dcw -P dev api${CR}             Dev profile, watch 'api'"
            echo -e "  ${CGR}dcw -y${CR}                     Skip confirmation"
            return 0
            ;;
    esac

    _dc_parse_args "$@"
    _dc_resolve_file || return 1
    _dc_build_extra_flags

    local files_str="${_dc_resolved_files[*]}"
    local svc_str="${_dc_services[*]}"

    _render_preview "compose watch" "$files_str" "$svc_str" ""

    local skip_confirm=false
    [[ "$_dc_yes" == true ]] && skip_confirm=true

    if [[ "$skip_confirm" == false ]]; then
        local acol
        acol=$(_action_color "watch")
        _confirm_operation "Start watch?" "$acol" || { echo -e "${CB}${CYE}Cancelled${CR}"; return 1; }
    fi

    local cmd="docker compose${_dc_file_flags}${_dc_profile_flags} watch"
    [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
    eval "$cmd"
}

# ---------------------------------------------------------------------------
# dcrun — docker compose run --rm (one-shot ephemeral)
#
# Usage: dcrun [-P <profile>] [-e <env-file>] [--no-rm] <service> <cmd> [args...]
# ---------------------------------------------------------------------------
dcrun() {
    case "$1" in
        -h|--help)
            echo -e "${CB}${CCY}dcrun${CR} — Docker Compose One-shot Run  ${CI}(docker compose run --rm)${CR}\n"

            echo -e "${CCY}USAGE${CR}"
            echo -e "  ${CB}dcrun${CR} [${CYE}flags${CR}] ${CMA}<service> <cmd>${CR} [${CMA}args...${CR}]\n"

            echo -e "${CCY}FLAGS${CR}"
            echo -e "  ${CYE}-h${CR}, ${CYE}--help${CR}           Show this help"
            echo -e "  ${CYE}-P${CR} ${CMA}<profile>${CR}          Compose profile (comma-separated for multiple)"
            echo -e "  ${CYE}-e${CR} ${CMA}<env-file>${CR}         Env-file override (repeatable)"
            echo -e "  ${CYE}--no-rm${CR}              Keep container after run (default: remove)\n"

            echo -e "${CCY}EXAMPLES${CR}"
            echo -e "  ${CGR}dcrun api bash${CR}                    Open bash in ephemeral 'api' container"
            echo -e "  ${CGR}dcrun -P dev migrate npm run migrate${CR}  Run migrations in dev profile"
            echo -e "  ${CGR}dcrun -e .env.test api pytest${CR}     Run pytest with test env-file"
            echo -e "  ${CGR}dcrun --no-rm api bash${CR}             Keep container after exit"
            return 0
            ;;
    esac

    local _run_rm="--rm"
    local _run_profiles=()
    local _run_env_files=()
    local _run_file_flags=""
    local _run_files=()

    # Parse dcrun-specific flags before service/cmd
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-rm)
                _run_rm=""
                shift
                ;;
            -P)
                [[ -z "$2" ]] && { echo -e "${CRE}dcrun: -P requires a profile argument${CR}"; return 1; }
                IFS=',' read -ra _ptmp <<< "$2"
                for _p in "${_ptmp[@]}"; do _run_profiles+=("$_p"); done
                unset _ptmp _p
                shift 2
                ;;
            -e)
                [[ -z "$2" ]] && { echo -e "${CRE}dcrun: -e requires a file argument${CR}"; return 1; }
                _run_env_files+=("$2")
                shift 2
                ;;
            -f)
                [[ -z "$2" ]] && { echo -e "${CRE}dcrun: -f requires a file argument${CR}"; return 1; }
                _run_files+=("$2")
                shift 2
                ;;
            *)
                # First non-flag is the service name; rest are cmd+args
                break
                ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}dcrun: service name required${CR}"
        echo -e "  Usage: ${CB}dcrun${CR} [flags] ${CMA}<service> <cmd>${CR} [args...]"
        return 1
    fi

    local _run_service="$1"
    shift
    # remaining args are the command passed to the container (may be empty)

    # Resolve compose file
    local _run_resolved_file
    if [[ ${#_run_files[@]} -gt 0 ]]; then
        for f in "${_run_files[@]}"; do
            [[ ! -f "$f" ]] && { echo -e "${CRE}Compose file ${CB}$f${CR} not found"; return 1; }
            _run_file_flags+=" -f \"$f\""
        done
    else
        _run_resolved_file=$(_get_compose_file) || {
            echo -e "${CRE}No compose file found. Set ${CB}DOCKER_COMPOSE_FILE${CR} or add docker-compose.yml${CR}"
            return 1
        }
        _run_file_flags=" -f \"$_run_resolved_file\""
    fi

    # Build --profile flags
    local _run_profile_flags=""
    for _p in "${_run_profiles[@]}"; do _run_profile_flags+=" --profile $_p"; done
    unset _p

    # Build --env-file flags
    local _run_env_flags=""
    for _ef in "${_run_env_files[@]}"; do _run_env_flags+=" --env-file $_ef"; done
    unset _ef

    local cmd="docker compose${_run_file_flags}${_run_profile_flags} run ${_run_rm} ${_run_env_flags} ${_run_service}"
    [[ $# -gt 0 ]] && cmd+=" $*"
    eval "$cmd"
}
