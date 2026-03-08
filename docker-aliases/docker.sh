#!/usr/bin/env bash
# Docker shortcuts — d() function and standalone docker aliases

# Main docker dispatcher
d() {
    case "$1" in
        # Basic
        ps|p)        shift; docker ps "$@" | docker-color-output ;;
        ps1|p1)      shift; docker ps --format "table {{.ID}}\t{{.Names}}\t{{.RunningFor}}\t{{.Status}}\t{{.Image}}" "$@" | docker-color-output ;;
        psp)         shift; docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" "$@" | docker-color-output ;;
        images|i)    shift; docker images "$@" | docker-color-output ;;

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
        help|h)      _docker_help ;;

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
