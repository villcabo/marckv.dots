#!/usr/bin/env bash
# docker-aliases — bash completion for dvol.

_dvol_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-u -s -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dvol_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dvol_complete_bash dvol
