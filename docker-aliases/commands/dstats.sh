#!/usr/bin/env bash
# docker-aliases — dstats: resource use, measured against each container's
# own limits.
#
# `docker stats` reports percentages that do not mean what they look like:
#
#   * MEM % is divided by the HOST's memory when a container has no limit, so a
#     container with no ceiling shows "0.14%" and reads as calm. It is not
#     calm; it is unbounded.
#   * CPU % is relative to ONE core: 100% is a full core, and a container
#     limited to --cpus 0.5 tops out at 50%. Measured: a busy loop under a
#     half-core limit shows 50.71% — at its ceiling, being throttled — and
#     nothing in docker's output says so.
#
# So every number here is shown against the container's own limit, in the
# same unit: "50.7% / 50%" is a container pinned against its CPU ceiling, and
# "384KiB / ∞" one with no memory limit at all. Colour comes from the ratio.
#
# Design contract:
#   * One `docker stats --no-stream`, one `inspect` of the same containers for
#     the limits and compose labels, one `docker info` for the host. The stats
#     call costs ~2 s and that cost is FIXED — the daemon waits a second
#     collection tick to compute the CPU delta, and the CLI cannot skip it —
#     so filtering never makes it faster, only shorter.
#   * Rows near a limit come first, then by memory: memory is what gets a
#     container killed; one CPU sample is too spiky to rank by.
#   * -w redraws in place until Ctrl-C. Each round costs the same ~2 s, so the
#     refresh rate is docker's, not a number to tune.
#   * dcstats is the same table for the current compose project, by service.
#     This file holds the shared core; dcstats.sh is the thin front.
#
# Read-only: a scope line, no preview, no confirmation.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dstats_help() {
    printf "${CB}${CCY}dstats${CR} — resource use, against each container's own limits\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dstats${CR} [${CYE}-w${CR}] [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-w${CR}                 Watch: redraw until Ctrl-C ${CI}(every ~2 s — docker's pace)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    _dstats_reading_help

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dstats${CR}                 Every running container\n"
    printf "  ${CGR}dstats kafka${CR}           Only names matching 'kafka'\n"
    printf "  ${CGR}dstats -w${CR}              Keep watching\n"
}

# Shared with dcstats: how to read the numbers.
_dstats_reading_help() {
    printf "${CCY}READING IT${CR}\n"
    printf "  ${CB}CPU${CR}   100%% is ONE core. ${CYE}50.7%% / 50%%${CR} is a container at its --cpus 0.5\n"
    printf "        ceiling, being throttled. No limit: just the usage.\n"
    printf "  ${CB}MEM${CR}   used / limit. ${CYE}∞${CR} means no limit — docker's own MEM %% divides by\n"
    printf "        the host's RAM then, and makes an unbounded container look calm.\n"
    printf "  ${CB}PIDS${CR}  processes / limit, when there is one.\n"
    printf "  ${CI}Red at 90%% of a limit, yellow at 70%%; anything else is left plain.${CR}\n"
    printf "  ${CI}Rows near a limit come first.${CR}\n\n"
}

# ---------------------------------------------------------------------------
# Number helpers — integer only, no fork
# ---------------------------------------------------------------------------

