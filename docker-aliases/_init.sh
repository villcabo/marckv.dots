#!/usr/bin/env bash
# Shared colors, styles, and utility functions for docker-aliases

# Color variables
CR="\033[0m"        # COLOR_RESET
CRE="\033[1;31m"    # COLOR_RED
CGR="\033[1;32m"    # COLOR_GREEN
CYE="\033[1;33m"    # COLOR_YELLOW
CBL="\033[1;34m"    # COLOR_BLUE
CMA="\033[1;35m"    # COLOR_MAGENTA
CCY="\033[1;36m"    # COLOR_CYAN
CWH="\033[1;37m"    # COLOR_WHITE

# Text styles
CB="\033[1m"        # BOLD
CI="\033[3m"        # ITALIC
CU="\033[4m"        # UNDERLINE

# Compose file detection
# Priority: $DOCKER_COMPOSE_FILE env var > .env setting > docker-compose.yml > docker-compose.yaml
_get_compose_file() {
    if [[ -n "$DOCKER_COMPOSE_FILE" && -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "$DOCKER_COMPOSE_FILE"
        return 0
    fi

    if [[ -f ".env" ]] && grep -q "^DOCKER_COMPOSE_FILE=" .env; then
        local env_file
        env_file=$(grep "^DOCKER_COMPOSE_FILE=" .env | cut -d'=' -f2)
        if [[ -f "$env_file" ]]; then
            echo "$env_file"
            return 0
        fi
    fi

    if [[ -f docker-compose.yml ]]; then
        echo "docker-compose.yml"
        return 0
    elif [[ -f docker-compose.yaml ]]; then
        echo "docker-compose.yaml"
        return 0
    fi

    return 1
}

# Interactive confirmation — returns 0 (yes) or 1 (no/cancel)
_confirm_operation() {
    local message="${1:-Continue with operation?}"
    printf "${CB}${CRE}${message} [yes/N]: ${CR}"
    read -r response
    [[ "$response" == "yes" ]]
}

# Completion helpers — shared between bash and zsh completion modules
_get_docker_containers() {
    docker ps --format "{{.Names}}" 2>/dev/null
}

_get_compose_services() {
    local compose_file
    compose_file=$(_get_compose_file)
    if [[ $? -eq 0 ]]; then
        docker compose -f "$compose_file" config --services 2>/dev/null
    fi
}
