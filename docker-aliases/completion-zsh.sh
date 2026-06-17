#!/usr/bin/env zsh
# Zsh completion for docker-aliases
# Loaded only when ZSH_VERSION is detected by the main loader

# ---------------------------------------------------------------------------
# Fallthrough to docker's official zsh completion (if available).
# Loaded first so our compdef calls below override for the commands we handle.
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
    eval "$(docker completion zsh 2>/dev/null)" 2>/dev/null || true
fi

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
        'stats:Live resource stats (delegates to dstats)'
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
        'prune:Clean system (delegates to dprune)'
        'help:Show help'
        'h:Show help'
        '-h:Show help'
        '--help:Show help'
    )

    local -a containers
    containers=(${(f)"$(_get_docker_containers)"})

    if (( CURRENT == 2 )); then
        _describe 'subcommand' subcmds
    else
        local cmd="${words[2]}"
        case "$cmd" in
            x|sh|bash|logs|l|l100|l300|l500|start|stop|restart|rm)
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
        'ps:List services'
        'p:List services'
        'stats:Live resource stats'
        's:Live resource stats'
        'logs:Follow logs'
        'l:Follow logs'
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
        'info:Show compose configuration'
        'help:Show help'
        'h:Show help'
        '-h:Show help'
        '--help:Show help'
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
        '-P[Compose profile (comma-separated)]:profile:->profiles'
        '-e[Env-file override]:env file:_files -g "*.env* .env*"'
        '-y[Skip confirmation]'
        '--yes[Skip confirmation]'
    )

    local -a build_flags
    build_flags=(
        '-f[Use specific compose file]:compose file:->yml'
        '-P[Compose profile (comma-separated)]:profile:->profiles'
        '-e[Env-file override]:env file:_files -g "*.env* .env*"'
        '-y[Skip confirmation]'
        '--yes[Skip confirmation]'
        '--bake[Use buildx bake for parallel/multi-arch build]'
    )

    local -a ps_flags
    ps_flags=(
        '-c[Compact format]'
        '-p[Show ports]'
    )

    local cmd="${words[2]}"
    local prev="${words[$((CURRENT-1))]}"

    # After -f: complete yml files
    if [[ "$prev" == "-f" ]]; then
        _describe 'compose file' yml_files
        return
    fi

    # After -P: complete profiles
    if [[ "$prev" == "-P" ]]; then
        local -a profiles
        profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
        _describe 'profile' profiles
        return
    fi

    if (( CURRENT == 2 )); then
        _describe 'subcommand' subcmds
        return
    fi

    # Flag completion
    if [[ "${words[$CURRENT]}" == -* ]]; then
        case "$cmd" in
            up|u|down|d)
                _describe 'flag' up_flags
                ;;
            build|b)
                _describe 'flag' build_flags
                ;;
            ps|p)
                _describe 'flag' ps_flags
                ;;
        esac
        return
    fi

    # Service or file completion
    case "$cmd" in
        x|sh|bash|logs|l|start|stop|restart|up|u|down|d|build|b)
            _describe 'service' services
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
        '-h[Show help and examples]'
        '--help[Show help and examples]'
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
# dstats completion
# ---------------------------------------------------------------------------
_dstats_zsh() {
    local -a flags
    flags=(
        '--once[Single snapshot (no-stream)]'
    )
    _describe 'option' flags
}

