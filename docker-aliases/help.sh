#!/usr/bin/env bash
# Help functions for docker-aliases

_docker_help() {
    echo -e "${CB}${CCY}🐳 Docker Helper${CR}  ${CI}(d <subcommand>)${CR}\n"

    echo -e "${CCY}BASIC${CR}"
    echo -e "  ${CGR}d ps${CR},  ${CGR}d p${CR}             List running containers"
    echo -e "  ${CGR}d ps1${CR}, ${CGR}d p1${CR}            List in compact format"
    echo -e "  ${CGR}d psp${CR}                  List with ports"
    echo -e "  ${CGR}d images${CR}, ${CGR}d i${CR}          List images"

    echo -e "\n${CCY}LOGS & STATS${CR}"
    echo -e "  ${CGR}d logs${CR}, ${CGR}d l${CR}            Follow logs (real-time)"
    echo -e "  ${CGR}d l100${CR}/${CGR}l300${CR}/${CGR}l500${CR}       Follow logs with tail limit"
    echo -e "  ${CGR}d stats${CR}, ${CGR}d s${CR}           Live stats"
    echo -e "  ${CGR}d s1${CR}                   Stats (single snapshot)"

    echo -e "\n${CCY}EXEC${CR}"
    echo -e "  ${CGR}d x${CR} ${CMA}<container> <cmd>${CR}   Execute command in container"
    echo -e "  ${CGR}d sh${CR} ${CMA}<container>${CR}        Open sh shell"
    echo -e "  ${CGR}d bash${CR} ${CMA}<container>${CR}      Open bash shell"

    echo -e "\n${CCY}CONTROL${CR}"
    echo -e "  ${CGR}d start${CR}/${CGR}stop${CR}/${CGR}restart${CR} ${CMA}<container>${CR}"
    echo -e "  ${CGR}d rm${CR} ${CMA}<container>${CR}        Remove container"
    echo -e "  ${CGR}d rmi${CR} ${CMA}<image>${CR}           Remove image"
    echo -e "  ${CGR}d kill${CR} ${CMA}<container>${CR}      Kill container"

    echo -e "\n${CCY}INFORMATION${CR}"
    echo -e "  ${CGR}d inspect${CR} ${CMA}<container>${CR}   Inspect container"
    echo -e "  ${CGR}d top${CR} ${CMA}<container>${CR}       Show running processes"

    echo -e "\n${CCY}CLEANUP${CR}"
    echo -e "  ${CGR}d prune${CR}                Clean system (safe)"
    echo -e "  ${CGR}d prunea${CR}               Clean all (aggressive)"
    echo -e "  ${CGR}d pruneima${CR}             Prune images"
    echo -e "  ${CGR}d prunevol${CR}             Prune volumes"
    echo -e "  ${CGR}d prunenet${CR}             Prune networks"

    echo -e "\n${CCY}QUICK FUNCTIONS${CR}"
    echo -e "  ${CGR}dq${CR} ${CMA}<pattern> <cmd>${CR}      Exec in first container matching pattern"
    echo -e "  ${CGR}dip${CR}                    List all containers with their IP addresses"
    echo -e "  ${CGR}dip${CR} ${CMA}<ip>${CR}               Find container by IP (or partial IP)"
    echo -e "  ${CGR}dstatus${CR}                Quick overview of containers and services"
    echo -e "  ${CGR}dcleanup${CR}               Full system cleanup"

    echo -e "\n${CCY}ALIASES${CR}"
    echo -e "  ${CYE}dps${CR}  → d ps    ${CYE}dps1${CR} → d ps1   ${CYE}di${CR}  → d images"
    echo -e "  ${CYE}dl${CR}   → d logs  ${CYE}ds${CR}   → d stats  ${CYE}dx${CR}  → d x"

    echo -e "\n${CCY}EXAMPLES${CR}"
    echo -e "  ${CGR}d x web bash${CR}           Open bash in 'web' container"
    echo -e "  ${CGR}dq nginx ls${CR}            Run ls in first container matching 'nginx'"
}

