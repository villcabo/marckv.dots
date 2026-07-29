#!/usr/bin/env bash
# docker-aliases — entry point.
#
# Source this file to load every v2 command:
#     source ~/.marckv.dots/docker-aliases/init.sh
#
# Load order matters: ui.sh defines the colors every other file prints with,
# compose.sh defines the lookups commands depend on, commands come last.

# ---------------------------------------------------------------------------
# Locate our own directory (bash and zsh disagree on how to ask)
# ---------------------------------------------------------------------------
# zsh's ${(%):-%x} is a syntax error to bash's parser, so it stays behind eval.

if [[ -n "${ZSH_VERSION:-}" ]]; then
    _DA_SOURCE=$(eval 'printf "%s" "${(%):-%x}"')
else
    _DA_SOURCE="${BASH_SOURCE[0]}"
fi

DOCKER_ALIASES_DIR="$(cd "$(dirname "$_DA_SOURCE")" 2>/dev/null && pwd)"
unset _DA_SOURCE

if [[ -z "$DOCKER_ALIASES_DIR" ]]; then
    printf 'docker-aliases v2: could not resolve install directory\n' >&2
    return 1 2>/dev/null || exit 1
fi

# ---------------------------------------------------------------------------
# Libraries
# ---------------------------------------------------------------------------

. "${DOCKER_ALIASES_DIR}/lib/ui.sh"
. "${DOCKER_ALIASES_DIR}/lib/compose.sh"

# ---------------------------------------------------------------------------
# Commands
#
# One file per command. Adding a command means dropping a file in commands/
# and a matching page in docs/ — nothing here needs to change.
# ---------------------------------------------------------------------------

for _da_cmd in "${DOCKER_ALIASES_DIR}"/commands/*.sh; do
    [[ -f "$_da_cmd" ]] && . "$_da_cmd"
done
unset _da_cmd

# ---------------------------------------------------------------------------
# Completions
# ---------------------------------------------------------------------------

# Globbed like commands, so a new command only needs its files dropped in.
_da_comp_ext=""
[[ -n "${ZSH_VERSION:-}" ]]  && _da_comp_ext="zsh"
[[ -n "${BASH_VERSION:-}" ]] && _da_comp_ext="bash"

if [[ -n "$_da_comp_ext" ]]; then
    for _da_comp in "${DOCKER_ALIASES_DIR}"/completions/*."${_da_comp_ext}"; do
        [[ -f "$_da_comp" ]] && . "$_da_comp"
    done
    unset _da_comp
fi
unset _da_comp_ext
