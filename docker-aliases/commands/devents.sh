#!/usr/bin/env bash
# docker-aliases — devents: what happened to a container, and why.
#
# The obvious way to build this is `docker events --since 24h`, and it does not
# work. The daemon keeps the last 256 events for the WHOLE HOST, in memory, and
# every healthcheck probe adds three of them (exec_create, exec_start,
# exec_die). Measured on a host with fifteen healthchecks: "the last 24 hours"
# reached back 33 seconds. A timeline built on events alone is empty exactly
# when it is needed — and an empty timeline reads as "nothing happened".
#
# What survives is on the container itself: its exit code, whether the OOM
# killer took it, how many times its restart policy brought it back, when it
# started and ended, and its logs. So that is the backbone, and the events are
# the garnish — shown with how far back they actually reach.
#
# Design contract:
#   * Two modes, chosen by the match, as in dhealth. No pattern, or several
#     matches: a table of what happened. Exactly one: that container's story.
#     A pattern that IS a container's name picks it even when it also matches
#     others, so `devents keycloak` does not drown in keycloak-db.
#   * Without a pattern the table covers the last 24 hours (-a: all time), plus
#     anything in a bad state however old. With a pattern, every match shows.
#   * The exit code is INTERPRETED. "137" means nothing at 3 a.m.; "SIGKILL —
#     docker kill, or stop timeout — not the OOM killer" means something.
#   * Stopped containers are searched too. A post-mortem is about the dead.
#   * -f follows live events. Everything else is read-only: no preview, no
#     confirmation.
#
# Times come from GNU date, ONE call for every timestamp on screen (`date -f -`
# reads a list). Zero forks per row, and the local clock stays right across a
# daylight-saving change, which fixed-offset arithmetic would not.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_devents_help() {
    printf "${CB}${CCY}devents${CR} — what happened to a container, and why\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}devents${CR} [${CYE}-a${CR}] [${CYE}-f${CR}] [${CMA}pattern${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-a${CR}                 Table: all time, not only the last 24 hours\n"
    printf "  ${CYE}-f${CR}                 Follow events live ${CI}(Ctrl-C to stop)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "${CCY}TWO MODES${CR}\n"
    printf "  ${CI}no pattern, or several matches${CR}   what ended, restarted or started\n"
    printf "  ${CI}a pattern matching ONE${CR}            its story: why it ended, how long it\n"
    printf "                                    lived, recent events, last log lines\n\n"

    printf "${CCY}WHY NOT JUST docker events?${CR}\n"
    printf "  The daemon keeps the last 256 events for the whole host, and every\n"
    printf "  healthcheck probe adds three. \"Since 24h\" can mean the last minute.\n"
    printf "  The story comes from what the container itself remembers.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}devents${CR}               What happened on this host today\n"
    printf "  ${CGR}devents api${CR}           The story of the api container\n"
    printf "  ${CGR}devents -f api${CR}        Watch it live\n"
    printf "  ${CGR}devents -f${CR}            Watch the whole host live\n"
}

# ---------------------------------------------------------------------------
# Interpretation
# ---------------------------------------------------------------------------

# _devents_signal_into <number> → "SIGTERM"
_devents_signal_into() {
    case "$1" in
        1) _DA_R="SIGHUP" ;;   2) _DA_R="SIGINT" ;;   3) _DA_R="SIGQUIT" ;;
        6) _DA_R="SIGABRT" ;;  9) _DA_R="SIGKILL" ;;  11) _DA_R="SIGSEGV" ;;
        15) _DA_R="SIGTERM" ;; '') _DA_R="" ;;        *) _DA_R="signal $1" ;;
    esac
}

