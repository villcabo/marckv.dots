#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcx.

_dcx_complete_zsh() {
    local -a flags services profiles users dirs commands
    local i seen_pattern=0

    case "${words[CURRENT-1]}" in
        -f) _files -g '*.y(a|)ml'; return ;;
        -e) _files; return ;;
        -P)
            profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
            (( ${#profiles} )) && compadd -a profiles
            return ;;
        -u)
            users=(root node postgres redis www-data)
            compadd -a users
            return ;;
        -w)
            dirs=(/ /app /srv /tmp /usr/src/app)
            compadd -a dirs
            return ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-u -w -f -e -P -h --help)
        compadd -a flags
        return
    fi

    # Everything after the service pattern is the command run inside the
    # container, which we cannot complete from out here.
    for (( i = 2; i < CURRENT; i++ )); do
        case "${words[i]}" in
            -u|-w|-f|-e|-P) (( i++ )) ;;
            -*) ;;
            *)  seen_pattern=1 ;;
        esac
    done

    if (( seen_pattern )); then
        commands=(bash sh ls cat env ps top)
        compadd -a commands
    else
        # Honour the -P already on the line: profiles decide which services exist.
        services=(${(f)"$(_get_compose_services --profiles \
            "$(_profiles_from_words "${words[@]}")" 2>/dev/null)"})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcx_complete_zsh dcx

return 0
