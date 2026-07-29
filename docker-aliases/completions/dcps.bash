#!/usr/bin/env bash
# docker-aliases — bash completion for dcps.

_dcps_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f) COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") ); return 0 ;;
        -e) COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
        -P) COMPREPLY=( $(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur") ); return 0 ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -x -t -f -e -P -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dcps_candidates "${COMP_WORDS[@]}" 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dcps_complete_bash dcps