# _devents_exit_into <code> <oomkilled> → a short reason
#
# 128+n is "killed by signal n" — the shell convention docker reports. 137
# without the OOM flag is the common one to misread: it is a SIGKILL, which is
# what `docker stop` sends when the grace period runs out, and what `docker
# kill` sends by default. Only OOMKilled=true says the kernel did it.
_devents_exit_into() {
    local code="$1" oom="$2"
    if [[ "$oom" == "true" ]]; then _DA_R="out of memory — the OOM killer"; return 0; fi
    case "$code" in
        0)   _DA_R="exited cleanly" ;;
        125) _DA_R="docker could not start it" ;;
        126) _DA_R="command not executable" ;;
        127) _DA_R="command not found" ;;
        130) _DA_R="interrupted (SIGINT)" ;;
        134) _DA_R="aborted (SIGABRT)" ;;
        137) _DA_R="killed (SIGKILL) — kill, or stop timeout" ;;
        139) _DA_R="segfault (SIGSEGV)" ;;
        143) _DA_R="stopped (SIGTERM)" ;;
        ''|*[!0-9]*) _DA_R="unknown exit" ;;
        *)
            if (( code > 128 && code < 160 )); then
                _devents_signal_into $(( code - 128 )); _DA_R="killed ($_DA_R)"
            else
                _DA_R="application error"
            fi
            ;;
    esac
}

# _devents_why_into <state> <exit> <oom> <restarts> <policy> → the WHY cell
_devents_why_into() {
    local state="$1" code="$2" oom="$3" restarts="$4" policy="$5"
    case "$state" in
        restarting) _DA_R="crash loop — restarting" ;;
        dead)       _DA_R="dead — removal failed" ;;
        created)    _DA_R="created, never started" ;;
        paused)     _DA_R="paused" ;;
        running)
            if (( restarts > 0 )); then _DA_R="restarted $restarts times"
            else _DA_R="started"
            fi
            ;;
        *)
            _devents_exit_into "$code" "$oom"
            # on-failure:N that used all N restarts: docker gave up.
            if [[ "$policy" == on-failure:* && "${policy#on-failure:}" != "0" ]] \
                && (( restarts > 0 && restarts >= ${policy#on-failure:} )); then
                _DA_R="$_DA_R — gave up after $restarts restarts"
            fi
            ;;
    esac
}

# Colour for the WHY cell — reached by the table as @evwhy. Keyed on the
# wording above, so the cell carries its own severity.
_evwhy_color_into() {
    case "$1" in
        "out of memory"*|"crash loop"*|dead*|segfault*|aborted*|*"gave up"*|"application error"*|"command not"*|"docker could not"*|"unknown exit"*)
            _DA_R="$CRE" ;;
        killed*|restarted*|interrupted*) _DA_R="$CYE" ;;
        started)                         _DA_R="$CGR" ;;
        *)                               _DA_R="$CDIM" ;;
    esac
}

# Colour for the STATE cell — @evstate
_evstate_color_into() {
    case "$1" in
        running)         _DA_R="$CGR" ;;
        restarting|dead) _DA_R="$CRE" ;;
        exited)          _DA_R="$CYE" ;;
        *)               _DA_R="$CDIM" ;;
    esac
}

# _devents_ago_into <seconds> → "45s", "12m", "3h", "5d"
_devents_ago_into() {
    local s="$1"
    if   (( s < 0 ));     then _DA_R="—"
    elif (( s < 60 ));    then _DA_R="${s}s"
    elif (( s < 3600 ));  then _DA_R="$(( s / 60 ))m"
    elif (( s < 86400 )); then _DA_R="$(( s / 3600 ))h"
    else                       _DA_R="$(( s / 86400 ))d"
    fi
}

# _devents_dur_into <seconds> → "1h 12m", "3d 4h", "8s"
_devents_dur_into() {
    local s="$1"
    if   (( s < 60 ));    then _DA_R="${s}s"
    elif (( s < 3600 ));  then _DA_R="$(( s / 60 ))m $(( s % 60 ))s"
    elif (( s < 86400 )); then _DA_R="$(( s / 3600 ))h $(( s % 3600 / 60 ))m"
    else                       _DA_R="$(( s / 86400 ))d $(( s % 86400 / 3600 ))h"
    fi
}

