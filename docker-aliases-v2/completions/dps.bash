#!/usr/bin/env bash
# docker-aliases v2 — bash completion for dps.

_dps_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f) COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") ); return 0 ;;
        -e) COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
        -P) COMPREPLY=( $(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur") ); return 0 ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -x -t -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dps_candidates 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dps_complete_bash dps
