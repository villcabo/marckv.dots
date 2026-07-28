#!/usr/bin/env bash
# docker-aliases v2 — dcver: which build is actually running in each service.
#
# Reads git.properties out of running containers — the file the git-commit-id
# plugin bakes into a Spring Boot / JHipster artifact — and answers the question
# you are really asking: is this the version I think it is?
#
# Replaces v1's dcpr, and changes what it shows. v1 printed the 40-character
# commit hash and the full commit message; on a merge commit that is a
# paragraph. Meanwhile it ignored the three fields that matter most:
#
#   app.version      1.1.0-d3cabc9   the answer, in one string
#   git.dirty        true            built from uncommitted changes
#   git.commit.time  2024-04-18…     how old this build is
#
# git.dirty deserves the emphasis it gets here: a dirty build cannot be
# reproduced from the repository, so "it works on that commit" is not a claim
# anyone can check.
#
# Configuration:
#   DOCKER_ALIASES_GIT_PROPS  Extra paths to search, ":"-separated. Tried first.

# Where the file usually lives. Ordered by how often it is the right answer.
_DAV2_PROP_PATHS='/app/resources/git.properties
/app/BOOT-INF/classes/git.properties
/app/classes/git.properties
/app/git.properties
/deployments/git.properties
/usr/share/nginx/html/git.properties
/usr/share/nginx/html/assets/git.properties'

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcver_help() {
    printf "${CB}${CCY}dcver${CR} — show the build running in each service\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcver${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-r${CR}                 Raw: print the whole git.properties instead of a table\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against service names,\n"
    printf "  as in ${CB}dclt${CR}. With no pattern, every service is queried.\n\n"

    printf "${CCY}WHERE IT LOOKS${CR}\n"
    printf "  Seven common locations, Spring Boot and nginx included. Add your own\n"
    printf "  with ${CB}DOCKER_ALIASES_GIT_PROPS${CR} — \":\"-separated, searched first:\n"
    printf "    ${CDIM}export DOCKER_ALIASES_GIT_PROPS=/opt/app/git.properties${CR}\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcver${CR}                         Every service, as a table\n"
    printf "  ${CGR}dcver api${CR}                     Only services matching 'api'\n"
    printf "  ${CGR}dcver -r api${CR}                  The raw file, every field\n\n"

    printf "${CCY}THE DIRTY FLAG${CR}\n"
    printf "  ${CRE}${CB}⚠ dirty${CR} means the artifact was built from a working tree with\n"
    printf "  uncommitted changes. Nobody can rebuild it from the commit it names,\n"
    printf "  so treat the commit as a hint rather than a fact.\n"
}

# ---------------------------------------------------------------------------
# dcver
# ---------------------------------------------------------------------------

