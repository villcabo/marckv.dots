#!/usr/bin/env zsh
# docker-aliases — zsh completion for dprune. It takes no names, only flags.

_dprune_complete_zsh() {
    local -a flags
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -v -n -h --help)
        compadd -a flags
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dprune_complete_zsh dprune

return 0
