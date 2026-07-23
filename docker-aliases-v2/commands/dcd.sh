#!/usr/bin/env bash
# docker-aliases v2 — dcd: jump to the compose project a container belongs to.
#
# Compose stamps every container it creates with labels naming the project, the
# service, the working directory and the compose files. dcd reads those and
# takes you there, which beats `docker inspect | grep working_dir` by hand.
#
# Design contract for this command:
#   * It searches EVERY container on the host, running or stopped — the whole
#     point is jumping to a project you are not standing in, and a project worth
#     jumping to is often one that is currently down.
#   * The ambiguity that matters is the DESTINATION, not the container. A
#     project has many containers — `dcd redmine` matching redmine,
#     redmine-postgres and redmine-db-backup is not ambiguous at all, because
#     all three lead to the same directory. Only patterns spanning two different
#     projects are an error.
#   * It never prints environment variables. `docker inspect` will hand them
#     over gladly, and they routinely hold database passwords and API keys —
#     which would land in your scrollback, and in any recording or screen share.
#
# `cd` only affects the caller when this runs as a shell function in the current
# shell, which is why it lives here and not in a script.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcd_help() {
    printf "${CB}${CCY}dcd${CR} — jump to a container's compose project directory\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcd${CR} [${CYE}flags${CR}] ${CMA}<pattern>${CR}\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-p${CR}                 Print the path and do not cd ${CI}(for scripting)${CR}\n"
    printf "  ${CYE}-i${CR}                 Show the details and do not cd\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against ${CB}container names${CR},\n"
    printf "  across the whole host — running and stopped alike.\n\n"
    printf "  Matching several containers of the ${CB}same project${CR} is fine: they all\n"
    printf "  lead to one directory. Only a pattern spanning ${CB}two projects${CR} is an\n"
    printf "  error, because then there really are two places to go.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcd redmine${CR}                   Jump to the redmine project\n"
    printf "  ${CGR}dcd '^redmine\$'${CR}               Exactly that container\n"
    printf "  ${CGR}dcd -i redmine${CR}                Look without moving\n"
    printf "  ${CGR}cd \"\$(dcd -p redmine)\"${CR}        Compose with other commands\n"
    printf "  ${CGR}code \"\$(dcd -p redmine)\"${CR}      Open the project in an editor\n\n"

    printf "${CCY}PRIVACY${CR}\n"
    printf "  Environment variables are never shown. Containers hold passwords\n"
    printf "  and tokens, and a scrollback is a lasting place to leave them.\n"
}

# ---------------------------------------------------------------------------
# dcd
# ---------------------------------------------------------------------------

