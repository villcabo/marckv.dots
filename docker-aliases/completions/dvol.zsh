#!/usr/bin/env zsh
# docker-aliases — zsh completion for dvol.

_dvol_complete_zsh() {
    local -a flags vols
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-u -s -h --help)
        compadd -a flags
    else
        vols=(${(f)"$(_dvol_candidates)"})
        (( ${#vols} )) && compadd -a vols
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dvol_complete_zsh dvol

return 0
