#!/usr/bin/env bash
# docker-aliases — bash completion for dprune. It takes no names, only flags.

_dprune_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -v -n -h --help" -- "$cur") )
    else
        COMPREPLY=()
    fi
    return 0
}

complete -F _dprune_complete_bash dprune
