#!/usr/bin/env bash
# docker-aliases — di: list images, and say which ones you could delete.
#
# The old di was `docker images | docker-color-output` — a list. But the
# question you are usually asking is not "what is here", it is "what can I
# get rid of": on this machine 15 of 32 images are dangling and 14 more have
# no container using them.
#
# So the listing carries a USED column, dangling images are labelled rather
# than left as <none>:<none>, and the footer says how much is actually
# reclaimable.
#
# Design contract:
#   * Dangling images are SHOWN, not hidden. They are half the list and they
#     are the answer to the question — the opposite call from dver, where what
#     got hidden was noise.
#   * The reclaimable figure comes from `docker system df`, never from adding
#     up sizes. Images share layers, so summing the dangling and unused ones
#     here gives 10.32GB where the truth is 4.72GB. A footer that overstates by
#     double is worse than no footer.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_di_help() {
    printf "${CB}${CCY}di${CR} — list images and what is reclaimable\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}di${CR} [${CYE}flags${CR}] [${CMA}pattern...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-u${CR}                 Only images no container is using\n"
    printf "  ${CYE}-d${CR}                 Only dangling images ${CI}(untagged leftovers)${CR}\n"
    printf "  ${CYE}-t${CR}                 Show the creation date instead of how long ago\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Short flags combine:${CR} ${CGR}-ut${CR} ${CI}is the same as${CR} ${CGR}-u -t${CR}\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR} matched against ${CB}repository:tag${CR},\n"
    printf "  as in ${CB}dps${CR} and ${CB}dclt${CR}. With no pattern, every image is listed.\n\n"

    printf "${CCY}THE USED COLUMN${CR}\n"
    printf "  How many containers refer to the image. A ${CB}—${CR} means none do, which\n"
    printf "  makes it a deletion candidate; ${CB}dangling${CR} means it lost its tag to a\n"
    printf "  rebuild and nothing refers to it by name at all.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}di${CR}                            Every image\n"
    printf "  ${CGR}di redmine${CR}                    Only images matching 'redmine'\n"
    printf "  ${CGR}di -u${CR}                         Only what nothing is using\n"
    printf "  ${CGR}di -d${CR}                         Only the dangling ones\n"
    printf "  ${CGR}di -ut${CR}                        Unused, with exact dates\n"
}

# ---------------------------------------------------------------------------
# di
# ---------------------------------------------------------------------------

di() {
    case "$1" in
        -h|--help) _di_help; return 0 ;;
    esac

    # --- expand clustered short flags: -ut → -u -t --------------------------
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
    local unused_only=false dangling_only=false absolute=false patterns=()

    set -- "${expanded[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _di_help; return 0 ;;
            -u) unused_only=true ;;
            -d) dangling_only=true ;;
            -t) absolute=true ;;
            -*) _err di "unknown flag: $1  (try: di --help)"; return 1 ;;
            *)  patterns+=("$1") ;;
        esac
        shift
    done

    # --- collect ------------------------------------------------------------
    # Two queries, because `docker images` HIDES dangling images by default —
    # the fifteen leftovers on this machine simply do not appear. `-a` would
    # reveal them, but on an older daemon it also drags in every intermediate
    # build layer, which floods the list. Asking for the dangling ones by name
    # gets exactly them, on any version.
    local fmt='{{.Repository}}	{{.Tag}}	{{.ID}}	{{.CreatedSince}}	{{.CreatedAt}}	{{.Size}}	{{.Containers}}'

    local tagged raw
    tagged=$(docker images --format "$fmt" 2>/dev/null) || {
        _err di "could not reach the docker daemon"
        return 1
    }
    raw="$tagged"

    local loose
    loose=$(docker images -f dangling=true --format "$fmt" 2>/dev/null)
    [[ -n "$loose" ]] && raw="${raw}
${loose}"

    local rows="" nl='
'
    local total=0 shown=0 dangling=0 unused=0
    local repo tag iid since created_at size containers
    local name when used pat keep is_dangling
    # _DA_R carries the helpers' results back without a subshell. Declared
    # local here so the _into calls below write into this function's scope
    # and nothing leaks to the global namespace.
    local _DA_R

    while IFS=$'\t' read -r repo tag iid since created_at size containers || [[ -n "$repo" ]]; do
        [[ -z "$iid" ]] && continue
        total=$(( total + 1 ))

        # A dangling image lost its tag to a rebuild: docker reports it as
        # <none>:<none>, which reads like a bug rather than a state.
        is_dangling=false
        if [[ "$repo" == "<none>" ]]; then
            is_dangling=true
            dangling=$(( dangling + 1 ))
        fi
        [[ "$containers" == "0" ]] && unused=$(( unused + 1 ))

        [[ "$dangling_only" == true && "$is_dangling" == false ]] && continue
        [[ "$unused_only" == true && "$containers" != "0" ]] && continue

        name="$repo"
        [[ "$is_dangling" == true ]] && name="<dangling>" && tag=""

        if [[ ${#patterns[@]} -gt 0 ]]; then
            keep=false
            for pat in "${patterns[@]}"; do
                if [[ "${repo}:${tag}" =~ $pat ]]; then keep=true; break; fi
            done
            [[ "$keep" == false ]] && continue
        fi

        if [[ "$absolute" == true ]]; then
            _short_timestamp_into "$created_at"
        else
            _short_duration_into "$since"
        fi
        when="$_DA_R"

        # The count matters more than the fact: 6 containers on one image says
        # something a checkmark would not.
        used="$containers"
        [[ "$containers" == "0" ]] && used="—"

        rows+="${rows:+$nl}${name}	${tag:-—}	${iid}	${when}	${size}	${used}"
        shown=$(( shown + 1 ))
    done <<< "$raw"

    _render_container_table "docker images" "$shown" "$total" "${patterns[*]}" \
        "REPOSITORY" "TAG" "IMAGE ID" "CREATED" "SIZE" "USED" "$rows" \
        "white,cyan,dim,dim,green,yellow"

    # --- footer -------------------------------------------------------------
    # Only when looking at everything: on a filtered view these totals describe
    # the machine, not the rows above them, and that reads as a lie.
    if [[ ${#patterns[@]} -eq 0 && "$unused_only" == false && "$dangling_only" == false ]]; then
        local reclaim
        reclaim=$(docker system df --format '{{.Type}}	{{.Reclaimable}}' 2>/dev/null \
            | while IFS=$'\t' read -r t r; do
                  [[ "$t" == "Images" ]] && { printf '%s' "$r"; break; }
              done)

        if (( dangling > 0 || unused > 0 )); then
            printf "  %s ${CDIM}%d dangling · %d unused${CR}" "$(_icon dir)" "$dangling" "$unused"
            [[ -n "$reclaim" ]] && printf " ${CDIM}·${CR} ${CYE}%s reclaimable${CR}" "$reclaim"
            printf "\n"
        fi
    fi
}

# Completion source: repository:tag pairs.
_di_candidates() {
    docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
        | grep -v '^<none>' | LC_ALL=C sort -u
}