dcver() {
    case "$1" in
        -h|--help) _dcver_help; return 0 ;;
    esac

    # --- parse --------------------------------------------------------------
    local raw=false
    local files=() env_files=() profiles=() patterns=()
    local profile_item

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dcver_help; return 0 ;;
            -r) raw=true ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcver "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcver "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcver "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            -*) _err dcver "unknown flag: $1  (try: dcver --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcver "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcver "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcver "env file not found: $file"; return 1; }
    done

    # --- match services -----------------------------------------------------
    local services=() svc
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && services+=("$svc")
    done <<< "$(_get_compose_services --profiles "${profiles[*]}" "${files[@]}")"

    if [[ ${#services[@]} -eq 0 ]]; then
        _err dcver "no services found in the compose file"
        return 1
    fi

    local matched=() pat
    if [[ ${#patterns[@]} -eq 0 ]]; then
        matched=("${services[@]}")
    else
        for svc in "${services[@]}"; do
            for pat in "${patterns[@]}"; do
                if [[ "$svc" =~ $pat ]]; then matched+=("$svc"); break; fi
            done
        done
        if [[ ${#matched[@]} -eq 0 ]]; then
            _err dcver "no service matched: ${patterns[*]}"
            printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${services[*]}" >&2
            return 1
        fi
    fi

    # --- the lookup, run inside each container ------------------------------
    # One `sh -c` per service that walks the candidate paths and prints the
    # first hit, prefixed with where it came from.
    local search_paths="$_DAV2_PROP_PATHS"
    [[ -n "${DOCKER_ALIASES_GIT_PROPS:-}" ]] && \
        search_paths="$(_split_on ':' "$DOCKER_ALIASES_GIT_PROPS")
$search_paths"

    local probe='for f in'
    while IFS= read -r file; do
        [[ -n "$file" ]] && probe+=" '$file'"
    done <<< "$search_paths"
    probe+='; do [ -f "$f" ] && { echo "@@PATH@@$f"; cat "$f"; exit 0; }; done; exit 1'

    local base=(docker compose)
    local item
    for item in "${files[@]}";     do base+=(-f "$item"); done
    for item in "${env_files[@]}"; do base+=(--env-file "$item"); done
    for item in "${profiles[@]}";  do base+=(--profile "$item"); done

    # Queried concurrently: each exec is a round trip, and a project with eight
    # services should not cost eight of them end to end.
    local tmp
    tmp=$(mktemp -d) || { _err dcver "could not create a temp directory"; return 1; }

    local idx=0
    for svc in "${matched[@]}"; do
        idx=$(( idx + 1 ))
        {
            "${base[@]}" exec -T "$svc" sh -c "$probe" 2>/dev/null > "${tmp}/${idx}.out"
            printf '%s' "$svc" > "${tmp}/${idx}.svc"
        } &
    done
    wait

    # --- raw mode -----------------------------------------------------------
    if [[ "$raw" == true ]]; then
        local i=0 out svc_name
        for svc in "${matched[@]}"; do
            i=$(( i + 1 ))
            out=$(cat "${tmp}/${i}.out" 2>/dev/null)
            printf "${CB}${CMA}# %s${CR}\n" "$svc"
            if [[ -z "$out" ]]; then
                printf "  ${CDIM}no git.properties found${CR}\n\n"
                continue
            fi
            # Pure shell: these commands run on minimal servers where anything
            # beyond a POSIX shell is a bet. The distro matrix caught an `sd`
            # here, which exists on exactly one machine — this one.
            local first="${out%%$'\n'*}"
            printf "  ${CDIM}%s${CR}\n" "${first#@@PATH@@}"
            printf '%s\n\n' "${out#*$'\n'}"
        done
        rm -rf "$tmp"
        return 0
    fi

    # --- table --------------------------------------------------------------
    local rows="" nl='
'
    local found=0 i=0 out props version commit branch dirty when flags
    for svc in "${matched[@]}"; do
        i=$(( i + 1 ))
        out=$(cat "${tmp}/${i}.out" 2>/dev/null)

        if [[ -z "$out" ]]; then
            rows+="${rows:+$nl}${svc}	—	—	—	—	no git.properties"
            continue
        fi
        found=$(( found + 1 ))

        props="${out#*$'\n'}"
        version=$(_prop_value app.version "$props") || version=""
        [[ -z "$version" ]] && version=$(_prop_value git.build.version "$props")
        commit=$(_prop_value git.commit.id.abbrev "$props") || commit=""
        if [[ -z "$commit" ]]; then
            commit=$(_prop_value git.commit.id "$props")
            commit="${commit:0:7}"
        fi
        branch=$(_prop_value git.branch "$props") || branch=""
        dirty=$(_prop_value git.dirty "$props") || dirty=""
        when=$(_age_of "$(_prop_value git.commit.time "$props")")

        flags=""
        [[ "$dirty" == "true" ]] && flags="$(_icon warn) dirty"

        rows+="${rows:+$nl}${svc}	${version:-—}	${commit:-—}	${branch:-—}	${when:-—}	${flags}"
    done
    rm -rf "$tmp"

    _render_container_table "compose versions" "$found" "${#matched[@]}" "${patterns[*]}" \
        "SERVICE" "VERSION" "COMMIT" "BRANCH" "BUILT" "" "$rows" \
        "white,cyan,dim,blue,dim,red"
}

# Completion source: service names, honouring any -P already typed.
_dcver_candidates() {
    _get_compose_services --profiles "$(_profiles_from_words "$@")" 2>/dev/null
}
