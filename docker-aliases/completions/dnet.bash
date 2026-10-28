#!/usr/bin/env bash
# docker-aliases — bash completion for dnet.

_dnet_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-u -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dnet_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dnet_complete_bash dnet
