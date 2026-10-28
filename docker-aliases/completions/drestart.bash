#!/usr/bin/env bash
# docker-aliases — bash completion for drestart.

_drestart_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$prev" == "-t" ]]; then
        COMPREPLY=()
    elif [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-t -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_drestart_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _drestart_complete_bash drestart
