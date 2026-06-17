#!/usr/bin/env bash
# Docker Compose shortcuts — dc(), dcup(), smart functions, and compose aliases
#
# Orden: helpers (_prefijo) primero, luego consumidores.
# Bash resuelve por orden de source — no romper sin revisar dependencias.

# ---------------------------------------------------------------------------
# Internal helper: parse -f <file> + other flags + service list from args.
# Sets variables: _dc_file, _dc_opts, _dc_show_logs, _dc_services[]
# ---------------------------------------------------------------------------
_dc_parse_args() {
    _dc_files=()
    _dc_opts=""
    _dc_show_logs=false
    _dc_services=()

    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-f" && -n "$2" && "$2" != -* ]]; then
            _dc_files+=("$2")
            shift 2
        elif [[ "$1" == -* ]]; then
            local flags="${1#-}"
            local i=0
            while (( i < ${#flags} )); do
                case "${flags:$i:1}" in
                    r) _dc_opts+=" --force-recreate" ;;
                    p) _dc_opts+=" --pull always" ;;
                    b) _dc_opts+=" --build" ;;
                    l) _dc_show_logs=true ;;
                    *) _dc_opts+=" -${flags:$i:1}" ;;
                esac
                (( i++ ))
            done
            shift
        else
            _dc_services+=("$1")
            shift
        fi
    done
}

