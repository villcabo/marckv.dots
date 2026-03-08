#!/usr/bin/env bash
# Help functions for docker-aliases

_docker_help() {
    cat << 'EOF'
🐳 Docker Helper (d)

BASIC:
  d ps, d p          List running containers
  d ps1, d p1        List in compact format
  d psp              List with ports
  d images, d i      List images

LOGS & STATS:
  d logs, d l        Follow logs (real-time)
  d l100/l300/l500   Follow logs with tail limit
  d stats, d s       Live stats
  d s1               Stats (single snapshot)

EXEC:
  d x <c> <cmd>      Execute command in container
  d sh <c>           Open sh shell
  d bash <c>         Open bash shell

CONTROL:
  d start/stop/restart <container>
  d rm <c>           Remove container
  d rmi <img>        Remove image
  d kill <c>         Kill container

INFORMATION:
  d inspect <c>      Inspect container
  d top <c>          Show running processes

CLEANUP:
  d prune            Clean system (safe)
  d prunea           Clean all (aggressive)
  d pruneima         Prune images
  d prunevol         Prune volumes
  d prunenet         Prune networks

QUICK:
  dq <pattern> <cmd> Execute in first container matching pattern
  dstatus            Quick overview of containers and services
  dcleanup           Full system cleanup

ALIASES:
  dps   → d ps       dps1 → d ps1    di  → d images
  dl    → d logs     dlt  → d l100   ds  → d stats
  dx    → d x        dpri → d image prune

Examples:
  d x web bash       Open bash in 'web' container
  dq nginx ls        Run ls in first container matching 'nginx'
EOF
}

_compose_help() {
    cat << 'EOF'
🐙 Docker Compose Helper (dc)

BASIC:
  dc up, dc u            Start services (with confirmation)
  dc up -p               Pull before up (--pull always)
  dc up -r               Force recreate (--force-recreate)
  dc up -b               Build before up (--build)
  dc up -l               Up + follow logs automatically
  dc up -f FILE          Use a specific compose file
  dc ul                  Up + follow logs (shorthand)
  dc down, dc d          Stop and remove services

FLAGS (combinable):
  -f FILE    Use specific compose file
  -p         Pull images first
  -b         Build before up
  -l         Show logs after up
  -r         Force recreate containers

FLAG COMBINATIONS:
  dc up -pl              Pull + logs
  dc up -rbl             Recreate + build + logs
  dc up -f prod.yml -pl  Use prod.yml + pull + logs

STATUS:
  dc ps, dc p            List services
  dc ps1, dc p1          Compact format
  dc psp                 List with ports
  dc info                Show compose config and available files

LOGS & STATS:
  dc logs, dc l          Follow logs (last 100 lines)
  dc l100/l300/l500      Follow logs with tail limit
  dc stats, dc s         Live resource stats
  dc s1                  Stats (single snapshot)

EXEC:
  dc x <svc> <cmd>       Execute in service
  dc sh <svc>            Open sh shell in service
  dc bash <svc>          Open bash shell in service

CONTROL:
  dc start/stop/restart <service>
  dc build, dc b         Build services
  dc build -f FILE       Build using specific compose file
  dc pull                Pull images

DEFAULT FILE MANAGEMENT:
  dc default             Show current default compose file
  dc default <file>      Set default compose file (saved in .env)
  dc default remove      Remove default setting

SMART FUNCTIONS:
  dcq <pattern> <cmd>    Exec in first service matching pattern
  dclt [opts] [svc...]   Follow logs for matching services
  dcpr <svc>             Show git.properties from container
  dcpr -a                Show git.properties for all services
  dcpr -as               Summary table for all services

ALIASES:
  dcup  → dc up     dcdown → dc down   dcps → dc ps
  dcl   → dc logs   dcs    → dc stats  dcx  → dc x

Examples:
  dc x api bash          Bash into 'api' service
  dc up -rl web          Recreate + logs for 'web' only
  dc up -f prod.yml      Use prod.yml compose file
  dc default staging.yml Set staging.yml as default
  dcq data psql          psql in first service matching 'data'
  dclt -r api|web        Follow logs matching regex 'api|web'
EOF
}

alias dhelp='_docker_help'
alias dchelp='_compose_help'
alias dockerhelp='echo "Use: dhelp (docker) or dchelp (compose)"'