# ---------------------------------------------------------------------------
# dprune completion
# ---------------------------------------------------------------------------
_dprune_zsh() {
    local -a flags
    flags=(
        '--all[docker system prune -af]'
        '--images[docker image prune -f]'
        '--volumes[docker volume prune -f]'
        '--networks[docker network prune -f]'
    )
    _describe 'option' flags
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
        '-n[Number of log lines to tail]:lines:(50 100 200 300 500)'
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
# dcpr completion (extra/ opt-in)
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
# dcw completion — compose watch
# ---------------------------------------------------------------------------
_dcw_zsh() {
    local -a services flags yml_files profiles
    services=(${(f)"$(_get_compose_services)"})
    yml_files=(${(f)"$(ls *.yml *.yaml 2>/dev/null)"})
    profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
    flags=(
        '-h[Show help and examples]'
        '--help[Show help and examples]'
        '-f[Use specific compose file]:compose file:(${yml_files[@]})'
        '-P[Compose profile (comma-separated)]:profile:(${profiles[@]})'
        '-y[Skip confirmation]'
        '--yes[Skip confirmation]'
    )

    local prev="${words[$((CURRENT-1))]}"

    if [[ "$prev" == "-f" ]]; then
        _describe 'compose file' yml_files
        return
    fi

    if [[ "$prev" == "-P" ]]; then
        _describe 'profile' profiles
        return
    fi

    if [[ "${words[$CURRENT]}" == -* ]]; then
        _describe 'flag' flags
        return
    fi

    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dcrun completion — one-shot run --rm
# ---------------------------------------------------------------------------
_dcrun_zsh() {
    local -a services flags yml_files profiles
    services=(${(f)"$(_get_compose_services)"})
    yml_files=(${(f)"$(ls *.yml *.yaml 2>/dev/null)"})
    profiles=(${(f)"$(_get_compose_profiles 2>/dev/null)"})
    flags=(
        '-h[Show help and examples]'
        '--help[Show help and examples]'
        '-P[Compose profile (comma-separated)]:profile:(${profiles[@]})'
        '-e[Env-file override]:env file:_files -g "*.env* .env*"'
        '-f[Use specific compose file]:compose file:(${yml_files[@]})'
        '--no-rm[Keep container after run]'
    )

    local prev="${words[$((CURRENT-1))]}"

    if [[ "$prev" == "-P" ]]; then
        _describe 'profile' profiles
        return
    fi

    if [[ "$prev" == "-f" ]]; then
        _describe 'compose file' yml_files
        return
    fi

    if [[ "${words[$CURRENT]}" == -* ]]; then
        _describe 'flag' flags
        return
    fi

    # First positional = service name
    local service_seen=false
    local w
    for w in "${words[@]:1:$((CURRENT-2))}"; do
        if [[ "$w" != -* ]]; then
            local wprev="${words[$((${words[(i)$w]}-1))]}"
            if [[ "$wprev" != "-P" && "$wprev" != "-e" && "$wprev" != "-f" ]]; then
                service_seen=true
                break
            fi
        fi
    done

    if [[ "$service_seen" == false ]]; then
        _describe 'service' services
    fi
}

# ---------------------------------------------------------------------------
# dss completion — no args
# ---------------------------------------------------------------------------
_dss_zsh() {
    :   # no completions
}

# ---------------------------------------------------------------------------
# dssps completion — suggest stacks
# ---------------------------------------------------------------------------
_dssps_zsh() {
    local -a stacks
    stacks=(${(f)"$(_get_swarm_stacks)"})
    _describe 'stack' stacks
}

# ---------------------------------------------------------------------------
# dssdeploy completion
# ---------------------------------------------------------------------------
_dssdeploy_zsh() {
    local prev="${words[$((CURRENT-1))]}"

    if [[ "$prev" == "-c" ]]; then
        local -a yml_files
        yml_files=(${(f)"$(ls *.yml *.yaml 2>/dev/null)"})
        _describe 'compose file' yml_files
        return
    fi

    if [[ "${words[$CURRENT]}" == -* ]]; then
        local -a flags
        flags=(
            '-c[Compose file to deploy]:compose file:_files -g "*.yml *.yaml"'
            '-y[Skip confirmation]'
            '--yes[Skip confirmation]'
        )
        _describe 'flag' flags
        return
    fi
    # First positional = stack name (free text — no completion)
}

# ---------------------------------------------------------------------------
# dssrm completion — suggest stacks + flags
# ---------------------------------------------------------------------------
_dssrm_zsh() {
    if [[ "${words[$CURRENT]}" == -* ]]; then
        local -a flags
        flags=(
            '-y[Skip confirmation]'
            '--yes[Skip confirmation]'
        )
        _describe 'flag' flags
        return
    fi
    local -a stacks
    stacks=(${(f)"$(_get_swarm_stacks)"})
    _describe 'stack' stacks
}

# ---------------------------------------------------------------------------
# dssvc completion — no args
# ---------------------------------------------------------------------------
_dssvc_zsh() {
    :
}

# ---------------------------------------------------------------------------
# dssvcps completion — suggest services
# ---------------------------------------------------------------------------
_dssvcps_zsh() {
    local -a services
    services=(${(f)"$(_get_swarm_services)"})
    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dssvcl completion — suggest services + -n flag
# ---------------------------------------------------------------------------
_dssvcl_zsh() {
    local prev="${words[$((CURRENT-1))]}"

    if [[ "$prev" == "-n" ]]; then
        local -a lines
        lines=('50:50 lines' '100:100 lines' '200:200 lines' '300:300 lines' '500:500 lines')
        _describe 'lines' lines
        return
    fi

    if [[ "${words[$CURRENT]}" == -* ]]; then
        local -a flags
        flags=(
            '-n[Number of log lines to tail]:lines:(50 100 200 300 500)'
        )
        _describe 'flag' flags
        return
    fi

    local -a services
    services=(${(f)"$(_get_swarm_services)"})
    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dssvcsc completion — suggest <svc>=N + flags
# ---------------------------------------------------------------------------
_dssvcsc_zsh() {
    if [[ "${words[$CURRENT]}" == -* ]]; then
        local -a flags
        flags=(
            '-y[Skip confirmation]'
            '--yes[Skip confirmation]'
        )
        _describe 'flag' flags
        return
    fi
    local -a services
    services=(${(f)"$(_get_swarm_services)"})
    _describe 'service' services
}

# ---------------------------------------------------------------------------
# dssnodes completion — no args
# ---------------------------------------------------------------------------
_dssnodes_zsh() {
    :
}

# ---------------------------------------------------------------------------
# dip completion — completes with container IPs
# ---------------------------------------------------------------------------
_dip_zsh() {
    local -a ips
    # Extract all IPs from running containers for completion
    local raw
    raw=$(docker inspect $(docker ps -q 2>/dev/null) \
        --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' 2>/dev/null)
    ips=(${(u)${=raw}})  # unique, split on whitespace
    ips=("${(@)ips:#}")  # remove empty entries
    _describe 'ip address' ips
}

# ---------------------------------------------------------------------------
# Register completions
# ---------------------------------------------------------------------------
compdef _d_zsh    d
compdef _dc_zsh   dc
compdef _dcup_zsh dcup

compdef _dstats_zsh dstats
compdef _dprune_zsh dprune

compdef _dq_zsh   dq
compdef _dcq_zsh  dcq dcdown dcl dcx dcs
compdef _dc_zsh   dcps
compdef _dq_zsh   dl dx
compdef _dclt_zsh dclt
compdef _dcpr_zsh dcpr
compdef _dip_zsh  dip
compdef _dcw_zsh  dcw
compdef _dcrun_zsh dcrun

# Swarm completions
compdef _dss_zsh      dss
compdef _dssps_zsh    dssps
compdef _dssdeploy_zsh dssdeploy
compdef _dssrm_zsh    dssrm
compdef _dssvc_zsh    dssvc
compdef _dssvcps_zsh  dssvcps
compdef _dssvcl_zsh   dssvcl
compdef _dssvcsc_zsh  dssvcsc
compdef _dssnodes_zsh dssnodes
