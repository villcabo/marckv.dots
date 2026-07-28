#!/usr/bin/env zsh
# docker-aliases — zsh completion for dcd.

_dcd_complete_zsh() {
    local -a flags containers

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-p -i -h --help)
        compadd -a flags
    else
        containers=(${(f)"$(_list_containers 2>/dev/null)"})
        (( ${#containers} )) && compadd -a containers
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dcd_complete_zsh dcd

return 0
