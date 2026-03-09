#!/usr/bin/env bash
# Docker Compose shortcuts — dc(), dcup(), smart functions, and compose aliases

# ---------------------------------------------------------------------------
# Internal helper: parse -f <file> + other flags + service list from args.
# Sets variables: _dc_file, _dc_opts, _dc_show_logs, _dc_services[]
# ---------------------------------------------------------------------------
_dc_parse_args() {
    _dc_file=""
    _dc_opts=""
    _dc_show_logs=false
    _dc_services=()

    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-f" && -n "$2" && "$2" != -* ]]; then
            _dc_file="$2"
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
_dc_resolve_file() {
    local custom="$1"
    if [[ -n "$custom" ]]; then
        if [[ ! -f "$custom" ]]; then
            echo -e "${CRE}Compose file ${CB}$custom${CR} not found ❌"
            return 1
        fi
        _dc_resolved_file="$custom"
    else
        _dc_resolved_file=$(_get_compose_file) || {
            echo -e "${CRE}No compose file found. Set ${CB}DOCKER_COMPOSE_FILE${CR} or add docker-compose.yml ❌"
            return 1
        }
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
            _dc_resolve_file "$_dc_file" || return 1
            compose_file="$_dc_resolved_file"

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CYE}DOCKER COMPOSE UP${CR} 🐳"
            echo -e "${CCY}Action:${CR} Start services"
            echo -e "${CCY}Compose file:${CR} ${CB}$compose_file${CR}"
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            [[ "$_dc_show_logs" == true ]] && echo -e "${CCY}After up:${CR} ${CB}Show logs${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose -f \"$compose_file\" up -d${_dc_opts}"
            [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
            if eval "$cmd"; then
                if [[ "$_dc_show_logs" == true ]]; then
                    if [[ ${#_dc_services[@]} -gt 0 ]]; then
                        docker compose -f "$compose_file" logs -f "${_dc_services[@]}"
                    else
                        docker compose -f "$compose_file" logs -f
                    fi
                fi
            fi
            ;;

        # ── up + logs immediately ───────────────────────────────────────────
        ul)
            shift
            docker compose -f "$compose_file" up -d "$@" && docker compose -f "$compose_file" logs -f "$@"
            ;;

        # ── status ──────────────────────────────────────────────────────────
        ps|p)   shift; docker compose -f "$compose_file" ps "$@" | docker-color-output ;;
        ps1|p1) shift; docker compose -f "$compose_file" ps --format "table {{.Name}}\t{{.Service}}\t{{.RunningFor}}\t{{.Status}}\t{{.Image}}" "$@" | docker-color-output ;;
        psp)    shift; docker compose -f "$compose_file" ps --format "table {{.Name}}\t{{.Service}}\t{{.Ports}}" "$@" | docker-color-output ;;

        # ── logs & stats ────────────────────────────────────────────────────
        stats|s) shift; docker compose -f "$compose_file" stats "$@" | docker-color-output ;;
        s1)      shift; docker compose -f "$compose_file" stats --no-stream "$@" | docker-color-output ;;
        logs|l)  shift; docker compose -f "$compose_file" logs --tail 100 -f "$@" ;;
        l100)    shift; docker compose -f "$compose_file" logs --tail 100 -f "$@" ;;
        l300)    shift; docker compose -f "$compose_file" logs --tail 300 -f "$@" ;;
        l500)    shift; docker compose -f "$compose_file" logs --tail 500 -f "$@" ;;

        # ── exec ────────────────────────────────────────────────────────────
        x)    shift; docker compose -f "$compose_file" exec "$@" ;;
        sh)   shift; docker compose -f "$compose_file" exec "$1" sh ;;
        bash) shift; docker compose -f "$compose_file" exec "$1" bash ;;

        # ── down ────────────────────────────────────────────────────────────
        down|d)
            shift
            _dc_parse_args "$@"
            _dc_resolve_file "$_dc_file" || return 1
            compose_file="$_dc_resolved_file"

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CRE}DOCKER COMPOSE DOWN${CR} 🛑"
            echo -e "${CCY}Action:${CR} Stop and remove services"
            echo -e "${CCY}Compose file:${CR} ${CB}$compose_file${CR}"
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose -f \"$compose_file\" down${_dc_opts}"
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
            _dc_resolve_file "$_dc_file" || return 1
            compose_file="$_dc_resolved_file"

            local all_services target_services
            all_services=($(_get_compose_services))
            [[ ${#_dc_services[@]} -gt 0 ]] && target_services=("${_dc_services[@]}") || target_services=("${all_services[@]}")

            echo -e "${CB}${CCY}DOCKER COMPOSE BUILD${CR} 🔨"
            echo -e "${CCY}Action:${CR} Build services"
            echo -e "${CCY}Compose file:${CR} ${CB}$compose_file${CR}"
            [[ -n "$_dc_opts" ]] && echo -e "${CCY}Options:${CR}${CB}$_dc_opts${CR}"
            echo -e "${CCY}Affected services:${CR} ${CB}${CGR}${target_services[*]}${CR}"
            echo ""

            _confirm_operation "Continue with operation?" || { echo -e "${CB}${CYE}Cancelled${CR} ⚠️"; return 1; }

            local cmd="docker compose -f \"$compose_file\" build${_dc_opts}"
            [[ ${#_dc_services[@]} -gt 0 ]] && cmd+=" ${_dc_services[*]}"
            eval "$cmd"
            ;;

        # ── default compose file management ─────────────────────────────────
        default)
            shift
            if [[ -z "$1" ]]; then
                if [[ -f ".env" ]] && grep -q "^DOCKER_COMPOSE_FILE=" .env; then
                    local current_file
                    current_file=$(grep "^DOCKER_COMPOSE_FILE=" .env | cut -d'=' -f2)
                    echo -e "${CGR}Current default: ${CB}$current_file${CR} 📋"
                else
                    echo -e "${CYE}No default compose file set${CR} ⚠️"
                fi
            elif [[ "$1" == "remove" || "$1" == "rm" ]]; then
                if [[ -f ".env" ]] && grep -q "^DOCKER_COMPOSE_FILE=" .env; then
                    sed -i '/^DOCKER_COMPOSE_FILE=/d' .env
                    echo -e "${CGR}Default compose file removed${CR} ✅"
                else
                    echo -e "${CYE}No default compose file set${CR} ⚠️"
                fi
            else
                local file="$1"
                [[ ! -f "$file" ]] && echo -e "${CRE}File ${CB}$file${CR} not found ❌" && return 1
                [[ -f ".env" ]] && sed -i '/^DOCKER_COMPOSE_FILE=/d' .env
                echo "DOCKER_COMPOSE_FILE=$file" >> .env
                echo -e "${CGR}Default compose file set to: ${CB}$file${CR} ✅"
            fi
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

            if [[ -f ".env" ]] && grep -q "^DOCKER_COMPOSE_FILE=" .env; then
                local default_file
                default_file=$(grep "^DOCKER_COMPOSE_FILE=" .env | cut -d'=' -f2)
                echo -e "${CCY}Default setting:${CR} ${CB}DOCKER_COMPOSE_FILE=$default_file${CR}"
            else
                echo -e "${CCY}Default setting:${CR} ${CYE}Not configured${CR}"
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
            echo -e "  ${CYE}-f${CR} ${CMA}<file>${CR}             Use a specific compose file"

            echo -e "\n${CCY}EXAMPLES${CR}"
            echo -e "  ${CGR}dcup${CR}                        Start all services"
            echo -e "  ${CGR}dcup api worker${CR}             Start specific services only"
            echo -e "  ${CGR}dcup -r${CR}                     Force recreate all services"
            echo -e "  ${CGR}dcup -l${CR}                     Start and follow logs"
            echo -e "  ${CGR}dcup -rl${CR}                    Force recreate + follow logs"
            echo -e "  ${CGR}dcup -r -l${CR}                  Same as above (flags can be split)"
            echo -e "  ${CGR}dcup -pbl${CR}                   Pull + build + follow logs"
            echo -e "  ${CGR}dcup -rb api${CR}                Recreate + build for 'api' service"
            echo -e "  ${CGR}dcup -f prod.yml -r${CR}         Custom compose file + recreate"
            ;;
        *)
            dc up "$@"
            ;;
    esac
}

# Compose aliases
alias dcps='dc ps'
alias dcps1='dc ps1'
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

# Full system cleanup
dcleanup() {
    echo -e "${CYE}${CB}Cleaning Docker...${CR} 🧹"
    docker system prune -f
    docker network prune -f
    echo -e "${CGR}${CB}Cleanup completed${CR} ✅"
}
