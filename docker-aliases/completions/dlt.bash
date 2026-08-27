#!/usr/bin/env bash
# docker-aliases — bash completion for dlt.

_dlt_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Value-taking flags decide the completion on their own.
    case "$prev" in
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
        COMPREPLY=( $(compgen -W "-n -s -o -t -a -h --help" -- "$cur") )
    else
        # Container names, host-wide — the same source dps completes from.
        COMPREPLY=( $(compgen -W "$(_dlt_candidates 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dlt_complete_bash dlt
