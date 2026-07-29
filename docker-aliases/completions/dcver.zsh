#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcver.

_dcver_complete_zsh() {
    local -a flags services profiles

    case "${words[CURRENT-1]}" in
        -f) _files -g '*.y(a|)ml'; return ;;
        -e) _files; return ;;
        -P)
            profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
            (( ${#profiles} )) && compadd -a profiles
            return ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-r -f -e -P -h --help)
        compadd -a flags
    else
        services=(${(f)"$(_dcver_candidates "${words[@]}" 2>/dev/null)"})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcver_complete_zsh dcver

return 0
