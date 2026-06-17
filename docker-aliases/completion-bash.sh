#!/usr/bin/env bash
# Bash completion for docker-aliases
# Loaded only when BASH_VERSION is detected by the main loader

# ---------------------------------------------------------------------------
# d() completion
# ---------------------------------------------------------------------------
_d_completion() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local cmds="ps p ps1 p1 psp images i stats logs l l100 l300 l500 x sh bash start stop restart rm prune help h -h --help"
        COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
    else
        case "$prev" in
            x|sh|bash|logs|l|l100|l300|l500|start|stop|restart|rm)
                COMPREPLY=($(compgen -W "$(_get_docker_containers)" -- "$cur"))
                ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# dc() / dcup completion
# ---------------------------------------------------------------------------
_dc_completion() {
    local cur prev command i
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    command=""

    # Find the first non-flag word as the subcommand
    for (( i=1; i<COMP_CWORD; i++ )); do
        if [[ "${COMP_WORDS[i]}" != -* ]]; then
            command="${COMP_WORDS[i]}"
            break
        fi
    done

    # After -f: complete yml/yaml files
    if [[ "$prev" == "-f" ]]; then
        COMPREPLY=($(compgen -W "$(ls *.yml *.yaml 2>/dev/null)" -- "$cur"))
        return 0
    fi

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local cmds="up u ps p stats s logs l x sh bash down d start stop restart build b pull info help h -h --help"
        COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
        return 0
    fi

    if [[ "$cur" == -* ]]; then
        case "$command" in
            up|u|down|d|build|b)
                local all_flags="-p -l -f -b -r"
                local used="" flag
                for (( i=1; i<COMP_CWORD; i++ )); do
                    [[ "${COMP_WORDS[i]}" == -* && "${COMP_WORDS[i]}" != "-f" ]] && used+="${COMP_WORDS[i]} "
                done
                local avail=""
                for flag in $all_flags; do
                    [[ "$flag" == "-f" || ! "$used" =~ $flag ]] && avail+="$flag "
                done
                COMPREPLY=($(compgen -W "$avail" -- "$cur"))
                ;;
            ps|p)
                COMPREPLY=($(compgen -W "-c -p" -- "$cur"))
                ;;
        esac
        return 0
    fi

    case "$command" in
        x|sh|bash|logs|l|start|stop|restart|up|u|down|d|build|b)
            [[ "$prev" != "-f" ]] && COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
            ;;
    esac
}

# ---------------------------------------------------------------------------
# dcup completion — same as "dc up" but skips the subcommand layer
# ---------------------------------------------------------------------------
_dcup_completion() {
    local cur prev i
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$prev" == "-f" ]]; then
        COMPREPLY=($(compgen -W "$(ls *.yml *.yaml 2>/dev/null)" -- "$cur"))
        return 0
    fi

    if [[ "$cur" == -* ]]; then
        local all_flags="-h --help -p -l -f -b -r"
        local used="" flag
        for (( i=1; i<COMP_CWORD; i++ )); do
            [[ "${COMP_WORDS[i]}" == -* && "${COMP_WORDS[i]}" != "-f" ]] && used+="${COMP_WORDS[i]} "
        done
        local avail=""
        for flag in $all_flags; do
            [[ "$flag" == "-f" || ! "$used" =~ $flag ]] && avail+="$flag "
        done
        COMPREPLY=($(compgen -W "$avail" -- "$cur"))
        return 0
    fi

    COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
}

# ---------------------------------------------------------------------------
# dstats completion
# ---------------------------------------------------------------------------
_dstats_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--once" -- "$cur"))
    fi
}

# ---------------------------------------------------------------------------
# dprune completion
# ---------------------------------------------------------------------------
_dprune_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* || ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "--all --images --volumes --networks" -- "$cur"))
    fi
}

# ---------------------------------------------------------------------------
# Quick function completions
# ---------------------------------------------------------------------------
_dq_completion() {
    COMPREPLY=($(compgen -W "$(_get_docker_containers)" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_dcq_completion() {
    COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_dc_services_completion() {
    COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_dc_containers_completion() {
    COMPREPLY=($(compgen -W "$(_get_docker_containers)" -- "${COMP_WORDS[COMP_CWORD]}"))
}

# ---------------------------------------------------------------------------
# dclt completion
# ---------------------------------------------------------------------------
_dclt_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$prev" == "-n" ]]; then
        COMPREPLY=($(compgen -W "50 100 200 300 500" -- "$cur"))
    elif [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-n -r --regex -w --wait" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
    fi
}

# ---------------------------------------------------------------------------
# dcpr completion (extra/ opt-in)
# ---------------------------------------------------------------------------
_dcpr_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-a --all -s --summary -as -sa" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
    fi
}

# ---------------------------------------------------------------------------
# Register all completions
# ---------------------------------------------------------------------------
complete -F _d_completion    d
complete -F _dc_completion   dc
complete -F _dcup_completion dcup

complete -F _dstats_completion    dstats
complete -F _dprune_completion    dprune

complete -F _dq_completion            dq
complete -F _dcq_completion           dcq
complete -F _dc_services_completion   dcdown dcl dcx dcs dcps
complete -F _dc_containers_completion dl dx
complete -F _dclt_completion          dclt
complete -F _dcpr_completion          dcpr
