#!/usr/bin/env bash
# Help functions for docker-aliases

_docker_help() {
    echo -e "${CB}${CCY}Docker Helper${CR}  ${CI}(d <subcommand>)${CR}\n"

    echo -e "${CCY}BASIC${CR}"
    echo -e "  ${CGR}d ps${CR},  ${CGR}d p${CR}             List running containers"
    echo -e "  ${CGR}d ps1${CR}, ${CGR}d p1${CR}            List in compact format"
    echo -e "  ${CGR}d psp${CR}                  List with ports"
    echo -e "  ${CGR}d images${CR}, ${CGR}d i${CR}          List images"

    echo -e "\n${CCY}LOGS & STATS${CR}"
    echo -e "  ${CGR}d logs${CR}, ${CGR}d l${CR}            Follow logs (real-time)"
    echo -e "  ${CGR}d l100${CR}/${CGR}l300${CR}/${CGR}l500${CR}       Follow logs with tail limit"
    echo -e "  ${CGR}d stats${CR}               Live stats (delegates to dstats)"

    echo -e "\n${CCY}EXEC${CR}"
    echo -e "  ${CGR}d x${CR} ${CMA}<container> <cmd>${CR}   Execute command in container"
    echo -e "  ${CGR}d sh${CR} ${CMA}<container>${CR}        Open sh shell"
    echo -e "  ${CGR}d bash${CR} ${CMA}<container>${CR}      Open bash shell"

    echo -e "\n${CCY}CONTROL${CR}"
    echo -e "  ${CGR}d start${CR}/${CGR}stop${CR}/${CGR}restart${CR} ${CMA}<container>${CR}"
    echo -e "  ${CGR}d rm${CR} ${CMA}<container>${CR}        Remove container"

    echo -e "\n${CCY}CLEANUP${CR}"
    echo -e "  ${CGR}d prune${CR}                Clean system — delegates to dprune"
    echo -e "  ${CGR}dprune${CR}                 docker system prune -f (safe)"
    echo -e "  ${CGR}dprune --all${CR}           docker system prune -af (preview + confirm)"
    echo -e "  ${CGR}dprune --all -y${CR}        Skip confirmation"
    echo -e "  ${CGR}dprune --images${CR}        docker image prune -f"
    echo -e "  ${CGR}dprune --volumes${CR}       docker volume prune -f"
    echo -e "  ${CGR}dprune --networks${CR}      docker network prune -f"

    echo -e "\n${CCY}STATS${CR}"
    echo -e "  ${CGR}dstats${CR}                 Live resource stats (streaming)"
    echo -e "  ${CGR}dstats --once${CR}          Single snapshot"

    echo -e "\n${CCY}QUICK FUNCTIONS${CR}"
    echo -e "  ${CGR}dq${CR} ${CMA}<pattern> <cmd>${CR}      Exec in first container matching pattern"
    echo -e "  ${CGR}dip${CR}                    List all containers with their IP addresses"
    echo -e "  ${CGR}dip${CR} ${CMA}<ip>${CR}               Find container by IP (or partial IP)"
    echo -e "  ${CGR}dstatus${CR}                Quick overview of containers and services"

    echo -e "\n${CCY}ALIASES${CR}"
    echo -e "  ${CYE}dps${CR}  → d ps    ${CYE}di${CR}  → d images  ${CYE}dl${CR}  → d logs"
    echo -e "  ${CYE}dlt${CR}  → d l100  ${CYE}dx${CR}  → d x"

    echo -e "\n${CCY}EXAMPLES${CR}"
    echo -e "  ${CGR}d x web bash${CR}           Open bash in 'web' container"
    echo -e "  ${CGR}dq nginx ls${CR}            Run ls in first container matching 'nginx'"
    echo -e "  ${CGR}dstats --once${CR}          One-shot stats snapshot"
    echo -e "  ${CGR}dprune --volumes${CR}       Prune unused volumes"

    echo -e "\n${CCY}CONFIGURATION${CR}"
    echo -e "  ${CYE}DOCKER_ALIASES_NERD_FONT=0${CR}    Force ASCII icons (default: Nerd Font)"
    echo -e "  ${CYE}DOCKER_ALIASES_AUTO_YES=1${CR}     Skip all confirmation prompts"
    echo -e "  ${CYE}DOCKER_ALIASES_CACHE_TTL=N${CR}   Completion cache TTL in seconds (default: 5)"
    echo -e "                               Set to 0 to disable caching."

    echo -e "\n${CCY}SEE ALSO${CR}"
    echo -e "  Run ${CGR}dsshelp${CR} for Docker Swarm commands (${CYE}dss*${CR} namespace)."
}

