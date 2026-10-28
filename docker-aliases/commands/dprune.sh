#!/usr/bin/env bash
# docker-aliases — dprune: delete what docker no longer uses, after showing
# exactly what that is, and why each thing is on the list.
#
# `docker system prune` asks "Are you sure?" over a paragraph of categories.
# It never says WHICH containers, networks or images — and its categories
# hide a cascade: it removes stopped containers FIRST, and that frees the
# networks, images and volumes those containers were holding, which the later
# steps then remove too. Measured on a real host: 23 of 39 networks had nothing
# running on them and all 23 were held by stopped containers. A preview that
# asked "which networks are unused?" would answer none, and the prune would
# delete 23.
#
# Design contract:
#   * The preview names every item and says WHY it goes: already unused, or
#     freed because the stopped containers holding it go first.
#   * What it shows is what it deletes: each item is removed by its own ID or
#     reference, never through a prune that re-evaluates at run time. And never
#     with -f — so anything that started using an item between the preview
#     and the confirmation makes docker refuse that one item instead of
#     deleting it.
#   * What is KEPT is said too: running containers and everything they use;
#     volumes unless -v; tagged images and the build cache unless -a.
#   * Every number is exact or labelled as an estimate. The build cache is
#     only touched with -a, because that is the case `builder du` reports
#     exactly; a default `builder prune` frees a share nobody can preview.
#   * The confirmation is the docker HOST's name, typed. Everything here is
#     irreversible, and `yes` is the answer to every other prompt. The name
#     comes from `docker info`, so under DOCKER_HOST it is the remote machine's
#     — exactly the one you are about to clean.
#   * -n is a dry run: the full lists, on stdout, and nothing deleted.
#   * No -y. DOCKER_ALIASES_AUTO_YES exists for tests and CI only.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dprune_help() {
    printf "${CB}${CCY}dprune${CR} — delete what docker no longer uses, after showing exactly what\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dprune${CR} [${CYE}-a${CR}] [${CYE}-v${CR}] [${CYE}-n${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Also every image no container uses, and the build cache\n"
    printf "  ${CYE}-v${CR}                 Also every volume no remaining container uses ${CRE}(data!)${CR}\n"
    printf "  ${CYE}-n${CR}                 Dry run: the full lists, nothing deleted\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}WHAT GOES${CR}\n"
    printf "  ${CB}always${CR}   stopped containers, the networks they leave unused, dangling images\n"
    printf "  ${CB}-a${CR}       + tagged images no container uses, + the build cache\n"
    printf "  ${CB}-v${CR}       + volumes no remaining container uses\n"
    printf "  Running containers, and everything they use, are never touched.\n\n"

    printf "${CCY}THE CASCADE${CR}\n"
    printf "  Removing a stopped container frees its networks, images and volumes —\n"
    printf "  so they go too. The preview marks each one ${CYE}freed${CR} or ${CDIM}unused${CR}, so\n"
    printf "  nothing on the list is a surprise.\n\n"

    printf "${CCY}CONFIRMATION${CR}\n"
    printf "  Type the docker host's name. Under DOCKER_HOST that is the remote one.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dprune -n${CR}             See everything it would delete\n"
    printf "  ${CGR}dprune${CR}                Containers, freed networks, dangling images\n"
    printf "  ${CGR}dprune -a${CR}             Plus unused images and the build cache\n"
    printf "  ${CGR}dprune -av${CR}            Everything unused, volumes included\n"
}

# ---------------------------------------------------------------------------
# Preview helpers
# ---------------------------------------------------------------------------

# The default preview shows this many items per section, then a count and a
# pointer to -n. A preview of 160 lines is not read; a capped one with the
# full number in its heading is. Volumes are never capped: they hold data.
_DPRUNE_CAP=10

# _dprune_section <title> <count> [detail]
_dprune_section() {
    printf "\n  ${CRE}${CB}%s${CR}  ${CB}%s${CR}" "$1" "$2"
    [[ -n "${3:-}" ]] && printf "  ${CDIM}%s${CR}" "$3"
    printf "\n"
}

