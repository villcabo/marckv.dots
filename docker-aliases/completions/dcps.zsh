#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcps.

_dcps_complete_zsh() {
    local -a flags candidates profiles

    case "${words[CURRENT-1]}" in
        -f) _files -g '*.y(a|)ml'; return ;;
        -e) _files; return ;;
        -P)
            # _into: the printing form loses the profile cache in its subshell.
            _get_compose_profiles_into 2>/dev/null || _DA_R=""
            profiles=(${(f)_DA_R})
            (( ${#profiles} )) && compadd -a profiles
            return ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -x -t -f -e -P -h --help)
        compadd -a flags
    else
        # The _into form: $(…) is a subshell and the cache it fills dies there.
        # TAB is the case the cache exists for.
        _dcps_candidates_into "${words[@]}" 2>/dev/null || _DA_R=""
        candidates=(${(f)_DA_R})
        (( ${#candidates} )) && compadd -a candidates
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcps_complete_zsh dcps

return 0
