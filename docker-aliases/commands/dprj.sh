#!/usr/bin/env bash
# docker-aliases — dprj: which compose projects live on this host.
#
# `docker compose ls` answers this, but as a wall of absolute paths with no
# colour, and its machine-readable form is JSON — which these scripts cannot
# parse, because jq is not on the servers they run on.
#
# Design contract:
#   * Built from the compose LABELS on every container, in one `ps -a`. That is
#     the same data `docker compose ls` derives its answer from, and it is
#     plain tab-separated text. Measured against `compose ls -a` on a real
#     host: the same projects and the same running/total counts.
#   * Running projects by default, as `docker compose ls` does; -a adds the
#     ones with nothing running.
#   * The directory goes LAST. It is the long column, and a last column needs no
#     padding — so it stays whole instead of shoving every row out of line.
#   * The name is what dcd takes: dprj finds a project, dcd takes you there.
#   * Read-only: a scope line, no preview, no confirmation.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dprj_help() {
    printf "${CB}${CCY}dprj${CR} — compose projects on this host\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dprj${CR} [${CYE}-a${CR}] [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Include projects with nothing running\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}THE STATE COLUMN${CR}\n"
    printf "  ${CGR}running${CR}       every container is up\n"
    printf "  ${CYE}partial${CR}       some are up, some are not — usually worth a look\n"
    printf "  ${CDIM}stopped${CR}       nothing is up ${CI}(only shown with -a)${CR}\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dprj${CR}                  What is running\n"
    printf "  ${CGR}dprj -a${CR}               Everything, stopped projects included\n"
    printf "  ${CGR}dprj nginx${CR}            By project name or directory\n"
    printf "  ${CGR}dprj -a && dcd nginx${CR}  Find it, then go there\n"
}

# ---------------------------------------------------------------------------
# Colour for the STATE cell — reached by the table as @prjstate
# ---------------------------------------------------------------------------

_prjstate_color_into() {
    case "$1" in
        running) _DA_R="$CGR" ;;
        partial) _DA_R="$CYE" ;;
        *)       _DA_R="$CDIM" ;;
    esac
}

# ---------------------------------------------------------------------------
# dprj
# ---------------------------------------------------------------------------

