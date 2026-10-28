#!/usr/bin/env bash
# docker-aliases — dcstats: dstats for the compose project you are standing in,
# by service name.
#
# `docker compose stats` exists and is no use here: its template has no
# {{.Service}} (measured: "can't evaluate field Service in type
# *container.statsContext"), so it prints container names — and every dc
# command speaks in service names. So this is dstats' table, filtered to the
# project's containers and labelled by service, through the same core in
# dstats.sh. Same numbers, same limits, same costs.

_dcstats_help() {
    printf "${CB}${CCY}dcstats${CR} — resource use of this compose project, by service\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcstats${CR} [${CYE}-f${CR} ${CMA}file${CR}] [${CYE}-w${CR}] [${CMA}service-pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-f${CR} ${CMA}file${CR}            Compose file ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-w${CR}                 Watch: redraw until Ctrl-C ${CI}(every ~2 s — docker's pace)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    _dstats_reading_help

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcstats${CR}                Every running service of the project\n"
    printf "  ${CGR}dcstats api${CR}            Services matching 'api'\n"
    printf "  ${CGR}dcstats -w${CR}             Keep watching\n"
}

dcstats() {
    local watch=false pattern="" project resolved item
    local -a files

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcstats_help; return 0 ;;
            -w) watch=true ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcstats "-f requires a compose file"; return 1; }
                [[ -f "$1" ]] || { _err dcstats "compose file not found: $1"; return 1; }
                files+=("$1")
                ;;
            -*) _err dcstats "unknown flag: $1"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dcstats "one pattern at a time"; return 1; }
                pattern="$1"
                ;;
        esac
        shift
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        resolved=$(_resolve_compose_files) || {
            _err dcstats "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        while IFS= read -r item; do
            [[ -n "$item" ]] && files+=("$item")
        done <<< "$resolved"
    fi

    project=$(_get_compose_project "${files[@]}") || {
        _err dcstats "could not work out the compose project name"
        return 1
    }

    if $watch; then
        _dstats_watch _dstats_table "compose stats · $project" project "$pattern" "$project"
    else
        _dstats_table "compose stats · $project" project "$pattern" "$project"
    fi
}