# _devents_clock_into <"epoch Mon DD HH:MM:SS"> <"Mon DD" of today>
# → "HH:MM:SS" when it happened today, "Mon DD HH:MM" otherwise.
_devents_clock_into() {
    local day="${1#* }"
    day="${day% *}"
    if [[ "$day" == "$2" ]]; then
        _DA_R="${1##* }"
    else
        _DA_R="$day ${1##* }"
        _DA_R="${_DA_R%:*}"
    fi
}

# A timestamp GNU date can always parse. A line it rejects produces NO output
# line, which would shift every answer after it onto the wrong row; docker's
# "never" (0001-01-01…) parses fine and is recognised by its year afterwards.
_devents_ts_into() {
    case "$1" in
        [0-9][0-9][0-9][0-9]-*) _DA_R="$1" ;;
        @[0-9]*)                _DA_R="$1" ;;
        *)                      _DA_R="0001-01-01T00:00:00Z" ;;
    esac
}

# ---------------------------------------------------------------------------
# One event, formatted — shared by the story and -f
# ---------------------------------------------------------------------------

# _devents_event_line <clock> <action> <exitCode> <signal> [name]
# Returns 1 for noise that should not be printed.
_devents_event_line() {
    local clock="$1" action="$2" code="$3" sig="$4" who="${5:-}" label detail color
    case "$action" in
        exec_*|resize|top|archive-path|extract-to-dir|attach|detach) return 1 ;;
        "health_status: healthy")   label="health"; detail="healthy";   color="$CGR" ;;
        "health_status: unhealthy") label="health"; detail="unhealthy"; color="$CRE" ;;
        health_status*)             label="health"; detail="${action#health_status: }"; color="$CYE" ;;
        die)
            label="die"; _devents_exit_into "$code" false
            detail="exit $code — $_DA_R"
            if [[ "$code" == "0" ]]; then color="$CDIM"; else color="$CRE"; fi ;;
        oom)     label="oom";     detail="out of memory";    color="$CRE" ;;
        kill)    label="kill";    _devents_signal_into "$sig"; detail="$_DA_R"; color="$CYE" ;;
        start)   label="start";   detail="";                 color="$CGR" ;;
        restart) label="restart"; detail="";                 color="$CYE" ;;
        stop)    label="stop";    detail="";                 color="$CDIM" ;;
        create)  label="create";  detail="";                 color="$CDIM" ;;
        destroy) label="destroy"; detail="removed";          color="$CDIM" ;;
        *)       label="${action%%:*}"; detail="";           color="$CDIM" ;;
    esac
    _pad_into "$label" 8
    if [[ -n "$who" ]]; then
        printf "  ${CDIM}%s${CR}  ${CWH}%s${CR}  ${color}%s${CR} %s\n" "$clock" "$who" "$_DA_R" "$detail"
    else
        printf "  ${CDIM}%s${CR}  ${color}%s${CR} %s\n" "$clock" "$_DA_R" "$detail"
    fi
}

# ---------------------------------------------------------------------------
# -f: follow live
# ---------------------------------------------------------------------------

