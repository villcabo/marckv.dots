#!/usr/bin/env bash
# docker-aliases — bash completion for dcx.

_dcx_complete_bash() {
    local cur prev i seen_pattern=0
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f) COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") ); return 0 ;;
        -e) COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
        # _into: the printing form loses the profile cache in its subshell.
        -P) _get_compose_profiles_into 2>/dev/null || _DA_R=""
            COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") ); return 0 ;;
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
        # The _into form, not $(…): a command substitution is a subshell, so
        # the service cache it fills is discarded — and TAB is exactly the
        # case the cache exists for. Measured: 234 ms on the first press,
        # ~30 ms on the ones after.
        _get_all_compose_services_into --profiles \
            "$(_profiles_from_words "${COMP_WORDS[@]}")" 2>/dev/null || _DA_R=""
        COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
    fi
    return 0
}

complete -F _dcx_complete_bash dcx
