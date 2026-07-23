#!/usr/bin/env zsh
# docker-aliases v2 — zsh completion for dcup.
#
# This file is sourced rather than dropped into fpath, so registering with
# compdef depends on compinit having run first.
#
# The function is defined unconditionally and only the registration is guarded.
# Bailing out before the definition would make the completion untestable
# outside an interactive shell, and would leave nothing to register for anyone
# who runs compinit after sourcing us.

_dcup_complete_zsh() {
    local -a flags services profiles

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
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-r -p -b -l -f -e -P -h --help)
        compadd -a flags
    else
        services=(${(f)"$(_get_compose_services 2>/dev/null)"})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcup_complete_zsh dcup

return 0
