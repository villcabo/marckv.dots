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

    # After -P: suggest profiles; after -e: suggest .env* files
    if [[ "$prev" == "-P" ]]; then
        COMPREPLY=($(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur"))
        return 0
    fi
    if [[ "$prev" == "-e" ]]; then
        COMPREPLY=($(compgen -f -G ".env*" -- "$cur"))
        return 0
    fi

    if [[ "$cur" == -* ]]; then
        case "$command" in
            up|u|down|d)
                local all_flags="-p -l -f -b -r -P -e"
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
            build|b)
                local all_flags="-p -l -f -b -r -P -e --bake"
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
# dcw completion — compose watch
# ---------------------------------------------------------------------------
_dcw_completion() {
    local cur prev i
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -f)
            COMPREPLY=($(compgen -W "$(ls *.yml *.yaml 2>/dev/null)" -- "$cur"))
            return 0
            ;;
        -P)
            COMPREPLY=($(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        local all_flags="-f -P -y --yes -h --help"
        # Exclude already-used single-use flags
        local used="" flag
        for (( i=1; i<COMP_CWORD; i++ )); do
            [[ "${COMP_WORDS[i]}" == -* && "${COMP_WORDS[i]}" != "-f" && "${COMP_WORDS[i]}" != "-P" ]] && used+="${COMP_WORDS[i]} "
        done
        local avail=""
        for flag in $all_flags; do
            [[ ! "$used" =~ $flag ]] && avail+="$flag "
        done
        COMPREPLY=($(compgen -W "$avail" -- "$cur"))
        return 0
    fi

    COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
}

# ---------------------------------------------------------------------------
# dcrun completion — one-shot run
# ---------------------------------------------------------------------------
_dcrun_completion() {
    local cur prev i
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -P)
            COMPREPLY=($(compgen -W "$(_get_compose_profiles 2>/dev/null)" -- "$cur"))
            return 0
            ;;
        -e)
            # Complete .env* files
            COMPREPLY=($(compgen -f -G ".env*" -- "$cur"))
            return 0
            ;;
        -f)
            COMPREPLY=($(compgen -W "$(ls *.yml *.yaml 2>/dev/null)" -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-P -e -f --no-rm -h --help" -- "$cur"))
        return 0
    fi

    # First non-flag argument → service name; after that → shell commands
    local service_pos=0
    for (( i=1; i<COMP_CWORD; i++ )); do
        if [[ "${COMP_WORDS[i]}" != -* ]]; then
            # check it's not a value for a flag
            local pprev="${COMP_WORDS[i-1]}"
            if [[ "$pprev" != "-P" && "$pprev" != "-e" && "$pprev" != "-f" ]]; then
                service_pos=$i
                break
            fi
        fi
    done

    if [[ $service_pos -eq 0 ]]; then
        COMPREPLY=($(compgen -W "$(_get_compose_services)" -- "$cur"))
    fi
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
# dss completion — no args beyond the command itself
# ---------------------------------------------------------------------------
_dss_completion() {
    :   # no completions — dss takes no arguments
}

# ---------------------------------------------------------------------------
# dssps / dssrm completion — suggest stacks
# ---------------------------------------------------------------------------
_dssps_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(_get_swarm_stacks)" -- "$cur"))
}

_dssrm_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-y --yes" -- "$cur"))
        return 0
    fi
    COMPREPLY=($(compgen -W "$(_get_swarm_stacks)" -- "$cur"))
}

# ---------------------------------------------------------------------------
# dssdeploy completion — first arg: stack name (free text); after -c: yml files
# ---------------------------------------------------------------------------
_dssdeploy_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$prev" == "-c" ]]; then
        COMPREPLY=($(compgen -W "$(ls *.yml *.yaml 2>/dev/null)" -- "$cur"))
        return 0
    fi

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-c -y --yes" -- "$cur"))
        return 0
    fi
    # No completion for stack name (free text) or command args beyond flags
}

# ---------------------------------------------------------------------------
# dssvc completion — no args
# ---------------------------------------------------------------------------
_dssvc_completion() {
    :
}

# ---------------------------------------------------------------------------
# dssvcps / dssvcl / dssvcsc completion — suggest services
# ---------------------------------------------------------------------------
_dssvcps_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(_get_swarm_services)" -- "$cur"))
}

_dssvcl_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$prev" == "-n" ]]; then
        COMPREPLY=($(compgen -W "50 100 200 300 500" -- "$cur"))
        return 0
    fi
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-n" -- "$cur"))
        return 0
    fi
    COMPREPLY=($(compgen -W "$(_get_swarm_services)" -- "$cur"))
}

_dssvcsc_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-y --yes" -- "$cur"))
        return 0
    fi
    # Suggest <svc>=N pattern by listing services as prefix
    local svcs
    svcs=$(_get_swarm_services)
    COMPREPLY=($(compgen -W "$svcs" -- "$cur"))
}

# ---------------------------------------------------------------------------
# dssnodes completion — no args
# ---------------------------------------------------------------------------
_dssnodes_completion() {
    :
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
complete -F _dcw_completion           dcw
complete -F _dcrun_completion         dcrun

# Swarm completions
complete -F _dss_completion      dss
complete -F _dssps_completion    dssps
complete -F _dssdeploy_completion dssdeploy
complete -F _dssrm_completion    dssrm
complete -F _dssvc_completion    dssvc
complete -F _dssvcps_completion  dssvcps
complete -F _dssvcl_completion   dssvcl
complete -F _dssvcsc_completion  dssvcsc
complete -F _dssnodes_completion dssnodes
