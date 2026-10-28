#!/usr/bin/env bash
# docker-aliases — dhealth: why is that container unhealthy.
#
# The LISTING is already covered: dps decodes "(healthy)" into a glyph and a
# colour. What is not covered is the diagnosis. docker keeps the last five
# probes — when each ran, what it exited with, what it printed — and reading
# that by hand means a docker inspect and nested JSON, with no jq on the server
# to tame it. Formatting it in plain shell is the whole value of this command.
#
# Design contract:
#   * Two modes, chosen by the match. No pattern, or one matching several
#     containers: a table of every container that HAS a healthcheck. A pattern
#     matching exactly one: the full diagnosis — the probe command, its
#     timing, and the last probes with their output.
#   * A container with no healthcheck is said to have none. "Up" in dps only
#     means the process runs; it says nothing about whether it answers.
#   * Exits 1 when something shown is unhealthy, so `dhealth || alert` works.
#   * Read-only: no preview, no confirmation.
#
# Measured on docker 29.9.2, and worth knowing before touching the templates:
#
#   * NEVER `index` a struct field here. docker inspect runs the template
#     against the TYPED container first; if that fails — and indexing State
#     fails, because State is a struct — it silently re-runs it against the
#     raw JSON as a MAP. In map mode every type changes and an absent key is
#     fatal. Measured on the same field:
#         typed  .Config.Healthcheck.Interval                5s
#         map    (after any index on a struct) ...Interval   5000000000
#     and on a container without a healthcheck the map version died with
#     "map has no entry for key Healthcheck". The first draft indexed State
#     as a precaution, and that precaution was the trigger. Typed access is
#     used throughout: an unset option is a zero value ("0s", 0), never an
#     absent key. `index` stays correct on things that really ARE maps —
#     .Config.Labels, as dip and dvol use it.
#   * Probe output can span several lines, so records are split on \x1e
#     (record separator), never on newline.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dhealth_help() {
    printf "${CB}${CCY}dhealth${CR} — why a container is (un)healthy\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dhealth${CR} [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}TWO MODES${CR}\n"
    printf "  ${CI}no pattern, or several matches${CR}   a table of every healthcheck\n"
    printf "  ${CI}a pattern matching ONE${CR}            its probe, timing, and last probes\n\n"

    printf "${CCY}EXIT CODE${CR}\n"
    printf "  ${CB}1${CR} when anything shown is unhealthy — so ${CGR}dhealth || alert${CR} works.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dhealth${CR}                  Every healthcheck on the host\n"
    printf "  ${CGR}dhealth keycloak${CR}         Why keycloak is in the state it is\n"
    printf "  ${CGR}dhealth || echo sick${CR}     Use it as a check\n"
}

# ---------------------------------------------------------------------------
# Colour for the STATUS cell — reached by the table as @healthstate
# ---------------------------------------------------------------------------

_healthstate_color_into() {
    case "$1" in
        healthy)   _DA_R="$CGR" ;;
        unhealthy) _DA_R="$CRE" ;;
        starting)  _DA_R="$CYE" ;;
        *)         _DA_R="$CDIM" ;;
    esac
}

# _dhealth_clock <time> → HH:MM:SS
#
# Typed mode prints Go's default form, "2026-10-25 22:57:28.68 -0400 -04".
# RFC 3339 ("…T22:57:28…") is what map mode prints; both are accepted, so a
# template change that flips the mode cannot quietly blank this column.
_dhealth_clock_into() {
    local t="$1"
    case "$t" in
        *T*)   t="${t#*T}" ;;
        *' '*) t="${t#* }" ;;
        *)     _DA_R="—"; return 0 ;;
    esac
    _DA_R="${t%%.*}"
    _DA_R="${_DA_R%% *}"
    [[ -z "$_DA_R" ]] && _DA_R="—"
}

# _dhealth_dur_into <nanoseconds | "5s" | <no value>> → "5s", "1m", "default"
#
# Accepts both shapes docker hands back (see the header). An option the
# healthcheck never set is docker's default, and is called that rather than
# shown as a blank that looks like a missing value.
_dhealth_dur_into() {
    local v="$1"
    case "$v" in
        # docker's typed zero value: the option was not set, so its default
        # applies. Shown as "default", never as a 0 that reads like a timeout
        # of zero seconds.
        ''|'<no value>'|0|0s) _DA_R="default"; return 0 ;;
        *[!0-9]*)          _DA_R="$v"; return 0 ;;   # already "5s"
    esac
    if   (( v >= 60000000000 && v % 60000000000 == 0 )); then _DA_R="$(( v / 60000000000 ))m"
    elif (( v % 1000000000 == 0 ));                         then _DA_R="$(( v / 1000000000 ))s"
    else                                                         _DA_R="$(( v / 1000000 ))ms"
    fi
}

# ---------------------------------------------------------------------------
# The diagnosis of one container
# ---------------------------------------------------------------------------

