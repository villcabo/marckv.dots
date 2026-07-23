#!/usr/bin/env zsh
# docker-aliases v2 — zsh completion for dclt.
#
# The function is defined unconditionally; only the compdef registration is
# guarded, since compdef exists only after compinit has run. Bailing out early
# would leave the completion undefined and untestable outside an interactive
# shell.

_dclt_complete_zsh() {
    local -a flags services profiles counts times

    # Value-taking flags decide the completion on their own.
    case "${words[CURRENT-1]}" in
        -f)
            _files -g '*.y(a|)ml'
            return
            ;;
        -e)
            _files
            return
            ;;
        -P)
            profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
            (( ${#profiles} )) && compadd -a profiles
            return
            ;;
        -n)
            counts=(100 500 1000 5000 all)
            compadd -a counts
            return
            ;;
        -s)
            times=(5m 10m 30m 1h 6h 24h)
            compadd -a times
            return
            ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-n -s -o -t -f -e -P -h --help)
        compadd -a flags
    else
        services=(${(f)"$(_get_compose_services 2>/dev/null)"})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dclt_complete_zsh dclt

return 0
