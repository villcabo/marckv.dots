#!/usr/bin/env zsh
# docker-aliases — zsh completion for dnet.

_dnet_complete_zsh() {
    local -a flags nets
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-u -h --help)
        compadd -a flags
    else
        nets=(${(f)"$(_dnet_candidates)"})
        (( ${#nets} )) && compadd -a nets
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dnet_complete_zsh dnet

return 0