_compose_help() {
    echo -e "${CB}${CCY}🐙 Docker Compose Helper${CR}  ${CI}(dc <subcommand>)${CR}\n"

    echo -e "${CCY}UP / DOWN${CR}"
    echo -e "  ${CGR}dc up${CR}, ${CGR}dc u${CR}             Start services (with confirmation)"
    echo -e "  ${CGR}dc up -p${CR}              Pull before up"
    echo -e "  ${CGR}dc up -r${CR}              Force recreate"
    echo -e "  ${CGR}dc up -b${CR}              Build before up"
    echo -e "  ${CGR}dc up -l${CR}              Up + follow logs"
    echo -e "  ${CGR}dc up -f${CR} ${CMA}<file>${CR}        Use a specific compose file"
    echo -e "  ${CGR}dc ul${CR}                 Up + follow logs (shorthand)"
    echo -e "  ${CGR}dc down${CR}, ${CGR}dc d${CR}          Stop and remove services"

    echo -e "\n${CCY}FLAGS${CR}  ${CI}(combinable in a single argument)${CR}"
    echo -e "  ${CYE}-f${CR} ${CMA}<file>${CR}   Use specific compose file"
    echo -e "  ${CYE}-p${CR}         Pull images first"
    echo -e "  ${CYE}-b${CR}         Build before up"
    echo -e "  ${CYE}-l${CR}         Show logs after up"
    echo -e "  ${CYE}-r${CR}         Force recreate containers"

    echo -e "\n${CCY}FLAG COMBINATIONS${CR}"
    echo -e "  ${CGR}dc up -pl${CR}                  Pull + logs"
    echo -e "  ${CGR}dc up -rbl${CR}                 Recreate + build + logs"
    echo -e "  ${CGR}dc up -f prod.yml -pl${CR}      Use prod.yml + pull + logs"

    echo -e "\n${CCY}STATUS${CR}"
    echo -e "  ${CGR}dc ps${CR}, ${CGR}dc p${CR}            List services"
    echo -e "  ${CGR}dc ps1${CR}, ${CGR}dc p1${CR}          Compact format"
    echo -e "  ${CGR}dc psp${CR}                List with ports"
    echo -e "  ${CGR}dc info${CR}               Show compose config and available files"

    echo -e "\n${CCY}LOGS & STATS${CR}"
    echo -e "  ${CGR}dc logs${CR}, ${CGR}dc l${CR}          Follow logs (last 100 lines)"
    echo -e "  ${CGR}dc l100${CR}/${CGR}l300${CR}/${CGR}l500${CR}     Follow logs with tail limit"
    echo -e "  ${CGR}dc stats${CR}, ${CGR}dc s${CR}         Live resource stats"
    echo -e "  ${CGR}dc s1${CR}                 Stats (single snapshot)"

    echo -e "\n${CCY}EXEC${CR}"
    echo -e "  ${CGR}dc x${CR} ${CMA}<svc> <cmd>${CR}       Execute in service"
    echo -e "  ${CGR}dc sh${CR} ${CMA}<svc>${CR}            Open sh shell in service"
    echo -e "  ${CGR}dc bash${CR} ${CMA}<svc>${CR}          Open bash shell in service"

    echo -e "\n${CCY}CONTROL${CR}"
    echo -e "  ${CGR}dc start${CR}/${CGR}stop${CR}/${CGR}restart${CR} ${CMA}<service>${CR}"
    echo -e "  ${CGR}dc build${CR}, ${CGR}dc b${CR}         Build services"
    echo -e "  ${CGR}dc pull${CR}               Pull images"

    echo -e "\n${CCY}DEFAULT FILE MANAGEMENT${CR}"
    echo -e "  ${CGR}dc default${CR}             Show current default compose file"
    echo -e "  ${CGR}dc default${CR} ${CMA}<file>${CR}      Set default compose file (saved in .env)"
    echo -e "  ${CGR}dc default remove${CR}      Remove default setting"

    echo -e "\n${CCY}SMART FUNCTIONS${CR}"
    echo -e "  ${CGR}dcq${CR} ${CMA}<pattern> <cmd>${CR}    Exec in first service matching pattern"
    echo -e "  ${CGR}dclt${CR} [opts] [svc...]   Follow logs for matching services"
    echo -e "  ${CGR}dcpr${CR} ${CMA}<svc>${CR}            Show git.properties from container"
    echo -e "  ${CGR}dcpr -a${CR}               Show git.properties for all services"
    echo -e "  ${CGR}dcpr -as${CR}              Summary table for all services"

    echo -e "\n${CCY}ALIASES${CR}"
    echo -e "  ${CYE}dcup${CR}  → dc up    ${CYE}dcdown${CR} → dc down   ${CYE}dcps${CR} → dc ps"
    echo -e "  ${CYE}dcl${CR}   → dc logs  ${CYE}dcs${CR}    → dc stats  ${CYE}dcx${CR}  → dc x"

    echo -e "\n${CCY}EXAMPLES${CR}"
    echo -e "  ${CGR}dc x api bash${CR}              Bash into 'api' service"
    echo -e "  ${CGR}dc up -rl web${CR}              Recreate + logs for 'web' only"
    echo -e "  ${CGR}dc up -f prod.yml${CR}          Use prod.yml compose file"
    echo -e "  ${CGR}dc default staging.yml${CR}     Set staging.yml as default"
    echo -e "  ${CGR}dcq data psql${CR}              psql in first service matching 'data'"
    echo -e "  ${CGR}dclt -r 'api|web'${CR}          Follow logs matching regex 'api|web'"
}

alias dhelp='_docker_help'
alias dchelp='_compose_help'
alias dockerhelp='echo "Use: dhelp (docker) or dchelp (compose)"'
