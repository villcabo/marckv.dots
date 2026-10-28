#!/usr/bin/env bash
# docker-aliases — bash completion for dcrestart.

_dcrestart_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f)
            COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") )
            return 0
            ;;
        -e)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
        -P)
            # _into: the printing form loses the profile cache in its subshell.
            _get_compose_profiles_into 2>/dev/null || _DA_R=""
            COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
            return 0
            ;;
        -t)
            # Seconds: nothing sensible to offer.
            COMPREPLY=()
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-f -e -P -t -h --help" -- "$cur") )
    else
        # Honour the -P already on the line, through the cache-keeping _into form
        # (see dcdown's completion for why that matters).
        _get_all_compose_services_into --profiles \
            "$(_profiles_from_words "${COMP_WORDS[@]}")" 2>/dev/null || _DA_R=""
        COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
    fi
    return 0
}

complete -F _dcrestart_complete_bash dcrestart
