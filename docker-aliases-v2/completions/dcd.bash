#!/usr/bin/env bash
# docker-aliases v2 — bash completion for dcd.
#
# Completes container names across the whole host, not just the current
# project — dcd is for jumping to somewhere you are not.

_dcd_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-p -i -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_list_containers 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dcd_complete_bash dcd
