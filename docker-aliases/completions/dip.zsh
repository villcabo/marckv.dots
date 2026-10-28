#!/usr/bin/env zsh
# docker-aliases — zsh completion for dip.

_dip_complete_zsh() {
    local -a flags names
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-h --help)
        compadd -a flags
    else
        names=(${(f)"$(docker ps --format '{{.Names}}' 2>/dev/null)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dip_complete_zsh dip

return 0
