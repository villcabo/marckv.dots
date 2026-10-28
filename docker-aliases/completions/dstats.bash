#!/usr/bin/env bash
# docker-aliases — bash completion for dstats.

_dstats_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-w -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dstats_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dstats_complete_bash dstats
