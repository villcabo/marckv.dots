#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcver.

_dcver_complete_zsh() {
    local -a flags services profiles

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
        flags=(-r -f -e -P -h --help)
        compadd -a flags
    else
        # The _into form: $(…) is a subshell and the cache it fills dies there.
        # TAB is the case the cache exists for.
        _dcver_candidates_into "${words[@]}" 2>/dev/null || _DA_R=""
        services=(${(f)_DA_R})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcver_complete_zsh dcver

return 0
