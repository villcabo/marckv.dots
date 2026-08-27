#!/usr/bin/env zsh
# docker-aliases — zsh completion for dlt.
#
# The function is defined unconditionally; only the compdef registration is
# guarded, since compdef exists only after compinit has run. Bailing out early
# would leave the completion undefined and untestable outside an interactive
# shell.

_dlt_complete_zsh() {
    local -a flags names counts times

    # Value-taking flags decide the completion on their own.
    case "${words[CURRENT-1]}" in
        -n)
            counts=(100 500 1000 5000 all)
            compadd -a counts
            return
            ;;
        -s)
            times=(5m 10m 30m 1h 6h 24h)
            compadd -a times
            return
            ;;
    esac

    if [[ "${words[CURRENT]}" == -* ]]; then
        flags=(-n -s -o -t -a -h --help)
        compadd -a flags
    else
        # Container names, host-wide — the same source dps completes from.
        names=(${(f)"$(_dlt_candidates 2>/dev/null)"})
        (( ${#names} )) && compadd -a names
    fi
}

# compdef only exists once compinit has run — skip quietly otherwise.
(( $+functions[compdef] )) && compdef _dlt_complete_zsh dlt

return 0
