#!/usr/bin/env bash
# docker-aliases v2 — dcdown: stop and remove compose services.
#
# Design contract for this command:
#   * `dcdown` and `dcdown -v` are not the same command. Removing containers is
#     recoverable — you run dcup again. Removing named volumes destroys data and
#     nothing brings it back. The two get different confirmations.
#   * With -v the preview names every volume that will be deleted, and the
#     prompt asks for the PROJECT NAME rather than "yes". Typing "yes" all day
#     is a reflex; typing the project name is not.
#   * The preview reports what is actually RUNNING when the daemon can be
#     reached, falling back to the declared services when it cannot — and it
#     says which of the two you are looking at.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcdown_help() {
    printf "${CB}${CCY}dcdown${CR} — stop and remove Docker Compose services\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcdown${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-v${CR}                 ${CRE}${CB}Delete named volumes${CR} ${CI}(destroys data)${CR}\n"
    printf "  ${CYE}-O${CR}                 Remove orphan containers ${CDIM}--remove-orphans${CR}\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-vO${CR} ${CI}is the same as${CR} ${CGR}-v -O${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against service names,\n"
    printf "  exactly as in ${CB}dclt${CR}. With no pattern the whole project comes down.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcdown${CR}                            Stop and remove everything\n"
    printf "  ${CGR}dcdown api${CR}                        Only services matching 'api'\n"
    printf "  ${CGR}dcdown 'api|worker'${CR}               Two patterns at once\n"
    printf "  ${CGR}dcdown -O${CR}                         Also clear orphan containers\n"
    printf "  ${CGR}dcdown -v${CR}                         ${CRE}Also delete named volumes${CR}\n"
    printf "  ${CGR}dcdown -f prod.yml${CR}                Custom compose file\n\n"

    printf "${CCY}CONFIRMATION${CR}\n"
    printf "  Without ${CB}-v${CR} you type ${CB}yes${CR}: containers and networks come back with\n"
    printf "  ${CB}dcup${CR}, so the cost of a mistake is a restart.\n\n"
    printf "  With ${CB}-v${CR} you type the ${CB}project name${CR}. Deleting volumes destroys data\n"
    printf "  permanently, and a prompt you answer the same way every time stops\n"
    printf "  being a prompt at all.\n"
}

# ---------------------------------------------------------------------------
# dcdown
# ---------------------------------------------------------------------------