dcd() {
    case "$1" in
        -h|--help) _dcd_help; return 0 ;;
    esac

    # --- parse --------------------------------------------------------------
    local print_only=false info_only=false pattern=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcd_help; return 0 ;;
            -p) print_only=true ;;
            -i) info_only=true ;;
            -pi|-ip) print_only=true; info_only=true ;;
            -*) _err dcd "unknown flag: $1  (try: dcd --help)"; return 1 ;;
            *)
                if [[ -n "$pattern" ]]; then
                    _err dcd "only one pattern is accepted (got '$pattern' and '$1')"
                    return 1
                fi
                pattern="$1"
                ;;
        esac
        shift
    done

    if [[ -z "$pattern" ]]; then
        _err dcd "a container pattern is required  (try: dcd --help)"
        return 1
    fi

    # --- match containers ---------------------------------------------------
    local containers=() name
    while IFS= read -r name; do
        [[ -n "$name" ]] && containers+=("$name")
    done <<< "$(_list_containers)"

    if [[ ${#containers[@]} -eq 0 ]]; then
        _err dcd "no containers found — is the docker daemon reachable?"
        return 1
    fi

    local matched=()
    for name in "${containers[@]}"; do
        if [[ "$name" =~ $pattern ]]; then
            matched+=("$name")
        fi
    done

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err dcd "no container matched: $pattern"
        printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${containers[*]}" >&2
        return 1
    fi

    # --- read the compose labels for every match, in one call ---------------
    local info
    info=$(_container_compose_info "${matched[@]}") || {
        _err dcd "could not inspect: ${matched[*]}"
        return 1
    }

    # Group the matches by destination. Several containers of one project is the
    # normal case, not a conflict — they all point at the same directory.
    # Parallel arrays would need indexing to pair up, and indexing is the one
    # thing that cannot be written once for bash and zsh — bash counts from 0,
    # zsh from 1. One array of joined records keeps every read an iteration.
    local dirs=() entries=()
    local nl='
'
    local members="" running=0 total=0
    local cstatus project service workdir config_files seen d i project_l workdir_l config_l
    local chosen_dir="" chosen_project="" chosen_config=""

    {
        while IFS= read -r cstatus; do
            IFS= read -r project
            IFS= read -r service
            IFS= read -r workdir
            IFS= read -r config_files

            # Containers not created by compose have no directory to offer.
            [[ -z "$workdir" ]] && continue

            seen=false
            for d in "${dirs[@]}"; do
                [[ "$d" == "$workdir" ]] && seen=true && break
            done
            if [[ "$seen" == false ]]; then
                dirs+=("$workdir")
                entries+=("${project}|${workdir}|${config_files}")
            fi
        done
    } <<< "$info"

    if [[ ${#dirs[@]} -eq 0 ]]; then
        _err dcd "no match was created by docker compose: ${matched[*]}"
        printf "  ${CDIM}no com.docker.compose labels — nowhere to jump to${CR}\n" >&2
        return 1
    fi

    if [[ ${#dirs[@]} -gt 1 ]]; then
        _err dcd "'$pattern' spans ${#dirs[@]} projects"
        local rec rec_project rec_rest rec_dir
        for rec in "${entries[@]}"; do
            rec_project="${rec%%|*}"
            rec_rest="${rec#*|}"
            rec_dir="${rec_rest%%|*}"
            printf "  ${CMA}%s${CR}  ${CDIM}%s${CR}\n" "${rec_project:-?}" "$rec_dir" >&2
        done
        printf "  ${CDIM}→ narrow the pattern${CR}\n" >&2
        return 1
    fi

    local rec rest
    for rec in "${entries[@]}"; do
        chosen_project="${rec%%|*}"
        rest="${rec#*|}"
        chosen_dir="${rest%%|*}"
        chosen_config="${rest#*|}"
        break
    done

    local workdir="$chosen_dir"
    local project="$chosen_project"
    local config_files="$chosen_config"

    # Count what is up, and name the containers we matched.
    {
        while IFS= read -r cstatus; do
            IFS= read -r project_l
            IFS= read -r service
            IFS= read -r workdir_l
            IFS= read -r config_l
            [[ "$workdir_l" != "$workdir" ]] && continue
            total=$(( total + 1 ))
            [[ "$cstatus" == "running" ]] && running=$(( running + 1 ))
            members+="${members:+ }${service:-?}"
        done
    } <<< "$info"

    # --- print-only mode ----------------------------------------------------
    # Nothing but the path on stdout, so `cd "$(dcd -p redmine)"` gets exactly
    # what it asked for and not a line of decoration.
    if [[ "$print_only" == true ]]; then
        printf '%s\n' "$workdir"
        [[ "$info_only" == false ]] && return 0
    fi

    # --- details ------------------------------------------------------------
    # Compose files are absolute in the labels. Shown relative to the project
    # directory when they live inside it, which is the normal case and reads far
    # better than five repetitions of the same prefix.
    local files_display="" item
    if [[ -n "$config_files" ]]; then
        while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            case "$item" in
                "$workdir"/*) item="${item#"$workdir"/}" ;;
            esac
            files_display+="${files_display:+$nl}${item}"
        done <<< "$(_split_commas "$config_files")"
    fi

    # Green only when the whole project is up: a half-running project is
    # something you want to notice on the way in.
    local status_color="$CYE"
    (( running == total )) && (( total > 0 )) && status_color="$CGR"

    if [[ "$print_only" == false ]]; then
        {
            printf "  %s ${CBL}${CB}%s${CR}  ${CDIM}·${CR}  ${status_color}%s/%s running${CR}\n" \
                "$(_icon docker)" "$project" "$running" "$total"
            printf "  %s ${CMA}%s${CR}\n" "$(_icon services)" "$members"
            if [[ -n "$files_display" ]]; then
                while IFS= read -r item; do
                    [[ -n "$item" ]] && printf "  %s ${CWH}%s${CR}\n" "$(_icon file)" "$item"
                done <<< "$files_display"
            fi
            printf "  %s ${CCY}%s${CR}\n" "$(_icon dir)" "$workdir"
            _hr
        } >&2
    fi

    [[ "$info_only" == true ]] && return 0

    # --- go -----------------------------------------------------------------
    if [[ ! -d "$workdir" ]]; then
        _err dcd "the project directory no longer exists: $workdir"
        return 1
    fi

    cd "$workdir" || {
        _err dcd "could not enter: $workdir"
        return 1
    }
}