_dhealth_detail() {
    # `hstate`, never `status`: in zsh status is $? and read-only, and
    # assigning it aborts the function. dip shipped that bug once already.
    local name="$1" raw head logs hstate streak probe interval timeout retries start
    local tab=$'\t' rs=$'\x1e' rec exitc out when line first _DA_R

    # Two parts, joined by a record separator: the configuration, then every
    # probe. One inspect call, whatever the number of probes.
    raw=$(docker inspect "$name" --format '{{with .State.Health}}{{.Status}}{{"\t"}}{{.FailingStreak}}{{else}}none{{"\t"}}0{{end}}{{"\t"}}{{with .Config.Healthcheck}}{{range $i, $e := .Test}}{{if $i}} {{end}}{{$e}}{{end}}{{"\t"}}{{.Interval}}{{"\t"}}{{.Timeout}}{{"\t"}}{{.Retries}}{{"\t"}}{{.StartPeriod}}{{end}}{{"\x1e"}}{{with .State.Health}}{{range .Log}}{{.End}}{{"\t"}}{{.ExitCode}}{{"\t"}}{{.Output}}{{"\x1e"}}{{end}}{{end}}' 2>/dev/null) || {
        _err dhealth "could not inspect $name"
        return 1
    }

    head="${raw%%"$rs"*}"
    logs="${raw#*"$rs"}"
    hstate="${head%%"$tab"*}";   head="${head#*"$tab"}"
    streak="${head%%"$tab"*}";   head="${head#*"$tab"}"
    probe="${head%%"$tab"*}";     head="${head#*"$tab"}"
    interval="${head%%"$tab"*}"; head="${head#*"$tab"}"
    timeout="${head%%"$tab"*}";  head="${head#*"$tab"}"
    retries="${head%%"$tab"*}";  head="${head#*"$tab"}"
    start="$head"

    if [[ "$hstate" == "none" ]]; then
        printf "  %s ${CWH}${CB}%s${CR} ${CDIM}has no healthcheck${CR}\n" "$(_icon health)" "$name"
        printf "  ${CDIM}\"Up\" in dps only means the process runs — not that it answers.${CR}\n"
        printf "  ${CDIM}add one with a${CR} ${CYE}healthcheck:${CR} ${CDIM}block in its compose service.${CR}\n"
        return 1
    fi

    _healthstate_color_into "$hstate"
    printf "  %s ${CB}health${CR}  ${CDIM}·${CR}  ${CWH}${CB}%s${CR}  ${CDIM}·${CR}  ${_DA_R}${CB}%s${CR}" \
        "$(_icon health)" "$name" "$hstate"
    if (( streak > 0 )); then
        printf "  ${CRE}(%s failed in a row)${CR}" "$streak"
    fi
    printf "\n"

    # The probe command first: when a check fails, the first question is
    # "what is it actually checking?", and the answer is not obvious from
    # the container name.
    printf "  ${CDIM}test${CR}      ${CWH}%s${CR}\n" "${probe:-—}"
    _dhealth_dur_into "$interval"; interval="$_DA_R"
    _dhealth_dur_into "$timeout";  timeout="$_DA_R"
    _dhealth_dur_into "$start";    start="$_DA_R"
    case "$retries" in ''|'<no value>'|0) retries="default" ;; esac
    printf "  ${CDIM}every${CR}     %s  ${CDIM}·  timeout${CR} %s  ${CDIM}·  retries${CR} %s  ${CDIM}·  start period${CR} %s\n" \
        "$interval" "$timeout" "$retries" "$start"
    _hr

    if [[ -z "${logs//[[:space:]$rs]/}" ]]; then
        printf "  ${CDIM}no probes recorded yet${CR}\n"
    else
        printf "  ${CDIM}last probes, newest first${CR}\n"
        # docker keeps them oldest first. Collected, then printed in reverse,
        # because the newest is the one you came here for.
        local -a recs
        while [[ -n "$logs" ]]; do
            rec="${logs%%"$rs"*}"
            if [[ "$logs" == *"$rs"* ]]; then logs="${logs#*"$rs"}"; else logs=""; fi
            [[ -z "${rec//[[:space:]]/}" ]] && continue
            recs=("$rec" "${recs[@]}")
        done
        for rec in "${recs[@]}"; do
            when="${rec%%"$tab"*}";  rec="${rec#*"$tab"}"
            exitc="${rec%%"$tab"*}"; out="${rec#*"$tab"}"
            _dhealth_clock_into "$when"; when="$_DA_R"
            # The first non-empty line of the output. A probe can print a
            # whole HTTP response; the first line is the one that says why.
            first=""
            while IFS= read -r line; do
                [[ -n "${line//[[:space:]]/}" ]] && { first="$line"; break; }
            done <<< "$out"
            if [[ "$exitc" == "0" ]]; then
                printf "  ${CDIM}%s${CR}  ${CGR}exit 0${CR}  ${CDIM}%s${CR}\n" "$when" "${first:-ok}"
            else
                printf "  ${CDIM}%s${CR}  ${CRE}exit %s${CR}  %s\n" "$when" "$exitc" "${first:-(no output)}"
            fi
        done
    fi

    [[ "$hstate" == "unhealthy" ]] && return 1
    return 0
}