dcdown() {
    case "$1" in
        -h|--help) _dcdown_help; return 0 ;;
    esac

    # --- expand clustered short flags: -vO → -v -O --------------------------
    local expanded=() arg rest char i
    for arg in "$@"; do
        if [[ "$arg" == --* ]]; then
            expanded+=("$arg")
        elif [[ "$arg" == -?* ]]; then
            rest="${arg#-}"
            i=0
            while (( i < ${#rest} )); do
                char="${rest:$i:1}"
                expanded+=("-$char")
                i=$(( i + 1 ))
            done
        else
            expanded+=("$arg")
        fi
    done

    # --- parse --------------------------------------------------------------
    local remove_volumes=false remove_orphans=false
    local files=() env_files=() profiles=() patterns=()
    local profile_item

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcdown_help; return 0 ;;
            -v) remove_volumes=true ;;
            -O) remove_orphans=true ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcdown "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcdown "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcdown "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dcdown "unknown flag: $1  (try: dcdown --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcdown "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        # May be two lines: the base file and its override sibling.
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcdown "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcdown "env file not found: $file"; return 1; }
    done

    # --- what is actually out there ----------------------------------------
    local declared=() running=() svc
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && declared+=("$svc")
    done <<< "$(_get_compose_services --profiles "${profiles[*]}" "${files[@]}")"

    if [[ ${#declared[@]} -eq 0 ]]; then
        _err dcdown "no services found in the compose file"
        return 1
    fi

    # A failed lookup means "cannot ask", not "nothing is running" — the two
    # deserve different words right before a destructive command.
    local daemon_ok=true
    local running_out
    if running_out=$(_get_running_services "${files[@]}"); then
        while IFS= read -r svc; do
            [[ -n "$svc" ]] && running+=("$svc")
        done <<< "$running_out"
    else
        daemon_ok=false
    fi

    # --- match services -----------------------------------------------------
    # Patterns are matched against the DECLARED set: it is the stable list, and
    # naming a stopped service should still be a valid thing to ask for.
    local matched=() pat
    if [[ ${#patterns[@]} -gt 0 ]]; then
        for svc in "${declared[@]}"; do
            for pat in "${patterns[@]}"; do
                if [[ "$svc" =~ $pat ]]; then
                    matched+=("$svc")
                    break
                fi
            done
        done
        if [[ ${#matched[@]} -eq 0 ]]; then
            _err dcdown "no service matched: ${patterns[*]}"
            printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${declared[*]}" >&2
            return 1
        fi
    fi

    # What the preview should show as the affected set.
    local preview_services
    if [[ ${#matched[@]} -gt 0 ]]; then
        preview_services="${matched[*]}"
    elif [[ "$daemon_ok" == true && ${#running[@]} -gt 0 ]]; then
        preview_services="${running[*]}"
    else
        preview_services="${declared[*]}"
    fi

    # --- volumes ------------------------------------------------------------
    local volumes=() volume_line=""
    if [[ "$remove_volumes" == true ]]; then
        local vol_out
        if vol_out=$(_get_compose_volumes "${files[@]}"); then
            while IFS= read -r svc; do
                [[ -n "$svc" ]] && volumes+=("$svc")
            done <<< "$vol_out"
            volume_line="${volumes[*]}"
        fi
    fi

    # --- build the command --------------------------------------------------
    local cmd=(docker compose)
    local shown="${CDIM}docker compose${CR}"
    local item

    for item in "${files[@]}"; do
        cmd+=(-f "$item")
        shown+=" ${CDIM}-f${CR} ${CWH}${item}${CR}"
    done
    for item in "${env_files[@]}"; do
        cmd+=(--env-file "$item")
        shown+=" ${CDIM}--env-file${CR} ${CWH}${item}${CR}"
    done
    for item in "${profiles[@]}"; do
        cmd+=(--profile "$item")
        shown+=" ${CDIM}--profile${CR} ${CBL}${item}${CR}"
    done

    cmd+=(down)
    shown+=" ${CRE}${CB}down${CR}"

    local flags_line=""
    if [[ "$remove_volumes" == true ]]; then
        cmd+=(--volumes)
        shown+=" ${CRE}${CB}--volumes${CR}"
        flags_line+=" --volumes"
    fi
    if [[ "$remove_orphans" == true ]]; then
        cmd+=(--remove-orphans)
        shown+=" ${CYE}--remove-orphans${CR}"
        flags_line+=" --remove-orphans"
    fi

    for item in "${matched[@]}"; do
        cmd+=("$item")
        shown+=" ${CMA}${item}${CR}"
    done

    # --- preview ------------------------------------------------------------
    local files_display
    files_display=$(printf '%s\n' "${files[@]}")

    _render_preview "compose down" "$files_display" "$preview_services" \
                    "${flags_line# }" "$shown" "$volume_line"

    # Say plainly which picture you are looking at.
    if [[ "$daemon_ok" == false ]]; then
        _note "could not reach the docker daemon — showing declared services"
    elif [[ ${#running[@]} -eq 0 ]]; then
        _note "nothing is running — this only removes networks"
    fi

    # --- confirm ------------------------------------------------------------
    if [[ "$remove_volumes" == true ]]; then
        local project
        project=$(_get_compose_project "${files[@]}") || project="delete"

        local warning
        if [[ ${#volumes[@]} -gt 0 ]]; then
            warning="This deletes ${#volumes[@]} volume(s) permanently. Type the project name to confirm:"
        else
            warning="This deletes any anonymous volumes permanently. Type the project name to confirm:"
        fi

        _confirm_typed "$project" "$warning" || {
            printf "  ${CB}${CYE}Cancelled${CR}\n" >&2
            return 1
        }
    else
        _confirm_operation "Continue?" "$(_action_color down)" || {
            printf "  ${CB}${CYE}Cancelled${CR}\n" >&2
            return 1
        }
    fi

    # --- run ----------------------------------------------------------------
    "${cmd[@]}"
}
