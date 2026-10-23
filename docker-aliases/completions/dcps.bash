#!/usr/bin/env bash
# docker-aliases — bash completion for dcps.

_dcps_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f) COMPREPLY=( $(compgen -f -X '!*.y*ml' -- "$cur") ); return 0 ;;
        -e) COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
        # _into: the printing form loses the profile cache in its subshell.
        -P) _get_compose_profiles_into 2>/dev/null || _DA_R=""
            COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") ); return 0 ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -x -t -f -e -P -h --help" -- "$cur") )
    else
        # The _into form: $(…) is a subshell and the cache it fills dies there.
        # TAB is the case the cache exists for.
        _dcps_candidates_into "${COMP_WORDS[@]}" 2>/dev/null || _DA_R=""
        COMPREPLY=( $(compgen -W "$_DA_R" -- "$cur") )
    fi
    return 0
}

complete -F _dcps_complete_bash dcps
