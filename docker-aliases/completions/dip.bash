#!/usr/bin/env bash
# docker-aliases — bash completion for dip.
#
# Offers running container names, which the text matcher understands. Not the
# addresses themselves: listing them needs a full inspect on every TAB, and an
# address is usually pasted from a log line rather than typed.

_dip_complete_bash() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dip_complete_bash dip