# ---------------------------------------------------------------------------
# dhealth
# ---------------------------------------------------------------------------

dhealth() {
    local pattern="" listing n raw line tab=$'\t' nl=$'\n' rest exact=""
    # Rows are bucketed by state so the sick ones come first: on a host with
    # forty healthchecks, the one that is failing must not be row 23.
    local name hstate streak lastexit lastend interval retries row
    local rows_sick="" rows_starting="" rows_ok=""
    local shown=0 with_check=0 without=0 sick=0 _DA_R
    local -a names matched

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) _dhealth_help; return 0 ;;
            -*) _err dhealth "unknown flag: $1"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err dhealth "one pattern at a time"; return 1; }
                pattern="$1"
                ;;
        esac
        shift
    done

    if ! listing=$(docker ps --format '{{.Names}}' 2>/dev/null); then
        _err dhealth "could not reach the docker daemon"
        return 1
    fi
    if [[ -z "$listing" ]]; then
        _err dhealth "no containers are running"
        return 1
    fi
    while IFS= read -r n; do
        [[ -z "$n" ]] && continue
        names+=("$n")
        [[ "$n" == "$pattern" ]] && exact="$n"
        [[ -z "$pattern" || "$n" =~ $pattern ]] && matched+=("$n")
    done <<< "$listing"
    # A pattern that IS a name means that container (see dx).
    [[ -n "$exact" ]] && matched=("$exact")

    if [[ -n "$pattern" && ${#matched[@]} -eq 0 ]]; then
        _err dhealth "no running container matched: $pattern"
        return 1
    fi

    # Exactly one: the diagnosis. Anything else: the table.
    if [[ -n "$pattern" && ${#matched[@]} -eq 1 ]]; then
        _dhealth_detail "${matched[@]}"
        return $?
    fi

    # --- the table: one inspect for every matched container -----------------
    raw=$(docker inspect --format '{{.Name}}{{"\t"}}{{with .State.Health}}{{.Status}}{{"\t"}}{{.FailingStreak}}{{$l := ""}}{{range .Log}}{{$l = .}}{{end}}{{"\t"}}{{if $l}}{{$l.ExitCode}}{{"\t"}}{{$l.End}}{{else}}{{"\t"}}{{end}}{{else}}none{{"\t"}}{{"\t"}}{{"\t"}}{{end}}{{"\t"}}{{with .Config.Healthcheck}}{{.Interval}}{{"\t"}}{{.Retries}}{{end}}' \
        "${matched[@]}" 2>/dev/null) || {
        _err dhealth "could not inspect the containers"
        return 1
    }

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%"$tab"*}"; name="${name#/}"; rest="${line#*"$tab"}"
        hstate="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        if [[ "$hstate" == "none" ]]; then
            without=$(( without + 1 ))
            continue
        fi
        with_check=$(( with_check + 1 ))
        streak="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        lastexit="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        lastend="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
        interval="${rest%%"$tab"*}"; retries="${rest#*"$tab"}"

        _dhealth_dur_into "$interval"; interval="$_DA_R"
        [[ "$hstate" == "unhealthy" ]] && sick=$(( sick + 1 ))
        _dhealth_clock_into "$lastend"; lastend="$_DA_R"
        [[ -z "$lastexit" ]] && lastexit="—"
        [[ -z "$streak" || "$streak" == "0" ]] && streak="—"

        shown=$(( shown + 1 ))
        row="${hstate}${tab}${streak}${tab}${lastend}${tab}${lastexit}${tab}${interval:-—}${tab}${name}${nl}"
        case "$hstate" in
            unhealthy) rows_sick+="$row" ;;
            starting)  rows_starting+="$row" ;;
            *)         rows_ok+="$row" ;;
        esac
    done <<< "$raw"

    local rows="${rows_sick}${rows_starting}${rows_ok}"
    _render_container_table "docker health" "$shown" "$with_check" "$pattern" \
        "STATUS" "FAILS" "LAST" "EXIT" "EVERY" "NAME" "${rows%"$nl"}" \
        "@healthstate,red,dim,dim,dim,white"

    if (( without > 0 )); then
        printf "  ${CDIM}%s running container(s) have no healthcheck — \"Up\" is all docker knows about them${CR}\n" "$without" >&2
    fi
    if (( sick > 0 )); then
        printf "  %s ${CRE}%s unhealthy${CR}${CDIM} — see why with${CR} ${CYE}dhealth <name>${CR}\n" "$(_icon warn)" "$sick" >&2
        return 1
    fi
    return 0
}

# Completion source: running containers.
_dhealth_candidates() {
    docker ps --format '{{.Names}}' 2>/dev/null
}
