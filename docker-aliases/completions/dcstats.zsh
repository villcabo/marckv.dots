#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcstats.

_dcstats_complete_zsh() {
    local -a flags services
    if [[ "${words[CURRENT-1]}" == "-f" ]]; then
        _files -g '*.y(a|)ml'
        return
    fi
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-f -w -h --help)
        compadd -a flags
    else
        # The _into form keeps the service cache alive (see dcdown's completion).
        _get_all_compose_services_into 2>/dev/null || _DA_R=""
        services=(${(f)_DA_R})
        (( ${#services} )) && compadd -a services
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcstats_complete_zsh dcstats

return 0