_compose_help() {
    echo -e "${CB}${CCY}Docker Compose Helper${CR}  ${CI}(dc <subcommand>)${CR}\n"

    echo -e "${CCY}UP / DOWN${CR}"
    echo -e "  ${CGR}dc up${CR}, ${CGR}dc u${CR}             Start services (preview + confirm)"
    echo -e "  ${CGR}dc up -p${CR}              Pull before up"
    echo -e "  ${CGR}dc up -r${CR}              Force recreate"
    echo -e "  ${CGR}dc up -b${CR}              Build before up"
    echo -e "  ${CGR}dc up -l${CR}              Up + follow logs"
    echo -e "  ${CGR}dc up -y${CR}              Skip confirmation"
    echo -e "  ${CGR}dc up -f${CR} ${CMA}<file>${CR}        Use a specific compose file"
    echo -e "  ${CGR}dc down${CR}, ${CGR}dc d${CR}          Stop and remove services"

    echo -e "\n${CCY}FLAGS${CR}  ${CI}(combinable in a single argument)${CR}"
    echo -e "  ${CYE}-f${CR} ${CMA}<file>${CR}   Use specific compose file"
    echo -e "  ${CYE}-p${CR}         Pull images first"
    echo -e "  ${CYE}-b${CR}         Build before up"
    echo -e "  ${CYE}-l${CR}         Show logs after up"
    echo -e "  ${CYE}-r${CR}         Force recreate containers"
    echo -e "  ${CYE}-y${CR}         Skip confirmation (or use ${CYE}--yes${CR})"

    echo -e "\n${CCY}FLAG COMBINATIONS${CR}"
    echo -e "  ${CGR}dc up -pl${CR}                  Pull + logs"
    echo -e "  ${CGR}dc up -rbl${CR}                 Recreate + build + logs"
    echo -e "  ${CGR}dc up -f prod.yml -pl${CR}      Use prod.yml + pull + logs"
    echo -e "  ${CGR}dc up -y api worker${CR}         Skip confirm + specific services"

    echo -e "\n${CCY}STATUS${CR}"
    echo -e "  ${CGR}dc ps${CR}, ${CGR}dc p${CR}            List services"
    echo -e "  ${CGR}dc ps -c${CR}              Compact format"
    echo -e "  ${CGR}dc ps -p${CR}              With ports"
    echo -e "  ${CGR}dc info${CR}               Show compose config and available files"

    echo -e "\n${CCY}LOGS & STATS${CR}"
    echo -e "  ${CGR}dc logs${CR}, ${CGR}dc l${CR}          Follow logs (last 100 lines)"
    echo -e "  ${CGR}dc stats${CR}, ${CGR}dc s${CR}         Live resource stats"

    echo -e "\n${CCY}EXEC${CR}"
    echo -e "  ${CGR}dc x${CR} ${CMA}<svc> <cmd>${CR}       Execute in service"
    echo -e "  ${CGR}dc sh${CR} ${CMA}<svc>${CR}            Open sh shell in service"
    echo -e "  ${CGR}dc bash${CR} ${CMA}<svc>${CR}          Open bash shell in service"

    echo -e "\n${CCY}CONTROL${CR}"
    echo -e "  ${CGR}dc start${CR}/${CGR}stop${CR}/${CGR}restart${CR} ${CMA}<service>${CR}"
    echo -e "  ${CGR}dc pull${CR}               Pull images"

    echo -e "\n${CCY}BUILD${CR}"
    echo -e "  ${CGR}dc build${CR}, ${CGR}dc b${CR}         Build services (docker compose build)"
    echo -e "  ${CGR}dc build --bake${CR}        Build via buildx bake — parallel, multi-arch, monorepos"
    echo -e "  ${CGR}dc build --bake api${CR}    Bake a specific target"
    echo -e "  ${CI}Use ${CYE}--bake${CR}${CI} when you have many images, need multi-arch releases, or compose builds${CR}"
    echo -e "  ${CI}become the bottleneck. Requires ${CYE}docker buildx${CR}${CI} (Docker 19.03+).${CR}"

    echo -e "\n${CCY}SMART FUNCTIONS${CR}"
    echo -e "  ${CGR}dcq${CR} ${CMA}<pattern> <cmd>${CR}    Exec in first service matching pattern"
    echo -e "  ${CGR}dclt${CR} [opts] [svc...]   Follow logs for matching services"
    echo -e "  ${CGR}dclt -n 300 api${CR}        Follow last 300 lines for 'api'"
    echo -e "  ${CGR}dclt -r 'api|web'${CR}      Regex match services"

    echo -e "\n${CCY}ALIASES${CR}"
    echo -e "  ${CYE}dcup${CR}  → dc up    ${CYE}dcdown${CR} → dc down   ${CYE}dcps${CR} → dc ps"
    echo -e "  ${CYE}dcl${CR}   → dc logs  ${CYE}dcs${CR}    → dc stats  ${CYE}dcx${CR}  → dc x"

    echo -e "\n${CCY}EXAMPLES${CR}"
    echo -e "  ${CGR}dc x api bash${CR}              Bash into 'api' service"
    echo -e "  ${CGR}dc up -rl web${CR}              Recreate + logs for 'web' only"
    echo -e "  ${CGR}dc up -f prod.yml${CR}          Use prod.yml compose file"
    echo -e "  ${CGR}dc ps -c${CR}                   Compact service list"
    echo -e "  ${CGR}dcq data psql${CR}              psql in first service matching 'data'"
    echo -e "  ${CGR}dclt -n 300 api${CR}            Follow last 300 log lines for 'api'"

    echo -e "\n${CCY}MODERN COMPOSE (v2-native)${CR}"
    echo -e "  ${CGR}dcw${CR} [opts] [svc...]   Compose watch (file-sync dev loop)"
    echo -e "  ${CGR}dcrun${CR} [opts] ${CMA}<svc> <cmd>${CR}  One-shot run --rm"
    echo -e "  ${CYE}-P${CR} ${CMA}<profile>${CR}          Activate compose profile (works on up/down/build/dcw/dcrun)"
    echo -e "  ${CYE}-e${CR} ${CMA}<file>${CR}             Env-file override (repeatable)"
    echo -e "  ${CI}Run ${CYE}dmhelp${CR}${CI} for full modern compose reference${CR}"

    echo -e "\n${CCY}CONFIGURATION${CR}"
    echo -e "  ${CYE}DOCKER_COMPOSE_FILE=file.yml${CR}     Override compose file"
    echo -e "  ${CYE}DOCKER_ALIASES_NERD_FONT=0${CR}      Force ASCII icons (default: Nerd Font)"
    echo -e "  ${CYE}DOCKER_ALIASES_AUTO_YES=1${CR}       Skip all confirmation prompts"
    echo -e "  ${CYE}DOCKER_ALIASES_LOG_LINES=200${CR}    Default tail lines for dclt (default: 100)"
    echo -e "  ${CYE}DOCKER_ALIASES_CACHE_TTL=N${CR}      Completion cache TTL in seconds (default: 5)"
    echo -e "                               Set to 0 to disable caching."
}

