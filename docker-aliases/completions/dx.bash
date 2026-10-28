#!/usr/bin/env bash
# docker-aliases — bash completion for dx.

_dx_complete_bash() {
    local cur prev i seen_pattern=0
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -u) COMPREPLY=( $(compgen -W "root node postgres redis www-data nobody" -- "$cur") ); return 0 ;;
        -w) COMPREPLY=( $(compgen -W "/ /app /srv /tmp /usr/src/app" -- "$cur") ); return 0 ;;
    esac

    # Settled BEFORE offering flags. Once the pattern is on the line, a word
    # starting with `-` belongs to the command run inside the container, and
    # offering dx's own flags there would promise something that ends up as
    # argv to ls or cat. dcx gets this order wrong; dx does not copy it.
    for (( i = 1; i < COMP_CWORD; i++ )); do
        case "${COMP_WORDS[i]}" in
            -u|-w) (( i++ )) ;;
            -*) ;;
            *)  seen_pattern=1 ;;
        esac
    done

    if (( seen_pattern )); then
        COMPREPLY=( $(compgen -W "bash sh ls cat env ps top" -- "$cur") )
    elif [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-u -w -h --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$(_dx_candidates)" -- "$cur") )
    fi
    return 0
}

complete -F _dx_complete_bash dx
