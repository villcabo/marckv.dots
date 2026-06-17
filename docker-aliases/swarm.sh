#!/usr/bin/env bash
# Docker Swarm shortcuts — dss* namespace
#
# Commands:
#   dss                  docker stack ls (colored)
#   dssps <stack>        docker stack ps <stack>
#   dssdeploy <stack>    docker stack deploy (auto-detect compose file)
#   dssrm <stack>        docker stack rm (destructive — preview + confirm)
#   dssvc                docker service ls
#   dssvcps <svc>        docker service ps <svc>
#   dssvcl <svc>         docker service logs --tail N -f
#   dssvcsc <svc>=<N>    docker service scale (preview + confirm)
#   dssnodes             docker node ls
#   dsstatus             overview: stacks + services + nodes
#
# Configuration:
#   DOCKER_ALIASES_LOG_LINES  default tail line count (default: 100)
#   DOCKER_ALIASES_AUTO_YES   skip confirmations when set to 1

# ---------------------------------------------------------------------------
# _color_pipe — pipe through docker-color-output if available
# ---------------------------------------------------------------------------
_color_pipe() {
    if command -v docker-color-output >/dev/null 2>&1; then
        docker-color-output
    else
        cat
    fi
}

# ---------------------------------------------------------------------------
# dss — docker stack ls
# ---------------------------------------------------------------------------
dss() {
    docker stack ls "$@" | _color_pipe
}

# ---------------------------------------------------------------------------
# dssps <stack> — docker stack ps <stack>
# ---------------------------------------------------------------------------
dssps() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssps <stack>${CR}"
        return 1
    fi
    docker stack ps "$@" | _color_pipe
}

# ---------------------------------------------------------------------------
# dssdeploy <stack> [-c <file>] [-y] — docker stack deploy
# ---------------------------------------------------------------------------
dssdeploy() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssdeploy <stack> [-c <file>] [-y]${CR}"
        return 1
    fi

    local stack="$1"
    shift

    local compose_file=""
    local auto_yes=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c)
                if [[ -n "$2" && "$2" != -* ]]; then
                    compose_file="$2"
                    shift 2
                else
                    echo -e "${CRE}dssdeploy: -c requires a file argument${CR}"
                    return 1
                fi
                ;;
            -y|--yes) auto_yes=true; shift ;;
            *) shift ;;
        esac
    done

    # Auto-detect compose file if -c not given
    if [[ -z "$compose_file" ]]; then
        compose_file=$(_get_compose_file 2>/dev/null) || {
            echo -e "${CRE}dssdeploy: no compose file found — use -c <file>${CR}"
            return 1
        }
    fi

    if [[ ! -f "$compose_file" ]]; then
        echo -e "${CRE}dssdeploy: compose file ${CB}$compose_file${CR} not found${CR}"
        return 1
    fi

    local action_color
    action_color=$(_action_color "swarm rm")   # blue per PRD §6

    _render_preview "swarm deploy" "$compose_file" "$stack" ""

    if [[ "$auto_yes" == false && "${DOCKER_ALIASES_AUTO_YES:-0}" != "1" ]]; then
        _confirm_operation "Deploy stack?" "$action_color" || { echo -e "  ${CYE}Aborted.${CR}"; return 1; }
    fi

    docker stack deploy -c "$compose_file" "$stack"
}

# ---------------------------------------------------------------------------
# dssrm <stack> [-y] — docker stack rm (destructive)
# ---------------------------------------------------------------------------
dssrm() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssrm <stack> [-y]${CR}"
        return 1
    fi

    local stack=""
    local auto_yes=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes) auto_yes=true; shift ;;
            *) stack="$1"; shift ;;
        esac
    done

    if [[ -z "$stack" ]]; then
        echo -e "${CRE}dssrm: stack name required${CR}"
        return 1
    fi

    local action_color
    action_color=$(_action_color "down")   # red for destructive

    _render_preview "swarm rm" "$stack" "" ""

    if [[ "$auto_yes" == false && "${DOCKER_ALIASES_AUTO_YES:-0}" != "1" ]]; then
        _confirm_operation "Remove stack?" "$action_color" || { echo -e "  ${CYE}Aborted.${CR}"; return 1; }
    fi

    docker stack rm "$stack"
}

# ---------------------------------------------------------------------------
# dssvc — docker service ls
# ---------------------------------------------------------------------------
dssvc() {
    docker service ls "$@" | _color_pipe
}

# ---------------------------------------------------------------------------
# dssvcps <svc> — docker service ps <svc>
# ---------------------------------------------------------------------------
dssvcps() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssvcps <service>${CR}"
        return 1
    fi
    docker service ps "$@" | _color_pipe
}

# ---------------------------------------------------------------------------
# dssvcl <svc> [-n <N>] — docker service logs --tail N -f
# ---------------------------------------------------------------------------
dssvcl() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssvcl <service> [-n <N>]${CR}"
        return 1
    fi

    local svc=""
    local tail_lines="${DOCKER_ALIASES_LOG_LINES:-100}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    tail_lines="$2"
                    shift 2
                else
                    echo -e "${CRE}dssvcl: -n requires a number${CR}"
                    return 1
                fi
                ;;
            *) svc="$1"; shift ;;
        esac
    done

    if [[ -z "$svc" ]]; then
        echo -e "${CRE}dssvcl: service name required${CR}"
        return 1
    fi

    docker service logs --tail "$tail_lines" -f "$svc"
}

# ---------------------------------------------------------------------------
# dssvcsc <svc>=<N> [-y] — docker service scale
# ---------------------------------------------------------------------------
dssvcsc() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CRE}Usage: dssvcsc <service>=<N> [-y]${CR}"
        return 1
    fi

    local scale_arg=""
    local auto_yes=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes) auto_yes=true; shift ;;
            *) scale_arg="$1"; shift ;;
        esac
    done

    if [[ -z "$scale_arg" || "$scale_arg" != *=* ]]; then
        echo -e "${CRE}dssvcsc: expected format <service>=<N> (e.g. api=3)${CR}"
        return 1
    fi

    local svc="${scale_arg%%=*}"
    local replicas="${scale_arg##*=}"

    local action_color
    action_color=$(_action_color "scale")   # blue per _action_color

    _render_preview "service scale" "$svc" "${replicas} replica(s)" ""

    if [[ "$auto_yes" == false && "${DOCKER_ALIASES_AUTO_YES:-0}" != "1" ]]; then
        _confirm_operation "Scale service?" "$action_color" || { echo -e "  ${CYE}Aborted.${CR}"; return 1; }
    fi

    docker service scale "${scale_arg}"
}

# ---------------------------------------------------------------------------
# dssnodes — docker node ls
# ---------------------------------------------------------------------------
dssnodes() {
    docker node ls "$@" | _color_pipe
}

# ---------------------------------------------------------------------------
# dsstatus — overview: stacks + services + nodes
# ---------------------------------------------------------------------------
dsstatus() {
    echo -e "\n${CB}${CCY}Docker Swarm Status${CR}\n"

    echo -e "${CCY}STACKS${CR}"
    docker stack ls 2>/dev/null || echo -e "  ${CYE}(not in swarm or no stacks)${CR}"

    echo -e "\n${CCY}SERVICES${CR}"
    docker service ls 2>/dev/null || echo -e "  ${CYE}(no services)${CR}"

    echo -e "\n${CCY}NODES${CR}"
    docker node ls 2>/dev/null || echo -e "  ${CYE}(not a swarm manager)${CR}"
}
