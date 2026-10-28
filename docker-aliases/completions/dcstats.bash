#!/usr/bin/env bash
# docker-aliases — bash completion for dcstats.

_dcstats_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$prev" == "-f" ]]; then
        COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") )
    elif [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-f -w -h --help" -- "$cur") )
    else
        # The _into form keeps the service cache alive (see dcdown's completion).
        _get_all_compose_services_into 2>/dev/null || _DA_R=""
        COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
    fi
    return 0
}

complete -F _dcstats_complete_bash dcstats