# _dstats_hundredths_into "50.71%" → 5071
_dstats_hundredths_into() {
    local v="${1%\%}" int frac
    v="${v// /}"
    int="${v%%.*}"
    if [[ "$v" == *.* ]]; then frac="${v#*.}"; else frac=""; fi
    frac="${frac}00"; frac="${frac:0:2}"
    [[ "$int" =~ ^[0-9]+$ ]] || int=0
    [[ "$frac" =~ ^[0-9]+$ ]] || frac=00
    _DA_R=$(( 10#$int * 100 + 10#$frac ))
}

# _dstats_level_into <used> <limit> → 2 (≥90%), 1 (≥70%), 0, in _DA_R
_dstats_level_into() {
    local used="$1" limit="$2"
    if (( limit <= 0 )); then _DA_R=0
    elif (( used * 100 >= limit * 90 )); then _DA_R=2
    elif (( used * 100 >= limit * 70 )); then _DA_R=1
    else _DA_R=0
    fi
}

# _dstats_ibytes_into <bytes> [exact] → "912.9MiB", "1.5GiB", "114MiB"
#
# One format for every figure in a column, so the column lines up. docker
# prints memory with whatever precision it likes — "33.1MiB", "30.07MiB",
# "8.184MiB" — and that alone kept the " / " from sitting in one place. Binary
# units, as docker's memory figures are; one decimal, none from 100 up, the
# same rule as _human_bytes_into. "exact" drops the decimal whenever there is
# none to show, for limits, which are set in round numbers: "512MiB", "1GiB".
_dstats_ibytes_into() {
    local b="${1:-0}" exact="${2:-}" unit div t
    if   (( b >= 1073741824 )); then div=1073741824; unit=GiB
    elif (( b >= 1048576 ));    then div=1048576;    unit=MiB
    elif (( b >= 1024 ));       then div=1024;       unit=KiB
    else _DA_R="${b}B"; return 0
    fi
    if [[ -n "$exact" ]] && (( b % div == 0 )); then _DA_R="$(( b / div ))$unit"; return 0; fi
    t=$(( (b * 10 + div / 2) / div ))
    if (( t >= 1000 )); then _DA_R="$(( t / 10 ))$unit"
    else _DA_R="$(( t / 10 )).$(( t % 10 ))$unit"; fi
}

# _dstats_width_into <text> → its display width, not its byte count. "∞" is
# three bytes; under a C locale ${#x} counts all three (see _pad_into).
_dstats_width_into() {
    local m="$1"
    (( ${#_DA_MB} > 1 )) && m="${m//[$'\x80'-$'\xbf']/}"
    _DA_R=${#m}
}

# _dstats_rjust_into <text> <width> → the text right-aligned to that width
_dstats_rjust_into() {
    local t="$1" w="$2" n
    _dstats_width_into "$t"; n=$(( w - _DA_R ))
    while (( n > ${#_DA_SP} )); do _DA_SP="${_DA_SP}${_DA_SP}"; done
    # $n, not a bare n: zsh reads ${x:0:n} as the history modifier :n and aborts.
    if (( n > 0 )); then _DA_R="${_DA_SP:0:$n}${t}"; else _DA_R="$t"; fi
}

# ---------------------------------------------------------------------------
# Cell colours — each parses its own cell, so the table stays generic
#
# Colour means "look here", so a figure with nothing to say gets none. Every
# colour this library has is bold, and the first version painted ordinary
# values bold white: on a screen where every MEM cell was highlighted, the one
# near its limit did not stand out.
# ---------------------------------------------------------------------------

_level_color_into() {
    case "$1" in 2) _DA_R="$CRE" ;; 1) _DA_R="$CYE" ;; *) _DA_R="" ;; esac
}

# "50.7% / 50%"  or  "0.32%"
_stcpu_color_into() {
    local cell="$1" u l
    if [[ "$cell" == *" / "* ]]; then
        _dstats_hundredths_into "${cell%% / *}"; u="$_DA_R"
        _dstats_hundredths_into "${cell##* / }"; l="$_DA_R"
        _dstats_level_into "$u" "$l"; _level_color_into "$_DA_R"
    else
        # No limit: worth a look only past a whole core.
        _dstats_hundredths_into "$cell"
        if (( _DA_R >= 10000 )); then _DA_R="$CYE"; else _DA_R=""; fi
    fi
}

# "170.4MiB / 256MiB"  or  "384KiB / ∞"
_stmem_color_into() {
    local cell="$1" u l
    case "$cell" in
        *"∞"*) _DA_R="$CYE"; return 0 ;;
    esac
    _bytes_of_into "${cell%% / *}"; u="$_DA_R"
    _bytes_of_into "${cell##* / }"; l="$_DA_R"
    _dstats_level_into "$u" "$l"; _level_color_into "$_DA_R"
}

# "18 / 50"  or  "18"
_stpids_color_into() {
    local cell="$1"
    if [[ "$cell" == *" / "* ]]; then
        _dstats_level_into "${cell%% / *}" "${cell##* / }"; _level_color_into "$_DA_R"
    else
        _DA_R=""
    fi
}

# ---------------------------------------------------------------------------
# The core: collect, join, render — shared by dstats and dcstats
# ---------------------------------------------------------------------------

# _dstats_align_into <sorted rows> <header>×5 → the table's rows, every figure
# aligned; the five headers come back aligned too, in _DSTATS_H1.._DSTATS_H5
#
# Rows arrive as "flag<TAB>bytes<TAB>cpu<US>lim<TAB>mem<US>lim<TAB>pids<US>lim
# <TAB>rx<US>tx<TAB>read<US>write<TAB>name". The rows it returns put the name
# FIRST, then the five aligned cells. Two passes: the first measures the
# widest half of every pair across all rows, the second right-aligns each half
# to it, so every " / " in a column sits in the same place and the digits line
# up under each other. A pair with no limit (CPU, PIDS) shows the used half
# alone, aligned with the others.
#
# Each header ends where the figures under it end. Its width counts in the
# first half of the pair: a left-aligned "PIDS" over right-aligned "55" and "6"
# put the numbers under "PI", and figures narrower than their header floated
# off to the left of the column.
_dstats_align_into() {
    local sorted="$1" line rest tab=$'\t' nl=$'\n' us=$'\x1f' out="" f a b
    local h1="$2" h2="$3" h3="$4" h4="$5" h5="$6"
    local wa wb i cells name
    # Pass 1: widths. Ten plain variables rather than an array: this file runs
    # in bash and zsh, whose arrays start at 0 and 1.
    local w1a=0 w1b=0 w2a=0 w2b=0 w3a=0 w3b=0 w4a=0 w4b=0 w5a=0 w5b=0
    _dstats_width_into "$h1"; w1a=$_DA_R
    _dstats_width_into "$h2"; w2a=$_DA_R
    _dstats_width_into "$h3"; w3a=$_DA_R
    _dstats_width_into "$h4"; w4a=$_DA_R
    _dstats_width_into "$h5"; w5a=$_DA_R
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        rest="${line#*"$tab"}"; rest="${rest#*"$tab"}"
        i=0
        while (( i < 5 )); do
            i=$(( i + 1 ))
            f="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
            a="${f%%"$us"*}"; b="${f#*"$us"}"
            _dstats_width_into "$a"; wa=$_DA_R
            _dstats_width_into "$b"; wb=$_DA_R
            case $i in
                1) (( wa > w1a )) && w1a=$wa; (( wb > w1b )) && w1b=$wb ;;
                2) (( wa > w2a )) && w2a=$wa; (( wb > w2b )) && w2b=$wb ;;
                3) (( wa > w3a )) && w3a=$wa; (( wb > w3b )) && w3b=$wb ;;
                4) (( wa > w4a )) && w4a=$wa; (( wb > w4b )) && w4b=$wb ;;
                5) (( wa > w5a )) && w5a=$wa; (( wb > w5b )) && w5b=$wb ;;
            esac
        done
    done <<< "$sorted"

    _dstats_rjust_into "$h1" "$w1a"; _DSTATS_H1="$_DA_R"
    _dstats_rjust_into "$h2" "$w2a"; _DSTATS_H2="$_DA_R"
    _dstats_rjust_into "$h3" "$w3a"; _DSTATS_H3="$_DA_R"
    _dstats_rjust_into "$h4" "$w4a"; _DSTATS_H4="$_DA_R"
    _dstats_rjust_into "$h5" "$w5a"; _DSTATS_H5="$_DA_R"

    # Pass 2: build the cells.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        rest="${line#*"$tab"}"; rest="${rest#*"$tab"}"
        cells=""
        i=0
        while (( i < 5 )); do
            i=$(( i + 1 ))
            f="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
            a="${f%%"$us"*}"; b="${f#*"$us"}"
            case $i in
                1) wa=$w1a; wb=$w1b ;; 2) wa=$w2a; wb=$w2b ;; 3) wa=$w3a; wb=$w3b ;;
                4) wa=$w4a; wb=$w4b ;; 5) wa=$w5a; wb=$w5b ;;
            esac
            _dstats_rjust_into "$a" "$wa"; a="$_DA_R"
            if [[ -n "$b" ]]; then
                _dstats_rjust_into "$b" "$wb"; a="$a / $_DA_R"
            fi
            cells+="${a}${tab}"
        done
        name="$rest"
        # The name leads. The renderer left-aligns and pads the first column,
        # and prints the last one as it comes — which is already aligned here.
        out+="${name}${tab}${cells%"$tab"}${nl}"
    done <<< "$sorted"
    _DA_R="${out%"$nl"}"
}

