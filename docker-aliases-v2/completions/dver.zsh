#!/usr/bin/env zsh
# docker-aliases v2 — zsh completion for dver.

_dver_complete_zsh() {
    local -a flags containers

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -r -h --help)
        compadd -a flags
    else
        containers=(${(f)"$(_dver_candidates 2>/dev/null)"})
        (( ${#containers} )) && compadd -a containers
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dver_complete_zsh dver

return 0
