#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcrestart.

_dcrestart_complete_zsh() {
    local -a flags services profiles

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
            # _into: the printing form loses the profile cache in its subshell.
            _get_compose_profiles_into 2>/dev/null || _DA_R=""
            profiles=(${(f)_DA_R})
            (( ${#profiles} )) && compadd -a profiles
            return
            ;;
        -t)
            # Seconds: nothing sensible to offer.
            return
            ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-f -e -P -t -h --help)
        compadd -a flags
    else
        # Honour the -P already on the line, through the cache-keeping _into form
        # (see dcdown's completion for why that matters).
        _get_all_compose_services_into --profiles \
            "$(_profiles_from_words "${words[@]}")" 2>/dev/null || _DA_R=""
        services=(${(f)_DA_R})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcrestart_complete_zsh dcrestart

return 0