# ---------------------------------------------------------------------------
# Internal helper: resolve compose file, printing an error if not found.
# Usage: _dc_resolve_file [custom_file]
# Sets: _dc_resolved_file
# ---------------------------------------------------------------------------
# Resolve compose files from _dc_files array or auto-detect.
# Sets: _dc_resolved_files[] and _dc_file_flags (for command building)
_dc_resolve_file() {
    _dc_resolved_files=()
    _dc_file_flags=""

    if [[ ${#_dc_files[@]} -gt 0 ]]; then
        for f in "${_dc_files[@]}"; do
            if [[ ! -f "$f" ]]; then
                echo -e "${CRE}Compose file ${CB}$f${CR} not found ❌"
                return 1
            fi
            _dc_resolved_files+=("$f")
            _dc_file_flags+=" -f \"$f\""
        done
    else
        local detected
        detected=$(_get_compose_file) || {
            echo -e "${CRE}No compose file found. Set ${CB}DOCKER_COMPOSE_FILE${CR} or add docker-compose.yml ❌"
            return 1
        }
        _dc_resolved_files+=("$detected")
        _dc_file_flags=" -f \"$detected\""
    fi
}

# ---------------------------------------------------------------------------
# Main docker compose dispatcher
# ---------------------------------------------------------------------------
dc() {
    # Handle help before compose file lookup so it works from any directory
    case "$1" in
        -h|--help|help|h|"") _compose_help; return 0 ;;
    esac

    local compose_file
    compose_file=$(_get_compose_file) || {
        echo -e "${CRE}No compose file found. Set ${CB}DOCKER_COMPOSE_FILE${CR} or add docker-compose.yml ❌"
        return 1
    }

    case "$1" in
        # ── up ──────────────────────────────────────────────────────────────
        up|u)
            shift
            _dc_parse_args "$@"
            _dc_resolve_file || return 1

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CYE}DOCKER COMPOSE UP${CR} 🐳"
            echo -e "${CCY}Action:${CR} Start services"
            for f in "${_dc_resolved_files[@]}"; do
                echo -e "${CCY}Compose file:${CR} ${CB}$f${CR}"
            done
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            [[ "$_dc_show_logs" == true ]] && echo -e "${CCY}After up:${CR} ${CB}Show logs${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose${_dc_file_flags} up -d${_dc_opts}"
            [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
            if eval "$cmd"; then
                if [[ "$_dc_show_logs" == true ]]; then
                    local log_cmd="docker compose${_dc_file_flags} logs -f"
                    [[ ${#_dc_services[@]} -gt 0 ]] && log_cmd+=" ${_dc_services[*]}"
                    eval "$log_cmd"
                fi
            fi
            ;;

        # ── status ──────────────────────────────────────────────────────────
        ps|p)
            shift
            local fmt_flag=""
            local remaining_args=()
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -c) fmt_flag="compact" ;;
                    -p) fmt_flag="ports" ;;
                    *)  remaining_args+=("$1") ;;
                esac
                shift
            done
            case "$fmt_flag" in
                compact) docker compose -f "$compose_file" ps --format "table {{.Name}}\t{{.Service}}\t{{.RunningFor}}\t{{.Status}}\t{{.Image}}" "${remaining_args[@]}" | docker-color-output ;;
                ports)   docker compose -f "$compose_file" ps --format "table {{.Name}}\t{{.Service}}\t{{.Ports}}" "${remaining_args[@]}" | docker-color-output ;;
                *)       docker compose -f "$compose_file" ps "${remaining_args[@]}" | docker-color-output ;;
            esac
            ;;

        # ── logs & stats ────────────────────────────────────────────────────
        stats|s) shift; docker compose -f "$compose_file" stats "$@" | docker-color-output ;;
        logs|l)  shift; docker compose -f "$compose_file" logs --tail 100 -f "$@" ;;

        # ── exec ────────────────────────────────────────────────────────────
        x)    shift; docker compose -f "$compose_file" exec "$@" ;;
        sh)   shift; docker compose -f "$compose_file" exec "$1" sh ;;
        bash) shift; docker compose -f "$compose_file" exec "$1" bash ;;

        # ── down ────────────────────────────────────────────────────────────
        down|d)
            shift
            _dc_parse_args "$@"
            _dc_resolve_file || return 1

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CRE}DOCKER COMPOSE DOWN${CR} 🛑"
            echo -e "${CCY}Action:${CR} Stop and remove services"
            for f in "${_dc_resolved_files[@]}"; do
                echo -e "${CCY}Compose file:${CR} ${CB}$f${CR}"
            done
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose${_dc_file_flags} down${_dc_opts}"
            [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
            eval "$cmd"
            ;;

        # ── simple control ──────────────────────────────────────────────────
        start)   shift; docker compose -f "$compose_file" start "$@" ;;
        stop)    shift; docker compose -f "$compose_file" stop "$@" ;;
        restart) shift; docker compose -f "$compose_file" restart "$@" ;;
        pull)    shift; docker compose -f "$compose_file" pull "$@" ;;

        # ── build ───────────────────────────────────────────────────────────
        build|b)
            shift
            _dc_parse_args "$@"
            _dc_resolve_file || return 1

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CCY}DOCKER COMPOSE BUILD${CR} 🔨"
            echo -e "${CCY}Action:${CR} Build services"
            for f in "${_dc_resolved_files[@]}"; do
                echo -e "${CCY}Compose file:${CR} ${CB}$f${CR}"
            done
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose${_dc_file_flags} build${_dc_opts}"
            [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
            eval "$cmd"
            ;;

        # ── info ────────────────────────────────────────────────────────────
        info)
            echo -e "${CB}${CCY}=== DOCKER COMPOSE CONFIGURATION ===${CR}"
            echo -e "${CCY}Working directory:${CR} ${CB}$(pwd)${CR}"

            local info_file
            info_file=$(_get_compose_file)
            if [[ $? -eq 0 ]]; then
                echo -e "${CCY}Active compose file:${CR} ${CB}${CGR}$info_file${CR}"
            else
                echo -e "${CCY}Active compose file:${CR} ${CRE}None found${CR}"
            fi

            if [[ -n "$DOCKER_COMPOSE_FILE" ]]; then
                echo -e "${CCY}DOCKER_COMPOSE_FILE:${CR} ${CB}$DOCKER_COMPOSE_FILE${CR}"
            else
                echo -e "${CCY}DOCKER_COMPOSE_FILE:${CR} ${CYE}Not set${CR}"
            fi

            echo -e "${CCY}Available compose files:${CR}"
            local found_files=false
            for file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml *.yml *.yaml; do
                if [[ -f "$file" ]]; then
                    echo -e "  - ${CB}$file${CR}"
                    found_files=true
                fi
            done
            [[ "$found_files" == false ]] && echo -e "  ${CYE}No compose files found${CR}"
            ;;

        # ── passthrough ─────────────────────────────────────────────────────
        *) docker compose -f "$compose_file" "$@" ;;
    esac
}