_devents_follow() {
    local target="$1" line tab=$'\t' t action code sig who clock
    local -a filter
    filter=(--filter type=container)
    [[ -n "$target" ]] && filter+=(--filter "container=$target")

    if [[ -n "$target" ]]; then
        printf "  %s ${CB}following${CR} ${CWH}%s${CR}  ${CDIM}· Ctrl-C to stop${CR}\n" "$(_icon docker)" "$target" >&2
    else
        printf "  %s ${CB}following the whole host${CR}  ${CDIM}· healthcheck probes hidden · Ctrl-C to stop${CR}\n" "$(_icon docker)" >&2
    fi

    # Action goes LAST: an exec_create action carries the whole probe command,
    # tabs and all, and anything after it would be split into the wrong field.
    docker events "${filter[@]}" \
        --format '{{.Time}}{{"\t"}}{{index .Actor.Attributes "name"}}{{"\t"}}{{index .Actor.Attributes "exitCode"}}{{"\t"}}{{index .Actor.Attributes "signal"}}{{"\t"}}{{.Action}}' \
        2>/dev/null | while IFS= read -r line; do
        t="${line%%"$tab"*}";    line="${line#*"$tab"}"
        who="${line%%"$tab"*}";  line="${line#*"$tab"}"
        code="${line%%"$tab"*}"; line="${line#*"$tab"}"
        sig="${line%%"$tab"*}";  action="${line#*"$tab"}"
        case "$action" in exec_*|resize|top|archive-path|extract-to-dir|attach|detach) continue ;; esac
        # One fork per SHOWN event: live, at human pace, after the noise is gone.
        clock=$(date -d "@$t" +%H:%M:%S 2>/dev/null) || clock="$t"
        if [[ -n "$target" ]]; then
            _devents_event_line "$clock" "$action" "$code" "$sig"
        else
            _devents_event_line "$clock" "$action" "$code" "$sig" "$who"
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# The story of one container
# ---------------------------------------------------------------------------

