#!/usr/bin/env zsh
# docker-aliases — zsh completion for drestart.

_drestart_complete_zsh() {
    local -a flags names
    if [[ "${words[CURRENT-1]}" == "-t" ]]; then
        return
    elif [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-t -h --help)
        compadd -a flags
    else
        names=(${(f)"$(_drestart_candidates)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _drestart_complete_zsh drestart

return 0
