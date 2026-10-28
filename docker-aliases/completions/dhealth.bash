#!/usr/bin/env bash
# docker-aliases — bash completion for dhealth.

_dhealth_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
    elif [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$(_dhealth_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dhealth_complete_bash dhealth
