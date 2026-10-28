#!/usr/bin/env bash
# docker-aliases — bash completion for devents.

_devents_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -f -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_devents_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _devents_complete_bash devents