_modern_compose_help() {
    echo -e "${CB}${CCY}Modern Compose Commands${CR}  ${CI}(compose v2-native)${CR}\n"

    echo -e "${CCY}WATCH${CR}"
    echo -e "  ${CGR}dcw${CR}                          Watch all services (sync on file change)"
    echo -e "  ${CGR}dcw api${CR}                      Watch only 'api' service"
    echo -e "  ${CGR}dcw -f dev.yml${CR}               Custom compose file"
    echo -e "  ${CGR}dcw -P dev api${CR}               Dev profile, watch 'api'"
    echo -e "  ${CGR}dcw -y${CR}                       Skip confirmation"

    echo -e "\n${CCY}ONE-SHOT RUN${CR}"
    echo -e "  ${CGR}dcrun api bash${CR}                Ephemeral bash in 'api' (removed after exit)"
    echo -e "  ${CGR}dcrun -P dev migrate npm run migrate${CR}  Migrations in dev profile"
    echo -e "  ${CGR}dcrun -e .env.test api pytest${CR} Run pytest with test env-file"
    echo -e "  ${CGR}dcrun --no-rm api bash${CR}        Keep container after exit"

    echo -e "\n${CCY}PROFILE FLAG${CR}  ${CI}(-P, applies to dcup / dcdown / dc build / dcw / dcrun)${CR}"
    echo -e "  ${CYE}-P${CR} ${CMA}<profile>${CR}              Activate a compose profile"
    echo -e "  ${CYE}-P${CR} ${CMA}dev,debug${CR}              Multiple profiles (comma-separated)"
    echo -e "  ${CGR}dcup -P dev${CR}                  Equivalent to: docker compose --profile dev up -d"
    echo -e "  ${CGR}dcup -P dev,debug api worker${CR}  Profile + specific services"

    echo -e "\n${CCY}ENV-FILE FLAG${CR}  ${CI}(-e, applies to dcup / dcdown / dc build / dcrun)${CR}"
    echo -e "  ${CYE}-e${CR} ${CMA}<file>${CR}               Env-file override (repeatable)"
    echo -e "  ${CGR}dcup -e .env.prod${CR}             Equivalent to: docker compose up --env-file .env.prod"
    echo -e "  ${CGR}dcup -e .env.prod -e .env.local${CR}  Stack multiple env-files"
    echo -e "  ${CGR}dcrun -e .env.test api pytest${CR} One-shot run with test env-file"

    echo -e "\n${CCY}COMPLETION HINTS${CR}"
    echo -e "  After ${CYE}-P${CR}, TAB suggests profiles from the active compose file."
    echo -e "  After ${CYE}-e${CR}, TAB suggests ${CMA}.env*${CR} files in the current directory."
}