dprj() {
    local show_all=false pattern="" arg i ch
    local raw line tab=$'\t' nl=$'\n' rest
    local proj svc state dir files p rows="" total=0 shown=0
    local up all nsvc st first nfiles shortdir keep
    local tmp_projects=0 containers_up=0
    local -a order
    typeset -A n_up n_all svcs dir_of files_of

    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -h|--help) _dprj_help; return 0 ;;
            # One arm per flag as well as the clustered form, as dnet, dps and
            # di do: completion.bats checks the completions against these arms.
            -a) show_all=true ;;
            -[a-zA-Z]*)
                for (( i = 1; i < ${#arg}; i++ )); do
                    ch="${arg:$i:1}"
                    case "$ch" in
                        a) show_all=true ;;
                        h) _dprj_help; return 0 ;;
                        *) _err dprj "unknown flag: -$ch"; return 1 ;;
                    esac
                done
                ;;
            -*) _err dprj "unknown flag: $arg"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dprj "one pattern at a time"; return 1; }
                pattern="$arg"
                ;;
        esac
        shift
    done

    # --- one call: every container's compose labels -------------------------
    # The CLI formatter family, so a plain \t (see dvol for why it matters).
    if ! raw=$(docker ps -a --format '{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}\t{{.State}}\t{{.Label "com.docker.compose.project.working_dir"}}\t{{.Label "com.docker.compose.project.config_files"}}' 2>/dev/null); then
        _err dprj "could not reach the docker daemon"
        return 1
    fi

    # --- fold containers into projects --------------------------------------
    # `order` remembers first-seen order, so the table never has to iterate an
    # associative array's keys — which has no portable spelling.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        proj="${line%%"$tab"*}"; rest="${line#*"$tab"}"
        [[ -z "$proj" ]] && continue          # not created by compose
        svc="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        state="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        dir="${rest%%"$tab"*}";   files="${rest#*"$tab"}"

        if [[ -z "${n_all[$proj]:-}" ]]; then
            order+=("$proj")
            n_all[$proj]=0; n_up[$proj]=0; svcs[$proj]=","
            dir_of[$proj]="$dir"; files_of[$proj]="$files"
        fi
        n_all[$proj]=$(( ${n_all[$proj]} + 1 ))
        if [[ "$state" == "running" ]]; then
            n_up[$proj]=$(( ${n_up[$proj]} + 1 ))
            containers_up=$(( containers_up + 1 ))
        fi
        # Distinct services, as a comma-wrapped set: ",api,db," — a membership
        # test is one pattern match, no loop and no fork.
        [[ "${svcs[$proj]}" != *",$svc,"* ]] && svcs[$proj]="${svcs[$proj]}${svc},"
    done <<< "$raw"

    if [[ ${#order[@]} -eq 0 ]]; then
        printf "  ${CDIM}no compose projects on this host${CR}\n" >&2
        return 0
    fi

    # --- rows ---------------------------------------------------------------
    for p in "${order[@]}"; do
        up="${n_up[$p]}"; all="${n_all[$p]}"
        if   (( up == all )); then st="running"
        elif (( up == 0 ));   then st="stopped"
        else                       st="partial"
        fi

        nsvc="${svcs[$p]//[!,]/}"; nsvc=$(( ${#nsvc} - 1 ))

        # The first compose file's name, and how many came with it. "+1" is the
        # usual docker-compose.override.yml, and seeing it explains why a
        # project behaves differently from what its main file says.
        files="${files_of[$p]}"
        first="${files%%,*}"; first="${first##*/}"
        nfiles="${files//[!,]/}"; nfiles=${#nfiles}
        (( nfiles > 0 )) && first="$first +$nfiles"
        [[ -z "$first" ]] && first="—"

        dir="${dir_of[$p]}"
        # Portable on purpose: ${dir/#$HOME/\~} keeps the backslash in zsh
        # ("\~/Projects"). Cutting the prefix and quoting the tilde does not.
        if   [[ "$dir" == "$HOME" ]];   then shortdir="~"
        elif [[ "$dir" == "$HOME"/* ]]; then shortdir="~${dir#"$HOME"}"
        else                                 shortdir="${dir:-—}"
        fi
        # /tmp is tmpfs: a project living there is gone after a reboot, and
        # one with a restart policy can leave dockerd recreating its bind
        # mounts as root on boot. Counted for the footer, whatever the filter.
        [[ "$dir" == /tmp/* ]] && tmp_projects=$(( tmp_projects + 1 ))

        total=$(( total + 1 ))
        keep=1
        if ! $show_all && [[ "$st" == "stopped" ]]; then keep=0; fi
        if (( keep )) && [[ -n "$pattern" ]]; then
            [[ "$p" =~ $pattern || "$dir" =~ $pattern ]] || keep=0
        fi
        (( keep )) || continue

        shown=$(( shown + 1 ))
        rows+="${p}${tab}${up}/${all}${tab}${st}${tab}${nsvc}${tab}${first}${tab}${shortdir}${nl}"
    done

    local filter="$pattern"
    $show_all || filter="${filter:+$filter, }running only"

    _render_container_table "compose projects" "$shown" "$total" "$filter" \
        "NAME" "UP" "STATE" "SERVICES" "FILES" "DIRECTORY" "${rows%"$nl"}" \
        "white,dim,@prjstate,dim,dim,cyan"

    printf "  ${CDIM}%s projects · %s containers up${CR}" "${#order[@]}" "$containers_up" >&2
    if ! $show_all; then
        local hidden=$(( total - shown ))
        [[ -z "$pattern" ]] && (( hidden > 0 )) && \
            printf "${CDIM} · %s stopped, see${CR} ${CYE}dprj -a${CR}" "$hidden" >&2
    fi
    printf "\n" >&2
    if (( tmp_projects > 0 )); then
        printf "  %s ${CYE}%s run from /tmp${CR}${CDIM} — tmpfs, gone after a reboot${CR}\n" \
            "$(_icon warn)" "$tmp_projects" >&2
    fi
    (( shown > 0 )) && printf "  ${CDIM}go to one with${CR} ${CYE}dcd <name>${CR}\n" >&2

    if [[ -n "$pattern" ]] && (( shown == 0 )); then
        return 1
    fi
    return 0
}

# Completion source: project names, running or not.
_dprj_candidates() {
    docker ps -a --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null \
        | LC_ALL=C sort -u | while IFS= read -r p; do [[ -n "$p" ]] && printf '%s\n' "$p"; done
}
