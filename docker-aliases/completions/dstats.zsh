#!/usr/bin/env zsh
# docker-aliases — zsh completion for dstats.

_dstats_complete_zsh() {
    local -a flags names
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-w -h --help)
        compadd -a flags
    else
        names=(${(f)"$(_dstats_candidates)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dstats_complete_zsh dstats

return 0
