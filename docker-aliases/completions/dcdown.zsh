#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcdown.
#
# The function is defined unconditionally; only the compdef registration is
# guarded, since compdef exists only after compinit has run.

_dcdown_complete_zsh() {
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
            profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
            (( ${#profiles} )) && compadd -a profiles
            return
            ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-v -O -f -e -P -h --help)
        compadd -a flags
    else
        # Honour the -P already on the line: profiles decide which services exist.
        services=(${(f)"$(_get_compose_services --profiles \
            "$(_profiles_from_words "${words[@]}")" 2>/dev/null)"})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcdown_complete_zsh dcdown

return 0
