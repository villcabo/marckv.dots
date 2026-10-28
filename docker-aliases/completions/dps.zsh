#!/usr/bin/env zsh
# docker-aliases — zsh completion for dps.

_dps_complete_zsh() {
    local -a flags candidates

    # No value-taking flags here. dps accepts -a -x -t and the two help forms,
    # none of which takes an argument. This used to carry -f, -e and -P
    # branches copied from the compose commands: dead, because the flag list
    # never offers them and dps rejects them if typed by hand.

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-a -x -t -h --help)
        compadd -a flags
    else
        candidates=(${(f)"$(_dps_candidates 2>/dev/null)"})
        (( ${#candidates} )) && compadd -a candidates
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dps_complete_zsh dps

return 0
