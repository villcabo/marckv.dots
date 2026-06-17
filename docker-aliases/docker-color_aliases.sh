#!/usr/bin/env bash
# ==============================================================
# Docker Color Aliases — loader
# ==============================================================
#
# Sources all docker-aliases modules in order and loads the
# appropriate completion system for the current shell.
#
# MAIN COMMANDS:
#   d [command]       Docker shortcuts (ps, logs, exec, etc.)
#   dc [command]      Docker Compose shortcuts (up, down, logs, etc.)
#   dcup [opts]       Docker Compose up (mirrors: dc up)
#   dq <pattern>      Quick exec in first matching container
#   dcq <pattern>     Quick exec in first matching service
#   dclt [opts]       Follow logs for services matching a pattern
#   dip [ip|pattern]  Find containers by IP, or list all with IPs
#   dstatus           Quick status overview
#   dcleanup          Full system cleanup
#   dhelp / dchelp    Show help
#
# CONFIGURATION:
#   DOCKER_COMPOSE_FILE — override default compose file path
#
# OPT-IN (no cargado por defecto):
#   dcpr <service>    Show git.properties — source extra/git-properties.sh
#
# ==============================================================

# Resolve the directory of this file (bash and zsh compatible)
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    _DOCKER_ALIASES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "$ZSH_VERSION" ]]; then
    _DOCKER_ALIASES_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
fi

if [[ -z "$_DOCKER_ALIASES_DIR" ]]; then
    echo "[docker-aliases] Error: could not determine script directory." >&2
    return 1
fi

# Load modules
source "$_DOCKER_ALIASES_DIR/_init.sh"
source "$_DOCKER_ALIASES_DIR/docker.sh"
source "$_DOCKER_ALIASES_DIR/compose-core.sh"
source "$_DOCKER_ALIASES_DIR/compose-modern.sh"
source "$_DOCKER_ALIASES_DIR/swarm.sh"
source "$_DOCKER_ALIASES_DIR/help.sh"

# Load shell-appropriate completions
if [[ -n "$ZSH_VERSION" ]]; then
    # Ensure zsh completion system is initialised
    if ! whence compdef &>/dev/null; then
        autoload -Uz compinit && compinit -u 2>/dev/null
    fi
    source "$_DOCKER_ALIASES_DIR/completion-zsh.sh"
else
    source "$_DOCKER_ALIASES_DIR/completion-bash.sh"
fi

unset _DOCKER_ALIASES_DIR