_devents_story() {
    local name="$1" raw tab=$'\t' nl=$'\n' rest
    local state code oom restarts policy maxr created started finished image cerr health
    local evraw logs now line t who action dates today
    local c_created c_started c_finished reach first_ev="" q cv
    local s_clock f_clock e_s e_f up ev ecode esig eaction
    local -a ev_lines log_lines

    raw=$(docker inspect "$name" --format '{{.State.Status}}{{"\t"}}{{.State.ExitCode}}{{"\t"}}{{.State.OOMKilled}}{{"\t"}}{{.RestartCount}}{{"\t"}}{{.HostConfig.RestartPolicy.Name}}{{"\t"}}{{.HostConfig.RestartPolicy.MaximumRetryCount}}{{"\t"}}{{.Created}}{{"\t"}}{{.State.StartedAt}}{{"\t"}}{{.State.FinishedAt}}{{"\t"}}{{.Config.Image}}{{"\t"}}{{with .State.Health}}{{.Status}}{{end}}{{"\t"}}{{.State.Error}}' 2>/dev/null) || {
        _err devents "could not inspect $name"
        return 1
    }
    state="${raw%%"$tab"*}";    rest="${raw#*"$tab"}"
    code="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
    oom="${rest%%"$tab"*}";     rest="${rest#*"$tab"}"
    restarts="${rest%%"$tab"*}";rest="${rest#*"$tab"}"
    policy="${rest%%"$tab"*}";  rest="${rest#*"$tab"}"
    maxr="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
    created="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
    started="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
    finished="${rest%%"$tab"*}";rest="${rest#*"$tab"}"
    image="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
    health="${rest%%"$tab"*}";  cerr="${rest#*"$tab"}"
    [[ -z "$policy" ]] && policy="no"
    [[ "$policy" == "on-failure" ]] && policy="on-failure:$maxr"

    local nownano
    nownano=$(date +%s.%N)
    now="${nownano%.*}"

    # --- the event buffer, whole: its oldest line says how far back it reaches
    # One call, no filter. --until is the current instant WITH nanoseconds,
    # and both halves of that matter. A whole second ("now") cut off the
    # events of the current second. A second in the future ("now + 1") is
    # worse: docker treats an --until that has not arrived yet as a live
    # stream and WAITS for it — measured at ~950 ms of pure waiting.
    evraw=$(docker events --since 24h --until "$nownano" \
        --format '{{.Time}}{{"\t"}}{{.Type}}{{"\t"}}{{index .Actor.Attributes "name"}}{{"\t"}}{{index .Actor.Attributes "exitCode"}}{{"\t"}}{{index .Actor.Attributes "signal"}}{{"\t"}}{{.Action}}' 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        t="${line%%"$tab"*}"; rest="${line#*"$tab"}"
        [[ -z "$first_ev" ]] && first_ev="$t"
        [[ "${rest%%"$tab"*}" == "container" ]] || continue
        rest="${rest#*"$tab"}"
        who="${rest%%"$tab"*}"
        [[ "$who" == "$name" ]] || continue
        rest="${rest#*"$tab"}"
        action="${rest#*"$tab"}"; action="${action#*"$tab"}"
        case "$action" in exec_*|resize|top|archive-path|extract-to-dir|attach|detach) continue ;; esac
        ev_lines+=("$t$tab$rest")
    done <<< "$evraw"

    # --- the last words, when it is not simply running fine
    if [[ "$state" != "running" ]] || (( restarts > 0 )); then
        logs=$(docker logs --tail 5 --timestamps "$name" 2>&1)
        while IFS= read -r line; do
            [[ -n "$line" ]] && log_lines+=("$line")
        done <<< "$logs"
    fi

    # --- every timestamp on screen, converted in ONE date call --------------
    # Order: now, created, started, finished, each event, each log line. The
    # answers come back in the same order and are consumed in the same order.
    dates="@$now"
    _devents_ts_into "$created";  dates+="$nl$_DA_R"
    _devents_ts_into "$started";  dates+="$nl$_DA_R"
    _devents_ts_into "$finished"; dates+="$nl$_DA_R"
    for line in "${ev_lines[@]}"; do dates+="$nl@${line%%"$tab"*}"; done
    for line in "${log_lines[@]}"; do _devents_ts_into "${line%% *}"; dates+="$nl$_DA_R"; done
    # "%s %b %d %H:%M:%S" — epoch for arithmetic, day for "is it today", clock.
    # The answers are a QUEUE: each consumer takes the head, in the order the
    # questions were asked. No indexing — zsh counts from 1, bash from 0.
    q=$(printf '%s\n' "$dates" | date -f - '+%s %b %d %H:%M:%S' 2>/dev/null)$nl
    cv="${q%%"$nl"*}"; q="${q#*"$nl"}"; today="${cv#* }"; today="${today% *}"
    c_created="${q%%"$nl"*}";  q="${q#*"$nl"}"
    c_started="${q%%"$nl"*}";  q="${q#*"$nl"}"
    c_finished="${q%%"$nl"*}"; q="${q#*"$nl"}"

    # --- header ------------------------------------------------------------
    _evstate_color_into "$state"
    printf "  %s ${CB}story${CR}  ${CDIM}·${CR}  ${CWH}${CB}%s${CR}  ${CDIM}·${CR}  ${_DA_R}${CB}%s${CR}" "$(_icon docker)" "$name" "$state"
    [[ "$state" == "exited" ]] && printf " ${CDIM}(%s)${CR}" "$code"
    printf "\n"

    # why — the line this command exists for
    if [[ "$state" == "exited" || "$state" == "dead" ]]; then
        _devents_exit_into "$code" "$oom"; cv="$_DA_R"
        _evwhy_color_into "$cv"
        printf "  ${CDIM}why${CR}       ${_DA_R}%s${CR}\n" "$cv"
        # What the restart policy says about how it came to be stopped.
        case "$policy" in
            always|unless-stopped)
                printf "            ${CDIM}its policy is ${CR}%s${CDIM}, so docker would have restarted a crash —${CR}\n" "$policy"
                printf "            ${CDIM}it was stopped on purpose (docker stop, compose stop/down).${CR}\n" ;;
            on-failure:*)
                if (( restarts > 0 )) && [[ "${policy#on-failure:}" != "0" ]] && (( restarts >= ${policy#on-failure:} )); then
                    printf "            ${CRE}docker gave up: %s restarts used of %s.${CR}\n" "$restarts" "${policy#on-failure:}"
                fi ;;
        esac
        [[ "$code" == "137" && "$oom" != "true" ]] && \
            printf "            ${CDIM}not the OOM killer — docker records that separately.${CR}\n"
    elif [[ "$state" == "restarting" ]]; then
        _devents_exit_into "$code" "$oom"
        printf "  ${CDIM}why${CR}       ${CRE}crash loop${CR} — last exit %s, %s\n" "$code" "$_DA_R"
    elif (( restarts > 0 )); then
        _devents_exit_into "$code" "$oom"
        printf "  ${CDIM}why${CR}       ${CYE}it crashed and its policy brought it back, %s times${CR}\n" "$restarts"
    fi
    [[ -n "$cerr" ]] && printf "  ${CDIM}error${CR}     ${CRE}%s${CR}\n" "$cerr"

    printf "  ${CDIM}restart${CR}   policy %s  ${CDIM}·${CR}  restarted %s times\n" "$policy" "$restarts"

    # lived — start, end, and how long between them
    e_s="${c_started%% *}"; e_f="${c_finished%% *}"
    if [[ "$started" == 0001-* ]]; then
        printf "  ${CDIM}lived${CR}     never started\n"
    else
        _devents_clock_into "$c_started" "$today"; s_clock="$_DA_R"
        if [[ "$state" == "running" || "$finished" == 0001-* ]] || (( e_f < e_s )); then
            _devents_dur_into $(( now - e_s ))
            printf "  ${CDIM}lived${CR}     started %s  ${CDIM}·${CR}  up %s\n" "$s_clock" "$_DA_R"
        else
            _devents_clock_into "$c_finished" "$today"; f_clock="$_DA_R"
            _devents_dur_into $(( e_f - e_s )); up="$_DA_R"
            _devents_ago_into $(( now - e_f ))
            printf "  ${CDIM}lived${CR}     started %s  ${CDIM}·${CR}  ended %s ${CDIM}(%s ago)${CR}  ${CDIM}·${CR}  up %s\n" \
                "$s_clock" "$f_clock" "$_DA_R" "$up"
        fi
    fi
    _devents_clock_into "$c_created" "$today"
    printf "  ${CDIM}created${CR}   %s  ${CDIM}from${CR} ${CCY}%s${CR}\n" "$_DA_R" "$image"
    # Only while it runs — a stopped container keeps the last health it had,
    # and "unhealthy" on a dead container describes a probe nobody runs.
    if [[ -n "$health" && "$state" == "running" ]]; then
        _healthstate_color_into "$health"
        printf "  ${CDIM}health${CR}    ${_DA_R}%s${CR}  ${CDIM}· the probes:${CR} ${CYE}dhealth %s${CR}\n" "$health" "$name"
    fi

    # --- recent events -----------------------------------------------------
    _hr
    if [[ -n "$first_ev" ]]; then
        _devents_dur_into $(( now - first_ev )); reach="$_DA_R"
    else
        reach="nothing"
    fi
    printf "  ${CDIM}recent events — docker keeps the last 256 for the whole host; here that reaches back${CR} %s\n" "$reach"
    if (( ${#ev_lines[@]} == 0 )); then
        printf "  ${CDIM}none in that window — the story above is what the container remembers${CR}\n"
    fi
    for ev in "${ev_lines[@]}"; do
        cv="${q%%"$nl"*}"; q="${q#*"$nl"}"
        rest="${ev#*"$tab"}"
        ecode="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        esig="${rest%%"$tab"*}";  eaction="${rest#*"$tab"}"
        _devents_clock_into "$cv" "$today"
        _devents_event_line "$_DA_R" "$eaction" "$ecode" "$esig"
    done

    # --- last log lines ----------------------------------------------------
    if (( ${#log_lines[@]} > 0 )); then
        _hr
        printf "  ${CDIM}last log lines${CR}\n"
        for line in "${log_lines[@]}"; do
            cv="${q%%"$nl"*}"; q="${q#*"$nl"}"
            _devents_clock_into "$cv" "$today"
            printf "  ${CDIM}%s${CR}  %s\n" "$_DA_R" "${line#* }"
        done
        printf "  ${CDIM}more with${CR} ${CYE}docker logs --tail 100 %s${CR}\n" "$name"
    fi

    case "$state" in
        exited|dead|restarting) return 1 ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# devents
# ---------------------------------------------------------------------------

devents() {
    local show_all=false follow=false pattern="" arg i ch
    local listing n exact="" raw line tab=$'\t' nl=$'\n' rest now dates d
    local name state code oom restarts policy maxr started finished health
    local e_s e_f last why ago keep rows="" rowsort="" sorted shown=0 total=0 q
    local -a names matched
    local window=86400

    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -h|--help) _devents_help; return 0 ;;
            # One arm per flag as well as the clustered form, as dnet, dps and
            # di do: completion.bats checks the completions against these arms.
            -a) show_all=true ;;
            -f) follow=true ;;
            -[a-zA-Z]*)
                for (( i = 1; i < ${#arg}; i++ )); do
                    ch="${arg:$i:1}"
                    case "$ch" in
                        a) show_all=true ;;
                        f) follow=true ;;
                        h) _devents_help; return 0 ;;
                        *) _err devents "unknown flag: -$ch"; return 1 ;;
                    esac
                done
                ;;
            -*) _err devents "unknown flag: $arg"; return 1 ;;
            *)
                [[ -n "$pattern" ]] && { _err devents "one pattern at a time"; return 1; }
                pattern="$arg"
                ;;
        esac
        shift
    done

    if ! listing=$(docker ps -a --format '{{.Names}}' 2>/dev/null); then
        _err devents "could not reach the docker daemon"
        return 1
    fi
    while IFS= read -r n; do
        [[ -z "$n" ]] && continue
        names+=("$n")
        [[ "$n" == "$pattern" ]] && exact="$n"
        [[ -z "$pattern" || "$n" =~ $pattern ]] && matched+=("$n")
    done <<< "$listing"

    if [[ -n "$pattern" && ${#matched[@]} -eq 0 ]]; then
        _err devents "no container matched: $pattern"
        return 1
    fi
    # A pattern that IS a name picks it, however many others it also matches.
    [[ -n "$exact" ]] && matched=("$exact")

    if $follow; then
        if [[ -n "$pattern" && ${#matched[@]} -gt 1 ]]; then
            _err devents "-f follows one container or the whole host; '$pattern' matched ${#matched[@]}:"
            for n in "${matched[@]}"; do printf "    %s\n" "$n" >&2; done
            return 1
        fi
        if [[ -n "$pattern" ]]; then _devents_follow "${matched[@]}"; else _devents_follow ""; fi
        return $?
    fi

    if [[ -n "$pattern" && ${#matched[@]} -eq 1 ]]; then
        _devents_story "${matched[@]}"
        return $?
    fi

    # --- the table ---------------------------------------------------------
    if [[ ${#matched[@]} -eq 0 ]]; then
        printf "  ${CDIM}no containers on this host${CR}\n" >&2
        return 0
    fi
    raw=$(docker inspect --format '{{.Name}}{{"\t"}}{{.State.Status}}{{"\t"}}{{.State.ExitCode}}{{"\t"}}{{.State.OOMKilled}}{{"\t"}}{{.RestartCount}}{{"\t"}}{{.HostConfig.RestartPolicy.Name}}{{"\t"}}{{.HostConfig.RestartPolicy.MaximumRetryCount}}{{"\t"}}{{with .State.Health}}{{.Status}}{{end}}{{"\t"}}{{.State.StartedAt}}{{"\t"}}{{.State.FinishedAt}}' \
        "${matched[@]}" 2>/dev/null) || {
        _err devents "could not inspect the containers"
        return 1
    }

    # Two timestamps per container, all converted in one date call, read back
    # two at a time in the same order.
    now=$(date +%s)
    dates=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        finished="${line##*"$tab"}"; rest="${line%"$tab"*}"; started="${rest##*"$tab"}"
        _devents_ts_into "$started";  dates+="$_DA_R$nl"
        _devents_ts_into "$finished"; dates+="$_DA_R$nl"
    done <<< "$raw"
    # Read back as a queue, two answers per container, in the order asked.
    q=$(printf '%s' "$dates" | date -f - +%s 2>/dev/null)$nl

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        e_s="${q%%"$nl"*}"; q="${q#*"$nl"}"
        e_f="${q%%"$nl"*}"; q="${q#*"$nl"}"

        name="${line%%"$tab"*}"; name="${name#/}"; rest="${line#*"$tab"}"
        state="${rest%%"$tab"*}";    rest="${rest#*"$tab"}"
        code="${rest%%"$tab"*}";     rest="${rest#*"$tab"}"
        oom="${rest%%"$tab"*}";      rest="${rest#*"$tab"}"
        restarts="${rest%%"$tab"*}"; rest="${rest#*"$tab"}"
        policy="${rest%%"$tab"*}";   rest="${rest#*"$tab"}"
        maxr="${rest%%"$tab"*}";     rest="${rest#*"$tab"}"
        health="${rest%%"$tab"*}"
        [[ "$policy" == "on-failure" ]] && policy="on-failure:$maxr"

        total=$(( total + 1 ))
        # The latest thing that happened to it: an end, or a (re)start.
        last="$e_s"; [[ -n "$e_f" ]] && (( e_f > last )) && last="$e_f"

        keep=0
        if [[ -n "$pattern" ]] || $show_all; then keep=1
        elif (( now - last <= window )); then keep=1
        fi
        case "$state" in restarting|dead) keep=1 ;; esac
        # Only while it runs: a stopped container keeps the LAST health it had,
        # so five-day-old corpses were all showing up as "unhealthy" today.
        [[ "$health" == "unhealthy" && "$state" == "running" ]] && keep=1
        (( keep )) || continue

        _devents_why_into "$state" "$code" "$oom" "$restarts" "$policy"; why="$_DA_R"
        [[ "$health" == "unhealthy" && "$state" == "running" ]] && why="unhealthy — see dhealth"
        if (( last < 0 )); then ago="—"; else _devents_ago_into $(( now - last )); ago="$_DA_R"; fi
        [[ "$state" == "running" || "$state" == "created" ]] && code="—"

        shown=$(( shown + 1 ))
        rowsort+="${last}${tab}${ago}${tab}${state}${tab}${code}${tab}${restarts}${tab}${why}${tab}${name}${nl}"
    done <<< "$raw"

    # Newest first: one sort for the whole table.
    if [[ -n "$rowsort" ]]; then
        sorted=$(printf '%s' "$rowsort" | LC_ALL=C sort -t "$tab" -k1,1nr)
        while IFS= read -r line; do
            [[ -n "$line" ]] && rows+="${line#*"$tab"}$nl"
        done <<< "$sorted"
    fi

    local filter="$pattern"
    if [[ -z "$pattern" ]] && ! $show_all; then filter="last 24h"; fi

    _render_container_table "what happened" "$shown" "$total" "$filter" \
        "WHEN" "STATE" "EXIT" "RESTARTS" "WHY" "NAME" "${rows%"$nl"}" \
        "dim,@evstate,dim,dim,@evwhy,white"

    if [[ -z "$pattern" ]] && ! $show_all; then
        printf "  ${CDIM}%s untouched in 24h, see${CR} ${CYE}devents -a${CR}" $(( total - shown )) >&2
        printf "${CDIM} · one container's story:${CR} ${CYE}devents <name>${CR}\n" >&2
    else
        printf "  ${CDIM}one container's story:${CR} ${CYE}devents <name>${CR}\n" >&2
    fi
    return 0
}

# Completion source: every container, stopped ones included.
_devents_candidates() {
    docker ps -a --format '{{.Names}}' 2>/dev/null | LC_ALL=C sort
}
