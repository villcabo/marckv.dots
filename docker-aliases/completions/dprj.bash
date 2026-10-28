#!/usr/bin/env bash
# docker-aliases — bash completion for dprj.

_dprj_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dprj_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dprj_complete_bash dprj
