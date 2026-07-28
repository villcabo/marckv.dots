#!/usr/bin/env bash
# docker-aliases v2 — bash completion for dcx.

_dcx_complete_bash() {
    local cur prev i seen_pattern=0
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f) COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") ); return 0 ;;
        -e) COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
        -P) COMPREPLY=( $(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur") ); return 0 ;;
        -u) COMPREPLY=( $(compgen -W "root node postgres redis www-data" -- "$cur") ); return 0 ;;
        -w) COMPREPLY=( $(compgen -W "/ /app /srv /tmp /usr/src/app" -- "$cur") ); return 0 ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-u -w -f -e -P -h --help" -- "$cur") )
        return 0
    fi

    # Has the service pattern already been given? Everything after it is the
    # command being run inside the container, not something we can complete.
    for (( i = 1; i < COMP_CWORD; i++ )); do
        case "${COMP_WORDS[i]}" in
            -u|-w|-f|-e|-P) (( i++ )) ;;
            -*) ;;
            *)  seen_pattern=1 ;;
        esac
    done

    if (( seen_pattern )); then
        COMPREPLY=( $(compgen -W "bash sh ls cat env ps top" -- "$cur") )
    else
        # Honour the -P already on the line: profiles decide which services exist.
        COMPREPLY=( $(compgen -W "$(_get_compose_services --profiles \
            "$(_profiles_from_words "${COMP_WORDS[@]}")" 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dcx_complete_bash dcx
