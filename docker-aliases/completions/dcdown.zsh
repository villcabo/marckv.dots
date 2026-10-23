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
            # _into: the printing form loses the profile cache in its subshell.
            _get_compose_profiles_into 2>/dev/null || _DA_R=""
            profiles=(${(f)_DA_R})
            (( ${#profiles} )) && compadd -a profiles
            return
            ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-v -O -f -e -P -h --help)
        compadd -a flags
    else
        # Honour the -P already on the line: profiles decide which services exist.
        # The _into form, not $(…): a command substitution is a subshell, so
        # the service cache it fills is discarded — and TAB is exactly the
        # case the cache exists for. Measured: 234 ms on the first press,
        # ~30 ms on the ones after.
        _get_all_compose_services_into --profiles \
            "$(_profiles_from_words "${words[@]}")" 2>/dev/null || _DA_R=""
        services=(${(f)_DA_R})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcdown_complete_zsh dcdown

return 0
