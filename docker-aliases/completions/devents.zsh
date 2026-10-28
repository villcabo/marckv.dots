#!/usr/bin/env zsh
# docker-aliases — zsh completion for devents.

_devents_complete_zsh() {
    local -a flags names
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -f -h --help)
        compadd -a flags
    else
        names=(${(f)"$(_devents_candidates)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _devents_complete_zsh devents

return 0