# _dstats_table <title> <mode> <pattern> [project]
#   mode "host":    every running container, named by container
#   mode "project": only containers of <project>, named by service
_dstats_table() {
    local title="$1" mode="$2" pattern="$3" project="${4:-}"
    local tab=$'\t' nl=$'\n' line rest raw lim info
    local name cpu memu net blk pids memused memlim
    local mem nanocpu quota period pidslim proj svc num
    local cpul meml pidsl label risk mb u l shown=0 total=0 unlimited=0
    local us=$'\x1f' memu_f rx tx br bw
    local sum_mem=0 sum_cpu=0 ncpu="" memtotal="" rowsort="" rows="" sorted
    local -a names
    typeset -A l_mem l_cpu l_quota l_period l_pids l_proj l_svc l_num

    if ! raw=$(docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}' 2>/dev/null); then
        if [[ "$mode" == "project" ]]; then _err dcstats "could not reach the docker daemon"
        else _err dstats "could not reach the docker daemon"; fi
        return 1
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && names+=("${line%%"$tab"*}")
    done <<< "$raw"
    if [[ ${#names[@]} -eq 0 ]]; then
        printf "  ${CDIM}no containers are running${CR}\n" >&2
        return 0
    fi

    # Limits and labels, one call. Typed access throughout — no `index` on a
    # struct, which would drop docker into map mode (see dhealth). Labels IS a
    # map, so `index` is right there. An unset PidsLimit is a nil pointer and
    # prints "<no value>"; so does a missing label on a nil map.
    lim=$(docker inspect --format '{{.Name}}{{"\t"}}{{.HostConfig.Memory}}{{"\t"}}{{.HostConfig.NanoCpus}}{{"\t"}}{{.HostConfig.CpuQuota}}{{"\t"}}{{.HostConfig.CpuPeriod}}{{"\t"}}{{.HostConfig.PidsLimit}}{{"\t"}}{{index .Config.Labels "com.docker.compose.project"}}{{"\t"}}{{index .Config.Labels "com.docker.compose.service"}}{{"\t"}}{{index .Config.Labels "com.docker.compose.container-number"}}' \
        "${names[@]}" 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}"; name="${name#/}"; rest="${line#*"$tab"}"
        l_mem[$name]="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
        l_cpu[$name]="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
        l_quota[$name]="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        l_period[$name]="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        l_pids[$name]="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        l_proj[$name]="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        l_svc[$name]="${rest%%"$tab"*}";    l_num[$name]="${rest#*"$tab"}"
    done <<< "$lim"

    info=$(docker info --format '{{.NCPU}}{{"\t"}}{{.MemTotal}}' 2>/dev/null) || info=""
    ncpu="${info%%"$tab"*}"; memtotal="${info#*"$tab"}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}"; rest="${line#*"$tab"}"
        cpu="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        memu="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        net="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        blk="${rest%%"$tab"*}";  pids="${rest#*"$tab"}"

        proj="${l_proj[$name]:-}"; [[ "$proj" == "<no value>" ]] && proj=""
        svc="${l_svc[$name]:-}";   [[ "$svc" == "<no value>" ]] && svc=""
        num="${l_num[$name]:-}";   [[ "$num" == "<no value>" ]] && num=""

        if [[ "$mode" == "project" ]]; then
            [[ "$proj" == "$project" ]] || continue
            label="${svc:-$name}"
            # A replica past the first gets its number: two "worker" rows
            # that cannot be told apart are worse than one.
            [[ -n "$num" && "$num" != "1" ]] && label="$label #$num"
            total=$(( total + 1 ))
            [[ -z "$pattern" || "$svc" =~ $pattern ]] || continue
        else
            label="$name"
            total=$(( total + 1 ))
            [[ -z "$pattern" || "$name" =~ $pattern ]] || continue
        fi

        risk=0
        # --- CPU: the ceiling, in docker's own unit (100% = one core) -------
        nanocpu="${l_cpu[$name]:-0}"; quota="${l_quota[$name]:-0}"; period="${l_period[$name]:-0}"
        [[ "$nanocpu" =~ ^[0-9]+$ ]] || nanocpu=0
        [[ "$quota" =~ ^[0-9]+$ ]] || quota=0
        [[ "$period" =~ ^[0-9]+$ ]] || period=0
        (( period == 0 )) && period=100000
        _dstats_hundredths_into "$cpu"; u="$_DA_R"
        sum_cpu=$(( sum_cpu + u ))
        l=0
        if (( nanocpu > 0 )); then l=$(( nanocpu / 100000 ))       # hundredths of a percent
        elif (( quota > 0 )); then l=$(( quota * 10000 / period ))
        fi
        cpul=""
        if (( l > 0 )); then
            cpul="$(( l / 100 ))%"
            _dstats_level_into "$u" "$l"; (( _DA_R > risk )) && risk=$_DA_R
        fi

        # --- memory: re-formatted, not docker's strings; ∞ with no limit -----
        memused="${memu%% / *}"
        _bytes_of_into "$memused"; mb="$_DA_R"
        sum_mem=$(( sum_mem + mb ))
        _dstats_ibytes_into "$mb"; memu_f="$_DA_R"
        mem="${l_mem[$name]:-0}"; [[ "$mem" =~ ^[0-9]+$ ]] || mem=0
        if (( mem > 0 )); then
            _dstats_ibytes_into "$mem" exact; meml="$_DA_R"
            _dstats_level_into "$mb" "$mem"; (( _DA_R > risk )) && risk=$_DA_R
        else
            meml="∞"
            unlimited=$(( unlimited + 1 ))
        fi

        # --- pids ------------------------------------------------------------
        pidslim="${l_pids[$name]:-}"
        pidsl=""
        if [[ "$pidslim" =~ ^[0-9]+$ ]] && (( pidslim > 0 )); then
            pidsl="$pidslim"
            _dstats_level_into "$pids" "$pidslim"; (( _DA_R > risk )) && risk=$_DA_R
        fi

        # --- network and disk: totals, re-formatted the same way -------------
        _bytes_of_into "${net%% / *}"; _human_bytes_into "$_DA_R"; rx="$_DA_R"
        _bytes_of_into "${net##* / }"; _human_bytes_into "$_DA_R"; tx="$_DA_R"
        _bytes_of_into "${blk%% / *}"; _human_bytes_into "$_DA_R"; br="$_DA_R"
        _bytes_of_into "${blk##* / }"; _human_bytes_into "$_DA_R"; bw="$_DA_R"

        shown=$(( shown + 1 ))
        # Sort key: near a limit (red) first, then memory used, descending.
        # Each figure travels as its two halves — used and limit, in and out —
        # joined by \x1f, because the widths that line them up can only be
        # known once every row is in.
        rowsort+="$(( risk == 2 ? 1 : 0 ))${tab}${mb}${tab}${cpu}${us}${cpul}${tab}${memu_f}${us}${meml}${tab}${pids}${us}${pidsl}${tab}${rx}${us}${tx}${tab}${br}${us}${bw}${tab}${label}${nl}"
    done <<< "$raw"

    if [[ -n "$rowsort" ]]; then
        sorted=$(printf '%s' "$rowsort" | LC_ALL=C sort -t "$tab" -k1,1nr -k2,2nr)
        _dstats_align_into "$sorted" "CPU" "MEM" "PIDS" "NET I/O" "DISK I/O"; rows="$_DA_R"
    fi

    local namehdr="NAME"
    local memsum hostmem
    [[ "$mode" == "project" ]] && namehdr="SERVICE"
    _render_container_table "$title" "$shown" "$total" "$pattern" \
        "$namehdr" "${_DSTATS_H1:-CPU}" "${_DSTATS_H2:-MEM}" "${_DSTATS_H3:-PIDS}" \
        "${_DSTATS_H4:-NET I/O}" "${_DSTATS_H5:-DISK I/O}" "$rows" \
        "white,@stcpu,@stmem,@stpids,dim,dim"

    # --- the footer: the host, and what has no ceiling ----------------------
    # Binary units, like the MEM column above it: the first version said "GB"
    # under a column of "MiB".
    _dstats_ibytes_into "$sum_mem"; memsum="$_DA_R"
    {
        printf "  ${CDIM}%s shown use${CR} %s ${CDIM}of memory" "$shown" "$memsum"
        if [[ "$memtotal" =~ ^[0-9]+$ ]]; then
            _dstats_ibytes_into "$memtotal"; hostmem="$_DA_R"
            printf " (host: %s)" "$hostmem"
        fi
        printf " · CPU %d.%02d%%" $(( sum_cpu / 100 )) $(( sum_cpu % 100 ))
        [[ "$ncpu" =~ ^[0-9]+$ ]] && printf " of %s00%% (%s cores)" "$ncpu" "$ncpu"
        printf "${CR}\n"
        if (( unlimited > 0 )); then
            printf "  %s ${CYE}%s with no memory limit${CR}${CDIM} — nothing stops one of them from taking the host's RAM${CR}\n" \
                "$(_icon warn)" "$unlimited"
        fi
    } >&2
    return 0
}

# _dstats_watch <command…> — redraw until Ctrl-C
#
# The screen is cleared and redrawn, as `watch` does, rather than moving the
# cursor up N lines: a row that wraps in a narrow terminal would make that
# count wrong and leave debris. DOCKER_ALIASES_WATCH_ROUNDS stops it after N
# rounds — for tests only, like DOCKER_ALIASES_AUTO_YES.
_dstats_watch() {
    local out rounds=0 max="${DOCKER_ALIASES_WATCH_ROUNDS:-0}"
    while :; do
        out=$("$@" 2>&1)
        printf '\033[H\033[J%s\n' "$out"
        printf "  ${CDIM}watching · every ~2 s, docker's pace · Ctrl-C to stop${CR}\n"
        rounds=$(( rounds + 1 ))
        (( max > 0 && rounds >= max )) && break
    done
    return 0
}

# ---------------------------------------------------------------------------
# dstats
# ---------------------------------------------------------------------------

dstats() {
    local watch=false pattern=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dstats_help; return 0 ;;
            -w) watch=true ;;
            -*) _err dstats "unknown flag: $1"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dstats "one pattern at a time"; return 1; }
                pattern="$1"
                ;;
        esac
        shift
    done

    if $watch; then
        _dstats_watch _dstats_table "docker stats" host "$pattern"
    else
        _dstats_table "docker stats" host "$pattern"
    fi
}

# Completion source: running containers.
_dstats_candidates() {
    docker ps --format '{{.Names}}' 2>/dev/null | LC_ALL=C sort
}
