#!/usr/bin/env zsh
# docker-aliases — zsh completion for dprj.

_dprj_complete_zsh() {
    local -a flags projects
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -h --help)
        compadd -a flags
    else
        projects=(${(f)"$(_dprj_candidates)"})
        (( ${#projects} )) && compadd -a projects
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dprj_complete_zsh dprj

return 0
