#!/usr/bin/env bash
# docker-aliases v2 — entry point.
#
# Source this file to load every v2 command:
#     source /path/to/docker-aliases-v2/init.sh
#
# Load order matters: ui.sh defines the colors every other file prints with,
# compose.sh defines the lookups commands depend on, commands come last.

# ---------------------------------------------------------------------------
# Locate our own directory (bash and zsh disagree on how to ask)
# ---------------------------------------------------------------------------
# zsh's ${(%):-%x} is a syntax error to bash's parser, so it stays behind eval.

if [[ -n "${ZSH_VERSION:-}" ]]; then
    _DAV2_SOURCE=$(eval 'printf "%s" "${(%):-%x}"')
else
    _DAV2_SOURCE="${BASH_SOURCE[0]}"
fi

DOCKER_ALIASES_V2_DIR="$(cd "$(dirname "$_DAV2_SOURCE")" 2>/dev/null && pwd)"
unset _DAV2_SOURCE

if [[ -z "$DOCKER_ALIASES_V2_DIR" ]]; then
    printf 'docker-aliases v2: could not resolve install directory\n' >&2
    return 1 2>/dev/null || exit 1
fi

# ---------------------------------------------------------------------------
# Libraries
# ---------------------------------------------------------------------------

. "${DOCKER_ALIASES_V2_DIR}/lib/ui.sh"
. "${DOCKER_ALIASES_V2_DIR}/lib/compose.sh"

# ---------------------------------------------------------------------------
# Commands
#
# One file per command. Adding a command means dropping a file in commands/
# and a matching page in docs/ — nothing here needs to change.
# ---------------------------------------------------------------------------

for _dav2_cmd in "${DOCKER_ALIASES_V2_DIR}"/commands/*.sh; do
    [[ -f "$_dav2_cmd" ]] && . "$_dav2_cmd"
done
unset _dav2_cmd

# ---------------------------------------------------------------------------
# Completions
# ---------------------------------------------------------------------------

if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ -f "${DOCKER_ALIASES_V2_DIR}/completions/dcup.zsh" ]] && \
        . "${DOCKER_ALIASES_V2_DIR}/completions/dcup.zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    [[ -f "${DOCKER_ALIASES_V2_DIR}/completions/dcup.bash" ]] && \
        . "${DOCKER_ALIASES_V2_DIR}/completions/dcup.bash"
fi
