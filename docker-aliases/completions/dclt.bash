#!/usr/bin/env bash
# docker-aliases — bash completion for dclt.

_dclt_complete_bash() {
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
            # _into: the printing form loses the profile cache in its subshell.
            _get_compose_profiles_into 2>/dev/null || _DA_R=""
            COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
            return 0
            ;;
        -n)
            COMPREPLY=( $(compgen -W "100 500 1000 5000 all" -- "$cur") )
            return 0
            ;;
        -s)
            COMPREPLY=( $(compgen -W "5m 10m 30m 1h 6h 24h" -- "$cur") )
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-n -s -o -t -f -e -P -h --help" -- "$cur") )
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

complete -F _dclt_complete_bash dclt
