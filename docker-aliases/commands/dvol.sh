#!/usr/bin/env bash
# docker-aliases — dvol: volumes, who holds them, and what a cleanup would free.
#
# `docker volume ls` gives a driver and a name, and a third of the names on a
# working host are 64 hex characters that say nothing. What you want is: which
# project does this belong to, is anything still using it, and how big is it.
#
# Design contract:
#   * Same rule as dnet, for the same reason: a volume a STOPPED container
#     mounts survives `docker volume prune`. USE says which of the three it is:
#       N running   mounted by a running container
#       stopped     only stopped containers mount it — a prune keeps it
#       unused      nothing mounts it: exactly what a prune removes
#     Measured on a real host, "unused" here equals docker's own
#     `volume ls -f dangling=true`, volume for volume.
#   * Sizes cost ~3.5 s (`docker system df -v`), so they are behind -s, as in di.
#     Without -s nothing waits on that call.
#   * Anonymous volumes are shown as the first 12 characters and an ellipsis:
#     the cut is visible, and the full name never helped anyone read the table.
#   * Read-only: a scope line, no preview, no confirmation.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dvol_help() {
    printf "${CB}${CCY}dvol${CR} — volumes, who holds them, and what cleaning would free\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dvol${CR} [${CYE}-u${CR}] [${CYE}-s${CR}] [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-u${CR}                 Only the unused ones — what a prune would remove\n"
    printf "  ${CYE}-s${CR}                 Add sizes, and the total a cleanup frees ${CI}(costs ~3.5s)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}THE USE COLUMN${CR}\n"
    printf "  ${CGR}N running${CR}     mounted by a running container\n"
    printf "  ${CDIM}stopped${CR}       only ${CB}stopped${CR} containers mount it — a prune keeps it\n"
    printf "  ${CYE}unused${CR}        nothing mounts it — the only kind a prune removes\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dvol${CR}                  Every volume\n"
    printf "  ${CGR}dvol -us${CR}              What a cleanup removes, and how much it frees\n"
    printf "  ${CGR}dvol postgres${CR}         By name or compose project\n"
    printf "  ${CGR}dvol -s keycloak${CR}      How big that project's data is\n"
}

# ---------------------------------------------------------------------------
# Colour for the USE cell — reached by the table as @voluse
# ---------------------------------------------------------------------------

_voluse_color_into() {
    case "$1" in
        *running) _DA_R="$CGR" ;;
        unused)   _DA_R="$CYE" ;;
        *)        _DA_R="$CDIM" ;;
    esac
}

# ---------------------------------------------------------------------------
# dvol
# ---------------------------------------------------------------------------

