#!/usr/bin/env zsh
# docker-aliases v2 — zsh completion for dps.

_dps_complete_zsh() {
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
        flags=(-a -x -t -h --help)
        compadd -a flags
    else
        candidates=(${(f)"$(_dps_candidates 2>/dev/null)"})
        (( ${#candidates} )) && compadd -a candidates
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dps_complete_zsh dps

return 0
