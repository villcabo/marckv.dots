#!/usr/bin/env bash
# docker-aliases — bash completion for dps.

_dps_complete_bash() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # No value-taking flags here. dps accepts -a -x -t and the two help forms,
    # none of which takes an argument, so there is nothing to complete after
    # one. This used to carry -f, -e and -P branches copied from the compose
    # commands: dead, because the flag list never offers them and dps rejects
    # them if typed by hand — it just cost a docker call to answer for a flag
    # that was about to be refused.

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-a -x -t -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dps_candidates 2>/dev/null)" -- "$cur") )
    fi
    return 0
}

complete -F _dps_complete_bash dps