dvol() {
    # Every local declared ONCE, here. In zsh, `local x` on a name already
    # local in the same function PRINTS it — the first draft declared tab and
    # rest in two places and would have spilled them onto the screen, in zsh
    # only, on every run.
    local only_unused=false sizes=false pattern="" arg i ch
    local listing v raw_vol all_names c raw_ct rest cname cstate mv line
    local raw_df sv ss name driver project created use holder shown_name keep col5 day
    local tab=$'\t' nl=$'\n' rows="" total=0 shown=0
    local c_run=0 c_stop=0 c_unused=0 unused_bytes=0 _DA_R
    local -a vols cnames
    typeset -A run_by stop_by run_n size_of
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -h|--help) _dvol_help; return 0 ;;
            # One arm per flag as well as the clustered form, as dnet, dps and
            # di do: completion.bats checks the completions against these arms.
            -u) only_unused=true ;;
            -s) sizes=true ;;
            -[a-zA-Z]*)
                for (( i = 1; i < ${#arg}; i++ )); do
                    ch="${arg:$i:1}"
                    case "$ch" in
                        u) only_unused=true ;;
                        s) sizes=true ;;
                        h) _dvol_help; return 0 ;;
                        *) _err dvol "unknown flag: -$ch"; return 1 ;;
                    esac
                done
                ;;
            -*) _err dvol "unknown flag: $arg"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dvol "one pattern at a time"; return 1; }
                pattern="$arg"
                ;;
        esac
        shift
    done

    # --- the volumes --------------------------------------------------------
    # Two families of --format, and they disagree about escapes. volume ls,
    # ps and system df go through the CLI formatter, which turns \t into a tab
    # before the template is parsed — so {{"\t"}} there arrives broken. inspect
    # runs the raw Go template and leaves \t alone, so it needs {{"\t"}}.
    # Measured both ways; each call below uses the form its family accepts.
    if ! listing=$(docker volume ls --format '{{.Name}}' 2>/dev/null); then
        _err dvol "could not reach the docker daemon"
        return 1
    fi
    if [[ -z "$listing" ]]; then
        printf "  ${CDIM}no volumes on this host${CR}\n" >&2
        return 0
    fi

    while IFS= read -r v; do
        [[ -n "$v" ]] && vols+=("$v")
    done <<< "$listing"

    raw_vol=$(docker volume inspect --format '{{.Name}}{{"\t"}}{{.Driver}}{{"\t"}}{{index .Labels "com.docker.compose.project"}}{{"\t"}}{{.CreatedAt}}' \
        "${vols[@]}" 2>/dev/null) || {
        _err dvol "could not inspect the volumes"
        return 1
    }

    # --- who mounts what --------------------------------------------------
    # From inspect, not from `ps --format {{.Mounts}}`: ps truncates the names
    # to fourteen characters with an ellipsis ("nginx-api-ws_n…"), so nothing
    # would ever match and every volume would come out "unused".
    #
    # A lookup table, so each volume is one access instead of a scan. Lookups
    # only: iterating an associative array's keys has no portable form
    # (${!m[@]} in bash, ${(k)m} in zsh), and nothing here needs to.
    all_names=$(docker ps -a --format '{{.Names}}' 2>/dev/null)
    if [[ -n "$all_names" ]]; then
        while IFS= read -r c; do
            [[ -n "$c" ]] && cnames+=("$c")
        done <<< "$all_names"

        raw_ct=$(docker inspect --format '{{.Name}}{{"\t"}}{{.State.Status}}{{range .Mounts}}{{if eq .Type "volume"}}{{"\t"}}{{.Name}}{{end}}{{end}}' \
            "${cnames[@]}" 2>/dev/null)
        while IFS= read -r line; do
            [[ "$line" != *"$tab"*"$tab"* ]] && continue   # mounts no volume
            cname="${line%%"$tab"*}"; cname="${cname#/}"; rest="${line#*"$tab"}"
            cstate="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
            while [[ -n "$rest" ]]; do
                if [[ "$rest" == *"$tab"* ]]; then
                    mv="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
                else
                    mv="$rest"; rest=""
                fi
                [[ -z "$mv" ]] && continue
                if [[ "$cstate" == "running" ]]; then
                    run_n[$mv]=$(( ${run_n[$mv]:-0} + 1 ))
                    [[ -z "${run_by[$mv]:-}" ]] && run_by[$mv]="$cname"
                else
                    [[ -z "${stop_by[$mv]:-}" ]] && stop_by[$mv]="$cname"
                fi
            done
        done <<< "$raw_ct"
    fi

    # --- sizes, only when asked ---------------------------------------------
    if $sizes; then
        raw_df=$(docker system df -v --format '{{range .Volumes}}{{.Name}}\t{{.Size}}\n{{end}}' 2>/dev/null)
        while IFS=$'\t' read -r sv ss; do
            [[ -n "$sv" ]] && size_of[$sv]="$ss"
        done <<< "$raw_df"
    fi

    # --- rows ---------------------------------------------------------------
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}";    rest="${line#*"$tab"}"
        driver="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        project="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        created="$rest"

        if [[ -n "${run_n[$name]:-}" ]]; then
            use="${run_n[$name]} running"; holder="${run_by[$name]}"; c_run=$(( c_run + 1 ))
        elif [[ -n "${stop_by[$name]:-}" ]]; then
            use="stopped"; holder="${stop_by[$name]}"; c_stop=$(( c_stop + 1 ))
        else
            use="unused"; holder="—"; c_unused=$(( c_unused + 1 ))
            if $sizes; then
                _bytes_of_into "${size_of[$name]:-0B}"
                unused_bytes=$(( unused_bytes + _DA_R ))
            fi
        fi

        # An anonymous volume is named by 64 hex characters. Cut visibly, and
        # say what it is in the PROJECT column, which would otherwise be a dash.
        shown_name="$name"
        if (( ${#name} == 64 )) && [[ "$name" != *[!0-9a-f]* ]]; then
            shown_name="${name:0:12}…"
            [[ -z "$project" ]] && project="anonymous"
        fi
        [[ -z "$project" ]] && project="—"

        # 2026-10-08T21:43:24-04:00 → 2026-10-08. The day is what tells a
        # leftover apart; the time of day never has.
        day="${created%%T*}"
        [[ -z "$day" ]] && day="—"

        # Column 5 is SIZE with -s and DRIVER without. The first draft put the
        # holder here too, so USED BY showed up twice in every row.
        if $sizes; then col5="${size_of[$name]:-—}"; else col5="${driver:-—}"; fi

        total=$(( total + 1 ))
        keep=1
        if $only_unused && [[ "$use" != "unused" ]]; then keep=0; fi
        if (( keep )) && [[ -n "$pattern" ]]; then
            [[ "$name" =~ $pattern || "$project" =~ $pattern || "$holder" =~ $pattern ]] || keep=0
        fi
        (( keep )) || continue

        shown=$(( shown + 1 ))
        rows+="${day}${tab}${use}${tab}${project}${tab}${holder}${tab}${col5}${tab}${shown_name}${nl}"
    done <<< "$raw_vol"

    local filter="$pattern" h5="DRIVER"
    $only_unused && filter="${filter:+$filter, }unused only"
    $sizes && h5="SIZE"

    _render_container_table "docker volumes" "$shown" "$total" "$filter" \
        "CREATED" "USE" "PROJECT" "USED BY" "$h5" "NAME" "${rows%"$nl"}" \
        "dim,@voluse,dim,white,cyan,white"

    # The whole host, always — a filter must not shrink the leftovers.
    printf "  ${CDIM}%s running · %s held by stopped containers · ${CR}" "$c_run" "$c_stop" >&2
    if (( c_unused > 0 )); then
        printf "${CYE}%s unused${CR}" "$c_unused" >&2
        if $sizes; then
            _human_bytes_into "$unused_bytes"
            printf "${CDIM}, ${CR}${CYE}%s${CR}${CDIM} reclaimable${CR}" "$_DA_R" >&2
        else
            printf "${CDIM} — add -s for how much they free${CR}" >&2
        fi
        printf "${CDIM} · dprune -v removes them${CR}\n" >&2
    else
        printf "${CDIM}0 unused${CR}\n" >&2
    fi

    if [[ -n "$pattern" || "$only_unused" == true ]] && (( shown == 0 )); then
        return 1
    fi
    return 0
}

# Completion source: volume names, and the compose projects they belong to.
_dvol_candidates() {
    docker volume ls --format '{{.Name}}' 2>/dev/null
}
