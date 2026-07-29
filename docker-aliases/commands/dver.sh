#!/usr/bin/env bash
# docker-aliases — dver: which build is running in each container, host-wide.
#
# The same question dcver answers, asked of the whole machine instead of one
# compose project — the pairing dps/dcps already established:
#
#   dps  ↔ dcps    what is running
#   dver ↔ dcver   what build is running
#
# Design contract:
#   * Containers WITHOUT a git.properties are hidden, and counted in a footer.
#     Most of a host is postgres, keycloak and traefik; fifteen rows of "—" to
#     find three answers is not a table, it is a haystack. The header still says
#     "3 of 17", so nothing is silently narrowed.
#   * PROJECT earns its column here. Host-wide the containers come from many
#     projects, and unlike dps there is no IMAGE column crowding the row.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dver_help() {
    printf "${CB}${CCY}dver${CR} — show the build running in each container\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dver${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Also list containers with no git.properties\n"
    printf "  ${CYE}-r${CR}                 Raw: print the whole git.properties instead of a table\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-ar${CR} ${CI}is the same as${CR} ${CGR}-a -r${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against container names,\n"
    printf "  as in ${CB}dps${CR} and ${CB}dcd${CR}. With no pattern, every container is queried.\n\n"

    printf "${CCY}SCOPE${CR}\n"
    printf "  ${CB}dver${CR} covers this whole host. For one compose project, ${CB}dcver${CR} takes\n"
    printf "  the same flags and speaks in service names.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dver${CR}                          Every container carrying a version\n"
    printf "  ${CGR}dver api${CR}                      Only containers matching 'api'\n"
    printf "  ${CGR}dver -a${CR}                       Include the ones without one\n"
    printf "  ${CGR}dver -r api${CR}                   The raw file, every field\n\n"

    printf "${CCY}THE DIRTY FLAG${CR}\n"
    printf "  ${CRE}${CB}⚠ dirty${CR} means the artifact was built from a working tree with\n"
    printf "  uncommitted changes, so it cannot be rebuilt from the commit it names.\n"
}

# ---------------------------------------------------------------------------
# dver
# ---------------------------------------------------------------------------

dver() {
    case "$1" in
        -h|--help) _dver_help; return 0 ;;
    esac

    # --- expand clustered short flags: -ar → -a -r --------------------------
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
    local show_all=false raw=false patterns=()

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dver_help; return 0 ;;
            -a) show_all=true ;;
            -r) raw=true ;;
            -*) _err dver "unknown flag: $1  (try: dver --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- collect containers -------------------------------------------------
    # Name and project in one call; the exec that follows is the expensive part.
    local listing
    listing=$(docker ps --format '{{.Names}}	{{.Label "com.docker.compose.project"}}' 2>/dev/null) || {
        _err dver "could not reach the docker daemon"
        return 1
    }

    # One array of joined records rather than two parallel ones: pairing them up
    # would need indexing, and that is the one thing with no portable spelling
    # (bash counts from 0, zsh from 1).
    local entries=() name project pat keep
    local total=0

    while IFS=$'\t' read -r name project || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue
        total=$(( total + 1 ))

        if [[ ${#patterns[@]} -gt 0 ]]; then
            keep=false
            for pat in "${patterns[@]}"; do
                if [[ "$name" =~ $pat ]]; then keep=true; break; fi
            done
            [[ "$keep" == false ]] && continue
        fi

        entries+=("${name}	${project:-—}")
    done <<< "$listing"

    if [[ ${#entries[@]} -eq 0 ]]; then
        if [[ ${#patterns[@]} -gt 0 ]]; then
            _err dver "no container matched: ${patterns[*]}"
        else
            _err dver "no containers are running"
        fi
        return 1
    fi

    # --- ask them all at once -----------------------------------------------
    local probe
    probe=$(_git_props_probe)

    local tmp
    tmp=$(mktemp -d) || { _err dver "could not create a temp directory"; return 1; }

    local idx=0 entry
    for entry in "${entries[@]}"; do
        idx=$(( idx + 1 ))
        docker exec "${entry%%	*}" sh -c "$probe" 2>/dev/null > "${tmp}/${idx}.out" &
    done
    wait

    # --- raw mode -----------------------------------------------------------
    if [[ "$raw" == true ]]; then
        local out first
        idx=0
        for entry in "${entries[@]}"; do
            idx=$(( idx + 1 ))
            name="${entry%%	*}"
            out=$(cat "${tmp}/${idx}.out" 2>/dev/null)
            [[ -z "$out" && "$show_all" == false ]] && continue
            printf "${CB}${CMA}# %s${CR}\n" "$name"
            if [[ -z "$out" ]]; then
                printf "  ${CDIM}no git.properties${CR}\n\n"
                continue
            fi
            first="${out%%$'\n'*}"
            printf "  ${CDIM}%s${CR}\n" "${first#@@PATH@@}"
            printf '%s\n\n' "${out#*$'\n'}"
        done
        rm -rf "$tmp"
        return 0
    fi

    # --- table --------------------------------------------------------------
    local rows="" nl='
'
    local found=0 hidden=0 hidden_names=""
    local out props version commit branch when dirty built

    idx=0
    for entry in "${entries[@]}"; do
        idx=$(( idx + 1 ))
        name="${entry%%	*}"
        project="${entry#*	}"
        out=$(cat "${tmp}/${idx}.out" 2>/dev/null)

        if [[ -z "$out" ]]; then
            hidden=$(( hidden + 1 ))
            hidden_names+="${hidden_names:+, }${name}"
            [[ "$show_all" == false ]] && continue
            rows+="${rows:+$nl}${name}	${project}	—	—	—	—"
            continue
        fi
        found=$(( found + 1 ))

        props="${out#*$'\n'}"
        IFS=$'\t' read -r version commit branch when dirty <<< "$(_git_props_row "$props")"

        # The flag rides along with BUILT: it is the last column, so it can grow
        # without pushing anything out of alignment.
        built="$when"
        [[ "$dirty" == "true" ]] && built+="  $(_icon warn) dirty"

        rows+="${rows:+$nl}${name}	${project}	${version}	${commit}	${branch}	${built}"
    done
    rm -rf "$tmp"

    _render_container_table "docker versions" "$found" "$total" "${patterns[*]}" \
        "NAME" "PROJECT" "VERSION" "COMMIT" "BRANCH" "BUILT" "$rows" \
        "white,dim,cyan,dim,blue,green"

    # Say what was left out, and name enough of it to be checkable.
    if (( hidden > 0 )) && [[ "$show_all" == false ]]; then
        local shortlist="$hidden_names"
        (( ${#shortlist} > 60 )) && shortlist="${shortlist:0:57}…"
        printf "  ${CDIM}%s %d with no git.properties (%s)  ${CR}${CDIM}-a to show${CR}\n" \
            "$(_icon dir)" "$hidden" "$shortlist"
    fi
}

# Completion source: container names across the host.
_dver_candidates() { _list_containers 2>/dev/null; }
