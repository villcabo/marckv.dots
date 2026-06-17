#!/usr/bin/env bash
# Docker shortcuts — d() function and standalone docker aliases

# Main docker dispatcher
d() {
    case "$1" in
        # Basic
        ps|p)        shift; docker ps "$@" | docker-color-output ;;
        ps1|p1)      shift; docker ps --format "table {{.ID}}\t{{.Names}}\t{{.RunningFor}}\t{{.Status}}\t{{.Image}}" "$@" | docker-color-output ;;
        psp)         shift; docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" "$@" | docker-color-output ;;
        images|i)    shift; docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" "$@" | docker-color-output ;;

        # Stats and logs
        stats|s)     shift; docker stats "$@" | docker-color-output ;;
        s1)          shift; docker stats --no-stream "$@" | docker-color-output ;;
        logs|l)      shift; docker logs -f "$@" ;;
        l100)        shift; docker logs --tail 100 -f "$@" ;;
        l300)        shift; docker logs --tail 300 -f "$@" ;;
        l500)        shift; docker logs --tail 500 -f "$@" ;;

        # Exec
        x)           shift; docker exec -it "$@" ;;
        sh)          shift; docker exec -it "$1" sh ;;
        bash)        shift; docker exec -it "$1" bash ;;

        # Container control
        start)       shift; docker start "$@" ;;
        stop)        shift; docker stop "$@" ;;
        restart)     shift; docker restart "$@" ;;
        rm)          shift; docker rm "$@" ;;
        rmi)         shift; docker rmi "$@" ;;
        kill)        shift; docker kill "$@" ;;

        # Information
        inspect)     shift; docker inspect "$@" ;;
        top)         shift; docker top "$@" ;;

        # Cleanup
        prune|pr)    docker system prune -f ;;
        prunea|prf)  docker system prune -af ;;
        pruneima|pri) docker image prune -f ;;
        prunevol|prv) docker volume prune -f ;;
        prunenet|prn) docker network prune -f ;;

        # Help
        help|h|-h|--help) _docker_help ;;

        # Passthrough
        *)           docker "$@" ;;
    esac
}

# Standalone aliases for the most common docker subcommands
alias dps='d ps'
alias dps1='d ps1'
alias di='d images'
alias dl='d logs'
alias dlt='d l100'
alias dpri='d image prune'
alias ds='d stats'
alias dx='d x'

# Orden: helpers (_prefijo) primero, luego consumidores.
# Bash resuelve por orden de source — no romper sin revisar dependencias.

_dip_impl() {
    local search="$1"

    # Collect all running container IDs
    local container_ids
    container_ids=$(docker ps -q 2>/dev/null)
    if [[ -z "$container_ids" ]]; then
        echo -e "${CYE}No running containers found.${CR}"
        return 0
    fi

    local found=0

    while IFS= read -r cid; do
        local info
        info=$(docker inspect --format \
            '{{.Name}}|{{.State.Status}}|{{.Config.Image}}|{{range $n,$v := .NetworkSettings.Networks}}{{$n}}:{{$v.IPAddress}} {{end}}|{{range $p,$b := .NetworkSettings.Ports}}{{if $b}}{{$p}}->{{(index $b 0).HostPort}} {{end}}{{end}}' \
            "$cid" 2>/dev/null)

        local name cstatus image networks ports
        IFS='|' read -r name cstatus image networks ports <<< "$info"
        name="${name#/}"

        # Filter by search term if provided
        if [[ -n "$search" ]] && [[ "$networks" != *"$search"* ]]; then
            continue
        fi

        (( found++ ))

        # Color status
        local status_colored
        case "$cstatus" in
            running) status_colored="${CGR}${cstatus}${CR}" ;;
            exited)  status_colored="${CRE}${cstatus}${CR}" ;;
            *)       status_colored="${CYE}${cstatus}${CR}" ;;
        esac

        echo -e "${CB}${CWH}${name}${CR}"
        echo -e "    ${CCY}Status :${CR} ${status_colored}"
        echo -e "    ${CCY}Image  :${CR} ${image}"

        for net_ip in $networks; do
            local net="${net_ip%%:*}"
            local ip="${net_ip##*:}"
            [[ -z "$ip" || "$ip" == "invalid IP" ]] && continue
            echo -e "    ${CCY}Network:${CR} ${CMA}${net}${CR}  →  ${CB}${ip}${CR}"
        done

        [[ -n "${ports// }" ]] && echo -e "    ${CCY}Ports  :${CR} ${ports}"
        echo ""
    done <<< "$container_ids"

    if [[ $found -eq 0 ]]; then
        echo -e "${CYE}No containers found matching IP: ${CB}${search}${CR}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# dip — Find containers/services by IP address, or list all with their IPs
#
# Usage:
#   dip                  List all containers with IPs, networks, status, ports
#   dip <ip|pattern>     Find containers whose IP matches (exact or partial)
# ---------------------------------------------------------------------------
dip() {
    if [[ -n "$ZSH_VERSION" ]]; then
        # Filter out debug noise from zsh DEBUG traps (e.g. oh-my-zsh plugins)
        # that print raw variable assignments like `info=...` to stdout
        _dip_impl "$@" 2>/dev/null | grep -vE "^[a-zA-Z_][a-zA-Z0-9_]*="
    else
        _dip_impl "$@" 2>/dev/null
    fi
}