_swarm_help() {
    echo -e "${CB}${CCY}Docker Swarm Helper${CR}  ${CI}(dss* namespace)${CR}\n"

    echo -e "${CCY}STACKS${CR}"
    echo -e "  ${CGR}dss${CR}                          List all stacks (docker stack ls)"
    echo -e "  ${CGR}dssps${CR} ${CMA}<stack>${CR}               Tasks of a stack (docker stack ps)"
    echo -e "  ${CGR}dssdeploy${CR} ${CMA}<stack>${CR}           Deploy stack (auto-detect compose file)"
    echo -e "  ${CGR}dssdeploy${CR} ${CMA}<stack>${CR} ${CYE}-c${CR} ${CMA}<file>${CR}   Deploy using specific compose file"
    echo -e "  ${CGR}dssdeploy${CR} ${CMA}<stack>${CR} ${CYE}-y${CR}          Deploy without confirmation"
    echo -e "  ${CGR}dssrm${CR} ${CMA}<stack>${CR}               Remove stack (preview + confirm)"
    echo -e "  ${CGR}dssrm${CR} ${CMA}<stack>${CR} ${CYE}-y${CR}             Remove without confirmation"

    echo -e "\n${CCY}SERVICES${CR}"
    echo -e "  ${CGR}dssvc${CR}                         List all services (docker service ls)"
    echo -e "  ${CGR}dssvcps${CR} ${CMA}<svc>${CR}               Tasks of a service (docker service ps)"
    echo -e "  ${CGR}dssvcl${CR} ${CMA}<svc>${CR}                Follow service logs (tail 100)"
    echo -e "  ${CGR}dssvcl${CR} ${CMA}<svc>${CR} ${CYE}-n${CR} ${CMA}<N>${CR}          Follow last N log lines"
    echo -e "  ${CGR}dssvcsc${CR} ${CMA}<svc>=<N>${CR}           Scale service (preview + confirm)"
    echo -e "  ${CGR}dssvcsc${CR} ${CMA}<svc>=<N>${CR} ${CYE}-y${CR}         Scale without confirmation"

    echo -e "\n${CCY}NODES${CR}"
    echo -e "  ${CGR}dssnodes${CR}                      List swarm nodes (docker node ls)"

    echo -e "\n${CCY}OVERVIEW${CR}"
    echo -e "  ${CGR}dsstatus${CR}                      Stacks + services + nodes overview"

    echo -e "\n${CCY}EXAMPLES${CR}"
    echo -e "  ${CGR}dssdeploy myapp${CR}               Deploy 'myapp' stack (auto-detects compose file)"
    echo -e "  ${CGR}dssdeploy myapp -c prod.yml${CR}   Deploy using prod.yml"
    echo -e "  ${CGR}dssrm myapp${CR}                   Remove 'myapp' stack (with confirm)"
    echo -e "  ${CGR}dssvcl myapp_api${CR}              Follow logs for service 'myapp_api'"
    echo -e "  ${CGR}dssvcl myapp_api -n 300${CR}       Follow last 300 lines"
    echo -e "  ${CGR}dssvcsc myapp_api=3${CR}           Scale 'myapp_api' to 3 replicas"
    echo -e "  ${CGR}dsstatus${CR}                      Quick swarm overview"

    echo -e "\n${CCY}FLAGS${CR}"
    echo -e "  ${CYE}-c${CR} ${CMA}<file>${CR}   Compose file for dssdeploy (default: auto-detect)"
    echo -e "  ${CYE}-n${CR} ${CMA}<N>${CR}     Tail lines for dssvcl (default: \$DOCKER_ALIASES_LOG_LINES or 100)"
    echo -e "  ${CYE}-y${CR}         Skip confirmation for dssdeploy / dssrm / dssvcsc"

    echo -e "\n${CCY}NOTES${CR}"
    echo -e "  Destructive commands (${CYE}dssrm${CR}, ${CYE}dssvcsc${CR}) show a preview + require confirmation."
    echo -e "  Set ${CYE}DOCKER_ALIASES_AUTO_YES=1${CR} to skip all confirmations globally."
    echo -e "  All list commands pipe through ${CYE}docker-color-output${CR} when available."
}

alias dhelp='_docker_help'
alias dchelp='_compose_help'
alias dmhelp='_modern_compose_help'
alias dsshelp='_swarm_help'