# Standalone dcup (mirrors dc up with the same flag parsing)
dcup() {
    case "$1" in
        -h|--help)
            echo -e "${CB}${CCY}dcup${CR} — Docker Compose Up shortcut  ${CI}(mirrors: dc up)${CR}\n"

            echo -e "${CCY}USAGE${CR}"
            echo -e "  ${CB}dcup${CR} [${CYE}flags${CR}] [${CMA}service...${CR}]\n"

            echo -e "${CCY}FLAGS${CR}"
            echo -e "  ${CYE}-h${CR}, ${CYE}--help${CR}           Show this help"
            echo -e "  ${CYE}-p${CR}                   Pull images before starting"
            echo -e "  ${CYE}-b${CR}                   Build images before starting"
            echo -e "  ${CYE}-r${CR}                   Force recreate containers"
            echo -e "  ${CYE}-l${CR}                   Follow logs after up"
            echo -e "  ${CYE}-f${CR} ${CMA}<file>${CR}             Use a specific compose file (repeatable)"

            echo -e "\n${CCY}EXAMPLES${CR}"
            echo -e "  ${CGR}dcup${CR}                                   Start all services"
            echo -e "  ${CGR}dcup api worker${CR}                        Start specific services only"
            echo -e "  ${CGR}dcup -r${CR}                                Force recreate all services"
            echo -e "  ${CGR}dcup -l${CR}                                Start and follow logs"
            echo -e "  ${CGR}dcup -rl${CR}                               Force recreate + follow logs"
            echo -e "  ${CGR}dcup -pbl${CR}                              Pull + build + follow logs"
            echo -e "  ${CGR}dcup -rb api${CR}                           Recreate + build for 'api' service"
            echo -e "  ${CGR}dcup -f prod.yml -r${CR}                    Custom compose file + recreate"
            echo -e "  ${CGR}dcup -f app.yml -f app.override.yml${CR}    Multiple compose files"
            ;;
        *)
            dc up "$@"
            ;;
    esac
}

# Compose aliases
alias dcps='dc ps'
alias dcl='dc logs'
alias dcdown='dc down'
alias dcs='dc stats'
alias dcx='dc x'

# ---------------------------------------------------------------------------
# Smart functions
# ---------------------------------------------------------------------------

# Quick exec in the first container whose name matches a pattern
dq() {
    if [[ -z "$1" ]]; then
        echo -e "${CRE}Usage: dq <pattern> <cmd> [args...]${CR}"
        return 1
    fi
    local container
    container=$(docker ps --format "{{.Names}}" | grep -i "$1" | head -1)
    if [[ -n "$container" ]]; then
        echo -e "${CGR}Executing in: ${CB}$container${CR} 🚀"
        shift
        docker exec -it "$container" "$@"
    else
        echo -e "${CRE}No container found matching: ${CB}$1${CR} ❌"
        return 1
    fi
}

# Quick exec in the first compose service whose name matches a pattern
dcq() {
    if [[ -z "$1" ]]; then
        echo -e "${CRE}Usage: dcq <pattern> <cmd> [args...]${CR}"
        return 1
    fi
    local compose_file
    compose_file=$(_get_compose_file) || {
        echo -e "${CRE}No compose file found ❌"
        return 1
    }
    local service
    service=$(docker compose -f "$compose_file" ps --services | grep -i "$1" | head -1)
    if [[ -n "$service" ]]; then
        echo -e "${CGR}Executing in service: ${CB}$service${CR} 🚀"
        shift
        docker compose -f "$compose_file" exec "$service" "$@"
    else
        echo -e "${CRE}No service found matching: ${CB}$1${CR} ❌"
        return 1
    fi
}

