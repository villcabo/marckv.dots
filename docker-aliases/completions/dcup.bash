#!/usr/bin/env bash
# docker-aliases — bash completion for dcup.

_dcup_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Value-taking flags decide the completion on their own.
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
            COMPREPLY=( $(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur") )
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-r -p -b -l -f -e -P -h --help" -- "$cur") )
    else
        # Honour the -P already on the line: profiles decide which services exist.
        COMPREPLY=( $(compgen -W "$(_get_compose_services --profiles \
            "$(_profiles_from_words "${COMP_WORDS[@]}")" 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dcup_complete_bash dcup
