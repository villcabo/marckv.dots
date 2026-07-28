#!/usr/bin/env zsh
# docker-aliases v2 — zsh completion for dcps.

_dcps_complete_zsh() {
    local -a flags candidates profiles

    case "${words[CURRENT-1]}" in
        -f) _files -g '*.y(a|)ml'; return ;;
        -e) _files; return ;;
        -P)
            profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
            (( ${#profiles} )) && compadd -a profiles
            return ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -x -t -f -e -P -h --help)
        compadd -a flags
    else
        candidates=(${(f)"$(_dcps_candidates "${words[@]}" 2>/dev/null)"})
        (( ${#candidates} )) && compadd -a candidates
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcps_complete_zsh dcps

return 0