# Quick status overview
dstatus() {
    echo -e "${CB}${CCY}=== CONTAINERS ===${CR}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | docker-color-output

    local compose_file
    compose_file=$(_get_compose_file)
    if [[ $? -eq 0 ]]; then
        echo -e "\n${CB}${CCY}=== COMPOSE SERVICES ===${CR}"
        docker compose -f "$compose_file" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" | docker-color-output
    fi
}

# ---------------------------------------------------------------------------
# dclt — Follow logs for services matching one or more patterns
#
# Usage: dclt [options] [pattern...]
#   -n <N>        Tail N lines (default: ${DOCKER_ALIASES_LOG_LINES:-100})
#   -r, --regex   Match patterns as regex (default: literal)
#   -w, --wait    Ask for confirmation before showing logs
# ---------------------------------------------------------------------------
dclt() {
    local regex_mode=false
    local ask_confirm=false
    local patterns=()
    local tail_lines="${DOCKER_ALIASES_LOG_LINES:-100}"

    local compose_file
    compose_file=$(_get_compose_file) || {
        echo -e "${CRE}No compose file found ❌"
        return 1
    }

    # Parse flags and patterns
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --* ]]; then
            case "$1" in
                --regex) regex_mode=true ;;
                --wait)  ask_confirm=true ;;
                *) echo "❌ Unknown option: $1" >&2; return 1 ;;
            esac
        elif [[ "$1" == "-n" ]]; then
            shift
            tail_lines="$1"
        elif [[ "$1" == -* && "$1" != "-" ]]; then
            local flags="${1#-}"
            local i=0
            while (( i < ${#flags} )); do
                case "${flags:$i:1}" in
                    r) regex_mode=true ;;
                    w) ask_confirm=true ;;
                    *) echo "❌ Unknown option: -${flags:$i:1}" >&2; return 1 ;;
                esac
                (( i++ ))
            done
        else
            patterns+=("$1")
        fi
        shift
    done

    local services matched_services unique_services
    services=($(_get_compose_services))
    if [[ ${#services[@]} -eq 0 ]]; then
        echo -e "${CRE}No compose services found ❌"
        return 1
    fi

    # Match services against patterns
    matched_services=()
    if [[ ${#patterns[@]} -gt 0 ]]; then
        if [[ "$regex_mode" == true ]]; then
            for svc in "${services[@]}"; do
                for pat in "${patterns[@]}"; do
                    if [[ "$svc" =~ $pat ]]; then
                        matched_services+=("$svc")
                        break
                    fi
                done
            done
        else
            for pat in "${patterns[@]}"; do
                for svc in "${services[@]}"; do
                    [[ "$svc" == "$pat" ]] && matched_services+=("$svc")
                done
            done
        fi
    else
        matched_services=("${services[@]}")
    fi

    # Deduplicate (bash/zsh compatible)
    unique_services=()
    for svc in "${matched_services[@]}"; do
        local found=false
        for usvc in "${unique_services[@]}"; do
            [[ "$svc" == "$usvc" ]] && found=true && break
        done
        [[ "$found" == false ]] && unique_services+=("$svc")
    done

    if [[ ${#unique_services[@]} -eq 0 ]]; then
        echo -e "${CRE}No services matched: ${CB}'${patterns[*]}'${CR} ❌"
        return 1
    fi

    echo -e "${CGR}Services: ${CB}${unique_services[*]}${CR} 📋"
    if [[ "$ask_confirm" == true ]]; then
        _confirm_operation "Show logs for these services?" || return 0
    fi

    docker compose -f "$compose_file" logs --tail "$tail_lines" -f "${unique_services[@]}"
}
