#!/usr/bin/env zsh
# docker-aliases — zsh completion for di.

_di_complete_zsh() {
    local -a flags images

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-u -d -t -h --help)
        compadd -a flags
    else
        images=(${(f)"$(_di_candidates 2>/dev/null)"})
        (( ${#images} )) && compadd -a images
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _di_complete_zsh di

return 0
