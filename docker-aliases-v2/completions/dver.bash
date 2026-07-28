#!/usr/bin/env bash
# docker-aliases v2 — bash completion for dver.

_dver_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -r -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dver_candidates 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dver_complete_bash dver
