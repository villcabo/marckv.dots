#!/usr/bin/env zsh
# Zsh completion for docker-aliases
# Loaded only when ZSH_VERSION is detected by the main loader

# ---------------------------------------------------------------------------
# d() completion
# ---------------------------------------------------------------------------
_d_zsh() {
    local -a subcmds
    subcmds=(
        'ps:List running containers'
        'p:List running containers'
        'ps1:List containers (compact format)'
        'p1:List containers (compact format)'
        'psp:List containers with ports'
        'images:List images'
        'i:List images'
        'stats:Live resource stats'
        's:Live resource stats'
        's1:Stats (single snapshot)'
        'logs:Follow container logs'
        'l:Follow container logs'
        'l100:Follow last 100 log lines'
        'l300:Follow last 300 log lines'
        'l500:Follow last 500 log lines'
        'x:Execute command in container'
        'sh:Open sh shell in container'
        'bash:Open bash shell in container'
        'start:Start container'
        'stop:Stop container'
        'restart:Restart container'
        'rm:Remove container'
        'rmi:Remove image'
        'kill:Kill container'
        'inspect:Inspect container'
        'top:Show container processes'
        'prune:Clean system (safe)'
        'prunea:Clean all (aggressive)'
        'pruneima:Prune images'
        'prunevol:Prune volumes'
        'prunenet:Prune networks'
        'help:Show help'
        'h:Show help'
    )

    local -a containers
    containers=(${(f)"$(_get_docker_containers)"})

    if (( CURRENT == 2 )); then
        _describe 'subcommand' subcmds
    else
        local cmd="${words[2]}"
        case "$cmd" in
            x|sh|bash|logs|l|l100|l300|l500|start|stop|restart|rm|inspect|top|kill)
                _describe 'container' containers
                ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# dc() / dcup completion
# ---------------------------------------------------------------------------
_dc_zsh() {
    local -a subcmds
    subcmds=(
        'up:Start services'
        'u:Start services'
        'ul:Start services and follow logs'
        'ps:List services'
        'p:List services'
        'ps1:List services (compact)'
        'p1:List services (compact)'
        'psp:List services with ports'
        'stats:Live resource stats'
        's:Live resource stats'
        's1:Stats (single snapshot)'
        'logs:Follow logs'
        'l:Follow logs'
        'l100:Follow last 100 lines'
        'l300:Follow last 300 lines'
        'l500:Follow last 500 lines'
        'x:Execute in service'
        'sh:Open sh in service'
        'bash:Open bash in service'
        'down:Stop and remove services'
        'd:Stop and remove services'
        'start:Start services'
        'stop:Stop services'
        'restart:Restart services'
        'build:Build services'
        'b:Build services'
        'pull:Pull images'
        'default:Manage default compose file'
        'info:Show compose configuration'
        'help:Show help'
        'h:Show help'
    )

    local -a services
    services=(${(f)"$(_get_compose_services)"})

    local -a yml_files
    yml_files=(${(f)"$(ls *.yml *.yaml 2>/dev/null)"})

    local -a up_flags
    up_flags=(
        '-f[Use specific compose file]:compose file:->yml'
        '-p[Pull images before up]'
        '-b[Build before up]'
        '-l[Follow logs after up]'
        '-r[Force recreate containers]'
    )

    local cmd="${words[2]}"
    local prev="${words[$((CURRENT-1))]}"

    # After -f: complete yml files
    if [[ "$prev" == "-f" ]]; then
        _describe 'compose file' yml_files
        return
    fi

    if (( CURRENT == 2 )); then
        _describe 'subcommand' subcmds
        return
    fi

    # Flag completion
    if [[ "${words[$CURRENT]}" == -* ]]; then
        case "$cmd" in
            up|u|ul|down|d|build|b)
                _describe 'flag' up_flags
                ;;
        esac
        return
    fi

    # Service or file completion
    case "$cmd" in
        x|sh|bash|logs|l|l100|l300|l500|start|stop|restart|up|u|ul|down|d|build|b)
            _describe 'service' services
            ;;
        default)
            if (( CURRENT == 3 )); then
                local -a opts
                opts=('remove:Remove default setting' 'rm:Remove default setting')
                _describe 'option' opts
                _describe 'file' yml_files
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# dcup completion — same as "dc up" but skips the subcommand layer
# ---------------------------------------------------------------------------
_dcup_zsh() {
    local -a services flags yml_files
    services=(${(f)"$(_get_compose_services)"})
    yml_files=(${(f)"$(ls *.yml *.yaml 2>/dev/null)"})
    flags=(
        '-f[Use specific compose file]'
        '-p[Pull images before up]'
        '-b[Build before up]'
        '-l[Follow logs after up]'
        '-r[Force recreate containers]'
    )

    local prev="${words[$((CURRENT-1))]}"
    if [[ "$prev" == "-f" ]]; then
        _describe 'compose file' yml_files
        return
    fi

    if [[ "${words[$CURRENT]}" == -* ]]; then
        _describe 'flag' flags
        return
    fi

    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dq completion
# ---------------------------------------------------------------------------
_dq_zsh() {
    local -a containers
    containers=(${(f)"$(_get_docker_containers)"})
    _describe 'container' containers
}

# ---------------------------------------------------------------------------
# dcq completion
# ---------------------------------------------------------------------------
_dcq_zsh() {
    local -a services
    services=(${(f)"$(_get_compose_services)"})
    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dclt completion
# ---------------------------------------------------------------------------
_dclt_zsh() {
    local -a services flags
    services=(${(f)"$(_get_compose_services)"})
    flags=(
        '-r[Match patterns as regex]'
        '--regex[Match patterns as regex]'
        '-w[Ask for confirmation before showing logs]'
        '--wait[Ask for confirmation before showing logs]'
    )

    if [[ "${words[$CURRENT]}" == -* ]]; then
        _describe 'option' flags
    else
        _describe 'service' services
    fi
}

# ---------------------------------------------------------------------------
# dcpr completion
# ---------------------------------------------------------------------------
_dcpr_zsh() {
    local -a services flags
    services=(${(f)"$(_get_compose_services)"})
    flags=(
        '-a[Show all services]'
        '--all[Show all services]'
        '-s[Show summary table]'
        '--summary[Show summary table]'
        '-as[Show all services with summary]'
        '-sa[Show all services with summary]'
    )

    if [[ "${words[$CURRENT]}" == -* ]]; then
        _describe 'option' flags
    else
        _describe 'service' services
    fi
}

# ---------------------------------------------------------------------------
# Register completions
# ---------------------------------------------------------------------------
compdef _d_zsh    d
compdef _dc_zsh   dc
compdef _dcup_zsh dcup
compdef _dq_zsh   dq
compdef _dcq_zsh  dcq dcdown dcl dcx dcs
compdef _dc_zsh   dcps dcps1
compdef _dq_zsh   dl dx
compdef _dclt_zsh dclt
compdef _dcpr_zsh dcpr
