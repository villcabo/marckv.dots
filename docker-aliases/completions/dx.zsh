#!/usr/bin/env zsh
# docker-aliases — zsh completion for dx.

_dx_complete_zsh() {
    # Not `commands`: that name shadows a zsh special parameter (the hash of
    # every command on PATH). Harmless today, and the kind of thing that stops
    # being harmless the day something reads it.
    local -a flags names users dirs cmds
    local i seen_pattern=0

    case "${words[CURRENT-1]}" in
        -u)
            users=(root node postgres redis www-data nobody)
            compadd -a users
            return ;;
        -w)
            dirs=(/ /app /srv /tmp /usr/src/app)
            compadd -a dirs
            return ;;
    esac

    # Settled before flags are offered: after the pattern, a dash word is argv
    # for the command inside the container, not one of dx's flags.
    for (( i = 2; i < CURRENT; i++ )); do
        case "${words[i]}" in
            -u|-w) (( i++ )) ;;
            -*) ;;
            *)  seen_pattern=1 ;;
        esac
    done

    if (( seen_pattern )); then
        cmds=(bash sh ls cat env ps top)
        compadd -a cmds
    elif [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-u -w -h --help)
        compadd -a flags
    else
        names=(${(f)"$(_dx_candidates)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dx_complete_zsh dx

return 0
