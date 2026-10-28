#!/usr/bin/env zsh
# docker-aliases — zsh completion for dhealth.

_dhealth_complete_zsh() {
    local -a flags names
    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-h --help)
        compadd -a flags
    elif (( CURRENT == 2 )); then
        names=(${(f)"$(_dhealth_candidates)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dhealth_complete_zsh dhealth

return 0
