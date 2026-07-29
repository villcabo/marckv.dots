#!/usr/bin/env bash
# docker-aliases — bash completion for di.

_di_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-u -d -t -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_di_candidates 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _di_complete_bash di