# _dprune_items <records> <cap> — one line per record, first column padded
#
# Records are "name<TAB>detail<TAB>detail<TAB>why". The last field is coloured
# by what it says: "freed …" in yellow — the cascade, the part nobody expects —
# and anything else dim.
_dprune_items() {
    local records="$1" cap="$2" line tab=$'\t' n=0 w=0 w2=0 c1 m rest a b c total=0 wc pa
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        total=$(( total + 1 ))
        (( cap > 0 && total > cap )) && continue
        # Display width, not bytes: see _pad_into.
        (( ${#_DA_MB} > 1 )) && line="${line//[$'\x80'-$'\xbf']/}"
        m="${line%%"$tab"*}"
        (( ${#m} > w )) && w=${#m}
        m="${line#*"$tab"}"; m="${m%%"$tab"*}"
        (( ${#m} > w2 )) && w2=${#m}
    done <<< "$records"
    (( w > 48 )) && w=48
    (( w2 > 40 )) && w2=40
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        n=$(( n + 1 ))
        (( cap > 0 && n > cap )) && break
        c1="${line%%"$tab"*}"; rest="${line#*"$tab"}"
        a="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        b="${rest%%"$tab"*}";  c="${rest#*"$tab"}"
        case "$c" in freed*) wc="$CYE" ;; *) wc="$CDIM" ;; esac
        _pad_into "$a" "$w2"; pa="$_DA_R"
        _pad_into "$c1" "$w"
        printf "    ${CWH}%s${CR}  ${CDIM}%s${CR}  ${CCY}%s${CR}  ${wc}%s${CR}\n" "$_DA_R" "$pa" "$b" "$c"
    done <<< "$records"
    if (( cap > 0 && total > cap )); then
        printf "    ${CDIM}… and %s more — every one with${CR} ${CYE}dprune -n${CR}\n" $(( total - cap ))
    fi
}

# _dprune_refs <ref…> → "a b c … +N more", for the command lines
_dprune_refs_into() {
    local n=0 out="" r
    for r in "$@"; do
        n=$(( n + 1 ))
        (( n <= 3 )) && out+=" $r"
    done
    (( n > 3 )) && out+=" … +$(( n - 3 )) more"
    _DA_R="${out# }"
}

# _dprune_run <label> <command…> — runs one deletion step, reports it
# Docker prints every deleted ID on stdout — hundreds of lines nobody reads —
# so stdout is dropped and stderr kept: each refusal is one "Error response"
# line, and those are what matter.
_dprune_run() {
    local label="$1" err n_req="$2" refused=0 line
    shift 2
    err=$("$@" 2>&1 >/dev/null)
    while IFS= read -r line; do
        [[ "$line" == *"Error"* ]] && refused=$(( refused + 1 ))
    done <<< "$err"
    _pad_into "$label" 12
    if (( refused > 0 )); then
        printf "  ${CB}%s${CR} %s deleted, ${CYE}%s refused${CR}\n" "$_DA_R" $(( n_req - refused )) "$refused"
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf "      ${CDIM}%s${CR}\n" "$line"
        done <<< "$err"
    else
        printf "  ${CB}%s${CR} %s deleted\n" "$_DA_R" "$n_req"
    fi
}

# ---------------------------------------------------------------------------
# dprune
# ---------------------------------------------------------------------------

dprune() {
    local all=false with_volumes=false dry=false arg i ch
    local host raw line tab=$'\t' nl=$'\n' rest
    local id state name cstatus image nets project ref size created repo tag
    local driver scope why vname vproj
    local keep_nets="," del_nets="," keep_imgs="," del_imgs="," keep_vols="," del_vols=","
    local n_running=0 img_bytes=0 seen_imgs="," kept_tagged=0 unused_vols_kept=0
    local cache_reclaim="" vol_sizes="" rec_c="" rec_n="" rec_i="" rec_v=""
    local -a all_ids del_cids del_netids del_imgrefs del_vnames
    typeset -A vol_size

    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -h|--help) _dprune_help; return 0 ;;
            # One arm per flag as well as the clustered form, as dnet, dps and
            # di do: completion.bats checks the completions against these arms.
            -a) all=true ;;
            -v) with_volumes=true ;;
            -n) dry=true ;;
            -[a-zA-Z]*)
                for (( i = 1; i < ${#arg}; i++ )); do
                    ch="${arg:$i:1}"
                    case "$ch" in
                        a) all=true ;;
                        v) with_volumes=true ;;
                        n) dry=true ;;
                        h) _dprune_help; return 0 ;;
                        *) _err dprune "unknown flag: -$ch  (try: dprune --help)"; return 1 ;;
                    esac
                done
                ;;
            *) _err dprune "unexpected argument: $arg — dprune takes no names, only flags"; return 1 ;;
        esac
        shift
    done

    if ! host=$(docker info --format '{{.Name}}' 2>/dev/null) || [[ -z "$host" ]]; then
        _err dprune "could not reach the docker daemon"
        return 1
    fi

    # --- containers: which stay, which go ------------------------------------
    # running, paused and restarting stay — exactly what `container prune`
    # spares. Everything else (exited, created, dead) goes.
    raw=$(docker ps -a --no-trunc --format '{{.ID}}\t{{.State}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Networks}}\t{{.Label "com.docker.compose.project"}}' 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id="${line%%"$tab"*}";     rest="${line#*"$tab"}"
        state="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        name="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        cstatus="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        image="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        nets="${rest%%"$tab"*}";   project="${rest#*"$tab"}"
        all_ids+=("$id")
        case "$state" in
            running|paused|restarting)
                n_running=$(( n_running + 1 ))
                keep_nets+="${nets},"
                ;;
            *)
                del_cids+=("$id")
                del_nets+="${nets},"
                rec_c+="${name}${tab}${cstatus}${tab}${image}${tab}${project}${nl}"
                ;;
        esac
    done <<< "$raw"

    # --- what every container uses: its image and its volumes ---------------
    # One inspect for all of them. Kept containers protect what they use;
    # deleted ones mark what they FREE, which is how the preview can say why.
    if [[ ${#all_ids[@]} -gt 0 ]]; then
        local deleted_set=","
        for id in "${del_cids[@]}"; do deleted_set+="${id},"; done
        raw=$(docker inspect --format '{{.Id}}{{"\t"}}{{.Image}}{{"\t"}}{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}},{{end}}{{end}}' "${all_ids[@]}" 2>/dev/null)
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            id="${line%%"$tab"*}"; rest="${line#*"$tab"}"
            image="${rest%%"$tab"*}"; nets="${rest#*"$tab"}"
            if [[ "$deleted_set" == *",${id},"* ]]; then
                del_imgs+="${image},"; del_vols+="${nets}"
            else
                keep_imgs+="${image},"; keep_vols+="${nets}"
            fi
        done <<< "$raw"
    fi

    # --- networks ------------------------------------------------------------
    # The built-in three can never go; docker_gwbridge and ingress belong to
    # swarm and are recreated by it, so they are left alone too.
    raw=$(docker network ls --format '{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id="${line%%"$tab"*}";     rest="${line#*"$tab"}"
        name="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        driver="${rest%%"$tab"*}"; scope="${rest#*"$tab"}"
        case "$name" in bridge|host|none|docker_gwbridge|ingress) continue ;; esac
        [[ "$scope" == "local" ]] || continue
        [[ "$keep_nets" == *",${name},"* ]] && continue
        if [[ "$del_nets" == *",${name},"* ]]; then why="freed — its stopped containers go first"
        else why="unused"; fi
        del_netids+=("$id")
        rec_n+="${name}${tab}${driver}${tab}${why}${tab}${nl}"
    done <<< "$raw"

    # --- images --------------------------------------------------------------
    # Two listings, because one cannot be trusted for both kinds. With the
    # containerd image store — docker 29's default — plain `docker images`
    # HIDES dangling images: measured, 42 of them, visible only with -a or
    # the dangling filter. And -a is wrong too: on the classic store it adds
    # intermediate layers, which are not dangling and which `image prune`
    # never removes. `--filter dangling=true` is the exact set `image prune`
    # works on, on either store; the plain listing supplies the tagged ones.
    # di learned the hiding first — see the two queries in di.sh.
    #
    # By reference, not by ID, for tagged ones: an ID with two tags makes
    # `docker rmi <id>` refuse without -f. Dangling ones have no tag, so ID.
    local fmt='{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'
    raw=$(docker images --no-trunc --filter dangling=true --format "$fmt" 2>/dev/null)
    raw+="${nl}$(docker images --no-trunc --format "$fmt" 2>/dev/null)"
    local dangling_seen=","
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id="${line%%"$tab"*}";      rest="${line#*"$tab"}"
        repo="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
        tag="${rest%%"$tab"*}";     rest="${rest#*"$tab"}"
        size="${rest%%"$tab"*}";    created="${rest#*"$tab"}"
        [[ "$keep_imgs" == *",${id},"* ]] && continue          # a kept container runs it
        if [[ "$repo" == "<none>" && "$tag" == "<none>" ]]; then
            # The classic store lists dangling images in BOTH listings.
            [[ "$dangling_seen" == *",${id},"* ]] && continue
            dangling_seen+="${id},"
            ref="${id#sha256:}"; ref="${ref:0:12}"
            name="<none>"
        elif $all; then
            ref="${repo}:${tag}"; name="$ref"
        else
            kept_tagged=$(( kept_tagged + 1 ))
            continue
        fi
        if [[ "$del_imgs" == *",${id},"* ]]; then why="freed — only stopped containers used it"
        else why="unused"; fi
        # Two tags of one image are one set of bytes: count the size once.
        if [[ "$seen_imgs" != *",${id},"* ]]; then
            seen_imgs+="${id},"
            _bytes_of_into "$size"; img_bytes=$(( img_bytes + _DA_R ))
        fi
        del_imgrefs+=("$ref")
        rec_i+="${name}${tab}${size}${tab}${created}${tab}${why}${nl}"
    done <<< "$raw"

    # --- volumes -------------------------------------------------------------
    # Counted either way, so that without -v the preview can say how many it is
    # LEAVING. Sizes cost ~3.5 s (`system df -v`), so only with -v — when the
    # size of what is about to be destroyed is the thing you need to see.
    raw=$(docker volume ls --format '{{.Name}}\t{{.Label "com.docker.compose.project"}}' 2>/dev/null)
    if $with_volumes && [[ -n "$raw" ]]; then
        vol_sizes=$(docker system df -v --format '{{range .Volumes}}{{.Name}}\t{{.Size}}\n{{end}}' 2>/dev/null)
        while IFS= read -r line; do
            [[ -n "$line" ]] && vol_size[${line%%"$tab"*}]="${line#*"$tab"}"
        done <<< "$vol_sizes"
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        vname="${line%%"$tab"*}"; vproj="${line#*"$tab"}"
        [[ "$keep_vols" == *",${vname},"* ]] && continue
        if ! $with_volumes; then
            unused_vols_kept=$(( unused_vols_kept + 1 ))
            continue
        fi
        if [[ "$del_vols" == *",${vname},"* ]]; then why="freed — its stopped containers go first"
        else why="unused"; fi
        name="$vname"
        [[ ${#vname} -eq 64 && "$vname" != *[!0-9a-f]* ]] && { name="${vname:0:12}…"; vproj="anonymous"; }
        [[ -z "$vproj" ]] && vproj="—"
        del_vnames+=("$vname")
        rec_v+="${name}${tab}${vproj}${tab}${vol_size[$vname]:-?}${tab}${why}${nl}"
    done <<< "$raw"

    # --- build cache: exact only for "everything unused", so only with -a ----
    raw=$(docker builder du 2>/dev/null)
    while IFS= read -r line; do
        [[ "$line" == Reclaimable:* ]] && { cache_reclaim="${line#Reclaimable:}"; cache_reclaim="${cache_reclaim//[[:space:]]/}"; }
    done <<< "$raw"
    local do_cache=false
    if $all && [[ -n "$cache_reclaim" && "$cache_reclaim" != "0B" ]]; then do_cache=true; fi

    # --- nothing at all ------------------------------------------------------
    local n_c=${#del_cids[@]} n_n=${#del_netids[@]} n_i=${#del_imgrefs[@]} n_v=${#del_vnames[@]}
    if (( n_c + n_n + n_i + n_v == 0 )) && ! $do_cache; then
        printf "  %s ${CB}nothing to prune${CR} ${CDIM}on %s${CR}\n" "$(_icon check)" "$host" >&2
        (( kept_tagged > 0 ))      && printf "  ${CDIM}%s unused tagged image(s) kept —${CR} ${CYE}dprune -a${CR}\n" "$kept_tagged" >&2
        (( unused_vols_kept > 0 )) && printf "  ${CDIM}%s unused volume(s) kept —${CR} ${CYE}dprune -v${CR}\n" "$unused_vols_kept" >&2
        return 0
    fi

    # --- preview -------------------------------------------------------------
    local cap=$_DPRUNE_CAP
    $dry && cap=0
    local img_total preview
    _human_bytes_into "$img_bytes"; img_total="$_DA_R"
    local -a cnames nnames
    # Built once, then written to the right stream: stdout for a dry run (so
    # `dprune -n | less` works), stderr otherwise, like every other preview.
    preview=$(
        if $dry; then
            printf "  %s ${CYE}${CB}prune — dry run${CR}  ${CDIM}·${CR}  ${CWH}${CB}%s${CR}  ${CDIM}·  nothing will be deleted${CR}\n" "$(_icon docker)" "$host"
        else
            printf "  %s ${CRE}${CB}prune${CR}  ${CDIM}·${CR}  ${CWH}${CB}%s${CR}  ${CDIM}·${CR}  ${CRE}these are DELETED, and cannot be undone${CR}\n" "$(_icon docker)" "$host"
        fi

        if (( n_c > 0 )); then
            _dprune_section "STOPPED CONTAINERS" "$n_c" "their filesystems and logs go with them"
            _dprune_items "$rec_c" "$cap"
        fi
        if (( n_n > 0 )); then
            _dprune_section "NETWORKS" "$n_n"
            _dprune_items "$rec_n" "$cap"
        fi
        if (( n_v > 0 )); then
            _dprune_section "VOLUMES" "$n_v" "the data in them is destroyed"
            # Never capped, and in red: this is the one category that is data.
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                name="${line%%"$tab"*}"; rest="${line#*"$tab"}"
                vproj="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
                size="${rest%%"$tab"*}"; why="${rest#*"$tab"}"
                printf "    ${CRE}${CB}%s${CR}  ${CDIM}%s${CR}  ${CRE}%s${CR}  ${CDIM}%s${CR}\n" "$name" "$vproj" "$size" "$why"
            done <<< "$rec_v"
        fi
        if (( n_i > 0 )); then
            if $all; then _dprune_section "IMAGES" "$n_i" "up to $img_total — images share layers, docker may free less"
            else _dprune_section "DANGLING IMAGES" "$n_i" "up to $img_total — images share layers, docker may free less"; fi
            _dprune_items "$rec_i" "$cap"
        fi
        if $do_cache; then
            _dprune_section "BUILD CACHE" "$cache_reclaim" "every record no build is using"
        fi

        # What stays — said out loud, so the list above is read as complete.
        printf "\n  ${CGR}${CB}KEPT${CR}\n"
        printf "    ${CGR}%s running container(s)${CR}${CDIM}, and every network, image and volume they use${CR}\n" "$n_running"
        if ! $with_volumes; then
            if (( unused_vols_kept > 0 )); then
                printf "    ${CWH}volumes${CR}${CDIM}: not touched — %s unused would go with${CR} ${CYE}-v${CR}\n" "$unused_vols_kept"
            else
                printf "    ${CWH}volumes${CR}${CDIM}: not touched${CR}\n"
            fi
        fi
        if ! $all; then
            (( kept_tagged > 0 )) && \
                printf "    ${CWH}tagged images${CR}${CDIM}: %s unused, kept — they go with${CR} ${CYE}-a${CR}\n" "$kept_tagged"
            if [[ -n "$cache_reclaim" && "$cache_reclaim" != "0B" ]]; then
                printf "    ${CWH}build cache${CR}${CDIM}: %s, kept — it goes with${CR} ${CYE}-a${CR}\n" "$cache_reclaim"
            fi
        fi

        # The commands, in the order they run. Containers first: that order
        # is the cascade the sections above already accounted for.
        printf "\n  ${CDIM}runs, in this order — each item by name, never with -f:${CR}\n"
        if (( n_c > 0 )); then
            while IFS= read -r line; do [[ -n "$line" ]] && cnames+=("${line%%"$tab"*}"); done <<< "$rec_c"
            _dprune_refs_into "${cnames[@]}"
            printf "  %s ${CDIM}docker${CR} ${CRE}rm${CR} %s\n" "$(_icon cmd)" "$_DA_R"
        fi
        if (( n_n > 0 )); then
            while IFS= read -r line; do [[ -n "$line" ]] && nnames+=("${line%%"$tab"*}"); done <<< "$rec_n"
            _dprune_refs_into "${nnames[@]}"
            printf "  %s ${CDIM}docker network${CR} ${CRE}rm${CR} %s\n" "$(_icon cmd)" "$_DA_R"
        fi
        if (( n_v > 0 )); then
            _dprune_refs_into "${del_vnames[@]}"
            printf "  %s ${CDIM}docker volume${CR} ${CRE}rm${CR} %s\n" "$(_icon cmd)" "$_DA_R"
        fi
        if (( n_i > 0 )); then
            _dprune_refs_into "${del_imgrefs[@]}"
            printf "  %s ${CDIM}docker${CR} ${CRE}rmi${CR} %s\n" "$(_icon cmd)" "$_DA_R"
        fi
        $do_cache && printf "  %s ${CDIM}docker builder${CR} ${CRE}prune${CR} -a -f\n" "$(_icon cmd)"
        _hr
    )
    if $dry; then printf '%s\n' "$preview"; else printf '%s\n' "$preview" >&2; fi

    if $dry; then
        printf "  ${CDIM}dry run — nothing was deleted${CR}\n" >&2
        return 0
    fi

    # --- confirm: the host's name ---------------------------------------------
    local what="$n_c container(s), $n_n network(s), $n_i image(s)"
    (( n_v > 0 )) && what+=", $n_v VOLUME(S)"
    $do_cache && what+=", the build cache"
    _confirm_typed "$host" "This deletes $what on $host, permanently. Type the host name to confirm:" || {
        printf "  ${CB}${CYE}Cancelled${CR} ${CDIM}— nothing was deleted${CR}\n" >&2
        return 1
    }

    # --- run, in cascade order -----------------------------------------------
    printf "\n" >&2
    {
        (( n_c > 0 )) && _dprune_run "containers" "$n_c" docker rm "${del_cids[@]}"
        (( n_n > 0 )) && _dprune_run "networks" "$n_n" docker network rm "${del_netids[@]}"
        (( n_v > 0 )) && _dprune_run "volumes" "$n_v" docker volume rm "${del_vnames[@]}"
        (( n_i > 0 )) && _dprune_run "images" "$n_i" docker rmi "${del_imgrefs[@]}"
        if $do_cache; then
            local out
            out=$(docker builder prune -a -f 2>&1 | tail -1)
            _pad_into "build cache" 12
            printf "  ${CB}%s${CR} %s\n" "$_DA_R" "$out"
        fi
    } >&2
    return 0
}
