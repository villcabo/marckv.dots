#!/usr/bin/env bash
# docker-aliases v2 — end-to-end suite.
#
# Runs every check in bash AND zsh, because that split is where the bugs live.
#
# Hermetic by design: `docker` is shimmed, so nothing here can start, stop or
# touch a real container. Service discovery still calls the real
# `docker compose config`, which parses YAML without needing a daemon.
#
# Usage:
#   ./e2e.sh              run everything
#   ./e2e.sh bash         run one shell only
#
# Exit code is the number of failures, capped at 125.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V2_DIR="$(dirname "$TESTS_DIR")"
INIT="${V2_DIR}/init.sh"

C_OK=$'\033[1;32m'; C_BAD=$'\033[1;31m'; C_DIM=$'\033[2m'; C_HEAD=$'\033[1;36m'; C_OFF=$'\033[0m'

PASSED=0
FAILED=0
CURRENT_SHELL=""

# ---------------------------------------------------------------------------
# Workspace: fixtures are copied out of the (read-only) repo mount, and a
# shimmed `docker` goes first on PATH.
# ---------------------------------------------------------------------------

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -r "${TESTS_DIR}/fixtures" "${WORK}/fixtures"
mkdir -p "${WORK}/bin"

REAL_DOCKER="$(command -v docker || true)"
if [[ -z "$REAL_DOCKER" ]]; then
    printf '%sdocker CLI not found in PATH — cannot run%s\n' "$C_BAD" "$C_OFF" >&2
    exit 125
fi

cat > "${WORK}/bin/docker" <<SHIM
#!/usr/bin/env bash
# Read-only queries reach the real docker; everything that would mutate state or
# stream forever is captured as argv instead.
#
#   config → parses YAML, needs no daemon, so it answers for real.
#   ps     → needs a daemon. There is none here, so it fails, which is exactly
#            the "cannot reach the daemon" path dcdown has to handle.
for a in "\$@"; do
    case "\$a" in
        config|ps) exec "${REAL_DOCKER}" "\$@" ;;
    esac
done
printf 'ARGV:'
for a in "\$@"; do printf ' [%s]' "\$a"; done
printf '\n'
SHIM
chmod +x "${WORK}/bin/docker"

export PATH="${WORK}/bin:${PATH}"
export DOCKER_ALIASES_NERD_FONT=0
export DOCKER_ALIASES_CACHE_TTL=0

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

section() { printf '\n%s── %s%s\n' "$C_HEAD" "$1" "$C_OFF"; }

pass() { PASSED=$(( PASSED + 1 )); printf '  %sPASS%s [%s] %s\n' "$C_OK" "$C_OFF" "$CURRENT_SHELL" "$1"; }
fail() {
    FAILED=$(( FAILED + 1 ))
    printf '  %sFAIL%s [%s] %s\n' "$C_BAD" "$C_OFF" "$CURRENT_SHELL" "$1"
    printf '       %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
    printf '       %sgot:%s      %s\n' "$C_DIM" "$C_OFF" "$(printf '%s' "$3" | tr '\n' '|')"
}

# assert_has <label> <needle> <haystack>
assert_has() {
    case "$3" in
        *"$2"*) pass "$1" ;;
        *)      fail "$1" "contains: $2" "$3" ;;
    esac
}

# assert_lacks <label> <needle> <haystack>
assert_lacks() {
    case "$3" in
        *"$2"*) fail "$1" "must NOT contain: $2" "$3" ;;
        *)      pass "$1" ;;
    esac
}

# assert_eq <label> <expected> <actual>
assert_eq() {
    if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "$2" "$3"; fi
}

strip_ansi() { sed -e 's/\x1b\[[0-9;]*m//g'; }

# in_shell <dir> <script>  → run a snippet with v2 loaded, in CURRENT_SHELL
in_shell() {
    local dir="$1" script="$2"
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $script
    " 2>&1 | strip_ansi
}

# dcup_out <dir> <args...> → preview + argv, always answering 'no'
dcup_out() {
    local dir="$1"; shift
    printf 'no\n' | "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcup $*
    " 2>&1 | strip_ansi
}

# dcup_rc <dir> <args...> → exit code only (no pipe to mask it)
dcup_rc() {
    local dir="$1"; shift
    printf 'no\n' | "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcup $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

# dcup_argv <dir> <args...> → only the shimmed argv lines, auto-confirmed
dcup_argv() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        export DOCKER_ALIASES_AUTO_YES=1
        source '$INIT'
        dcup $*
    " 2>&1 | strip_ansi | grep '^ARGV:'
}

# dclt never confirms, and the shim turns `logs` into argv instead of a
# blocking stream — so these return immediately.

# dclt_argv <dir> <args...> → STDOUT only, which must stay pipe-clean
dclt_argv() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dclt $*
    " 2>/dev/null | strip_ansi
}

# dclt_err <dir> <args...> → STDERR only, where the preview belongs
dclt_err() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dclt $*
    " 2>&1 >/dev/null | strip_ansi
}

dclt_rc() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dclt $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

# dcdown_argv <dir> <args...> → argv, auto-confirmed
dcdown_argv() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        export DOCKER_ALIASES_AUTO_YES=1
        source '$INIT'
        dcdown $*
    " 2>&1 | strip_ansi | grep '^ARGV:'
}

# dcdown_err <dir> <args...> → stderr only (preview + notes), declined
dcdown_err() {
    local dir="$1"; shift
    printf 'no\n' | "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcdown $*
    " 2>&1 >/dev/null | strip_ansi
}

# dcdown_answer <dir> <answer> <args...> → ACCEPT when it ran, REJECT when not
dcdown_answer() {
    local dir="$1" answer="$2"; shift 2
    local out
    out=$(printf '%s\n' "$answer" | "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcdown $*
    " 2>&1 | strip_ansi)
    case "$out" in
        *"ARGV:"*"down"*) printf 'ACCEPT' ;;
        *)                printf 'REJECT' ;;
    esac
}

dcdown_rc() {
    local dir="$1"; shift
    printf 'no\n' | "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcdown $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

run_suite() {
    CURRENT_SHELL="$1"
    local F="${WORK}/fixtures"
    local out rc

    section "$CURRENT_SHELL — help"
    out=$(in_shell "$F/basic" 'dcup --help')
    assert_has "--help shows USAGE"            "USAGE"        "$out"
    assert_has "--help documents combining"    "-rpl"         "$out"
    assert_has "--help states the yes rule"    "full word"    "$out"
    assert_lacks "--help offers no -y escape"  " -y "         "$out"

    section "$CURRENT_SHELL — preview"
    out=$(dcup_out "$F/basic")
    assert_has "preview names the action"      "compose up"          "$out"
    assert_has "preview shows the file"        "docker-compose.yml"  "$out"
    assert_has "preview resolves all services" "api"                 "$out"
    assert_has "preview shows the command"     "docker compose"      "$out"
    assert_has "preview asks with [yes/N]"     "[yes/N]"             "$out"

    section "$CURRENT_SHELL — flags to argv"
    assert_has "no flags → plain up -d" \
        "[up] [-d]" "$(dcup_argv "$F/basic")"
    assert_has "-r → --force-recreate" \
        "[--force-recreate]" "$(dcup_argv "$F/basic" -r)"
    assert_has "-b → --build" \
        "[--build]" "$(dcup_argv "$F/basic" -b)"
    out=$(dcup_argv "$F/basic" -rpl api)
    assert_has "-rpl expands to recreate"      "[--force-recreate]"  "$out"
    assert_has "-rpl expands to pull"          "[--pull] [always]"   "$out"
    assert_has "-rpl targets the service"      "[api]"               "$out"
    assert_has "-l follows logs afterwards"    "[logs] [-f]"         "$out"

    section "$CURRENT_SHELL — env files"
    out=$(dcup_argv "$F/envfile" -e .env.prod)
    assert_has "-e emits --env-file" "[--env-file] [.env.prod]" "$out"
    # --env-file is an option of `docker compose`, not of `up`. v1 emitted it
    # after `up`, where docker rejects it outright.
    case "$out" in
        *"[--env-file] [.env.prod]"*"[up]"*) pass "--env-file precedes up" ;;
        *) fail "--env-file precedes up" "--env-file before [up]" "$out" ;;
    esac

    section "$CURRENT_SHELL — multiple compose files"
    out=$(dcup_argv "$F/multifile" -f base.yml -f override.yml)
    assert_has "first -f survives"  "[-f] [base.yml]"     "$out"
    assert_has "second -f survives" "[-f] [override.yml]" "$out"
    out=$(dcup_out "$F/multifile" -f base.yml -f override.yml)
    assert_has "merged services include the override-only one" "sidecar" "$out"

    section "$CURRENT_SHELL — profiles"
    out=$(dcup_argv "$F/profiles" -P dev,debug)
    assert_has "comma split, first profile"  "[--profile] [dev]"   "$out"
    assert_has "comma split, second profile" "[--profile] [debug]" "$out"
    out=$(dcup_argv "$F/profiles" -P dev -P debug)
    assert_has "repeated -P, first"  "[--profile] [dev]"   "$out"
    assert_has "repeated -P, second" "[--profile] [debug]" "$out"

    section "$CURRENT_SHELL — quoting"
    assert_has "filename with a space stays one argv element" \
        "[my stack.yml]" "$(dcup_argv "$F/spaces" -f "'my stack.yml'")"

    section "$CURRENT_SHELL — compose file detection"
    out=$(dcup_out "$F/detect-env")
    assert_has "DOCKER_COMPOSE_FILE in .env is honored" "custom.yml" "$out"

    section "$CURRENT_SHELL — errors and exit codes"
    assert_eq "unknown flag exits 1"     "1" "$(dcup_rc "$F/basic" --bogus)"
    assert_eq "-f without value exits 1" "1" "$(dcup_rc "$F/basic" -f)"
    assert_eq "missing file exits 1"     "1" "$(dcup_rc "$F/basic" -f nope.yml)"
    assert_eq "declining exits 1"        "1" "$(dcup_rc "$F/basic")"
    assert_has "unknown flag explains itself" \
        "unknown flag" "$(dcup_out "$F/basic" --bogus)"

    section "$CURRENT_SHELL — confirmation"
    local answer expected
    for answer in yes YES Yes; do
        out=$(printf '%s\n' "$answer" | "$CURRENT_SHELL" -c "
            cd '$F/basic'; source '$INIT'
            _confirm_operation 'Continue?' >/dev/null 2>&1 && echo ACCEPT || echo REJECT")
        assert_eq "'$answer' is accepted" "ACCEPT" "$out"
    done
    for answer in y Y n no ""; do
        out=$(printf '%s\n' "$answer" | "$CURRENT_SHELL" -c "
            cd '$F/basic'; source '$INIT'
            _confirm_operation 'Continue?' >/dev/null 2>&1 && echo ACCEPT || echo REJECT")
        assert_eq "'${answer:-<enter>}' is rejected" "REJECT" "$out"
    done
    out=$("$CURRENT_SHELL" -c "
        cd '$F/basic'; source '$INIT'
        DOCKER_ALIASES_AUTO_YES=1 _confirm_operation 'x' </dev/null >/dev/null 2>&1 \
            && echo ACCEPT || echo REJECT")
    assert_eq "AUTO_YES bypasses the prompt (tests/CI)" "ACCEPT" "$out"

    section "$CURRENT_SHELL — discovery helpers"
    out=$(in_shell "$F/basic"    '_get_compose_services')
    assert_has "services are discovered" "worker" "$out"
    out=$(in_shell "$F/profiles" '_get_compose_profiles')
    assert_has "profiles are discovered" "debug"  "$out"

    run_dclt_checks "$F"
    run_dcdown_checks "$F"

    section "$CURRENT_SHELL — completion"
    run_completion_checks "$F"
}

# ---------------------------------------------------------------------------
# dcdown
# ---------------------------------------------------------------------------

run_dcdown_checks() {
    local F="$1" out

    section "$CURRENT_SHELL — dcdown help"
    out=$(in_shell "$F/volumes" 'dcdown --help')
    assert_has "help shows USAGE"                    "USAGE"        "$out"
    assert_has "help flags -v as destroying data"    "destroys data" "$out"
    assert_has "help explains the project-name rule" "project name" "$out"

    section "$CURRENT_SHELL — dcdown command"
    assert_has "plain down takes no extra flags" \
        "[down]" "$(dcdown_argv "$F/volumes")"
    assert_has "-v emits --volumes" \
        "[--volumes]" "$(dcdown_argv "$F/volumes" -v)"
    assert_has "-O emits --remove-orphans" \
        "[--remove-orphans]" "$(dcdown_argv "$F/volumes" -O)"
    out=$(dcdown_argv "$F/volumes" -vO)
    assert_has "-vO still removes volumes" "[--volumes]"         "$out"
    assert_has "-vO still clears orphans"  "[--remove-orphans]"  "$out"
    assert_has "a pattern narrows the target" \
        "[db]" "$(dcdown_argv "$F/volumes" db)"
    assert_lacks "a pattern excludes the rest" \
        "[cache]" "$(dcdown_argv "$F/volumes" db)"

    section "$CURRENT_SHELL — dcdown volume warning"
    out=$(dcdown_err "$F/volumes" -v)
    assert_has "preview names the first volume"   "pgdata"          "$out"
    assert_has "preview names the second volume"  "redis_data"      "$out"
    assert_has "preview says it cannot be undone" "cannot be undone" "$out"
    assert_has "prompt asks for the project name" "dav2-fixture-volumes" "$out"
    out=$(dcdown_err "$F/volumes")
    assert_lacks "no -v means no volume line"     "cannot be undone" "$out"
    assert_has  "no -v asks the ordinary way"     "[yes/N]"          "$out"

    section "$CURRENT_SHELL — dcdown confirmation strength"
    # The whole point: the answer that works everywhere else must NOT work here.
    assert_eq "-v rejects 'yes'" \
        "REJECT" "$(dcdown_answer "$F/volumes" yes -v)"
    assert_eq "-v rejects a wrong project name" \
        "REJECT" "$(dcdown_answer "$F/volumes" not-the-project -v)"
    assert_eq "-v accepts the project name" \
        "ACCEPT" "$(dcdown_answer "$F/volumes" dav2-fixture-volumes -v)"
    assert_eq "without -v 'yes' is enough" \
        "ACCEPT" "$(dcdown_answer "$F/volumes" yes)"
    assert_eq "without -v a bare 'y' still fails" \
        "REJECT" "$(dcdown_answer "$F/volumes" y)"

    section "$CURRENT_SHELL — dcdown daemon awareness"
    # Asserted without assuming a daemon: the suite runs both on a workstation
    # that has one and inside containers that do not. What must hold either way
    # is that dcdown says WHICH picture it is showing — silently presenting
    # declared services as if they were running is the failure mode here.
    out=$(dcdown_err "$F/volumes")
    case "$out" in
        *"could not reach"*|*"nothing is running"*)
            pass "states whether the list is running or declared" ;;
        *)
            fail "states whether the list is running or declared" \
                 "a note about the daemon or about nothing running" "$out" ;;
    esac
    assert_has "still lists the services" "cache" "$out"

    section "$CURRENT_SHELL — dcdown errors"
    assert_eq "no match exits 1"         "1" "$(dcdown_rc "$F/volumes" zzz)"
    assert_eq "unknown flag exits 1"     "1" "$(dcdown_rc "$F/volumes" -Z)"
    assert_eq "-f without value exits 1" "1" "$(dcdown_rc "$F/volumes" -f)"
    assert_eq "missing file exits 1"     "1" "$(dcdown_rc "$F/volumes" -f nope.yml)"
    assert_eq "declining exits 1"        "1" "$(dcdown_rc "$F/volumes")"
    out=$(dcdown_err "$F/volumes" zzz)
    assert_has "no match lists what exists" "available:" "$out"
}

# ---------------------------------------------------------------------------
# dclt
# ---------------------------------------------------------------------------

run_dclt_checks() {
    local F="$1" out

    section "$CURRENT_SHELL — dclt help"
    out=$(in_shell "$F/basic" 'dclt --help')
    assert_has "help shows USAGE"                "USAGE"                "$out"
    assert_has "help documents the bare number"  "dclt 500 api"         "$out"
    assert_has "help says patterns are regex"    "regular expressions"  "$out"

    section "$CURRENT_SHELL — dclt matching"
    assert_has "no pattern follows every service" \
        "[api] [db] [worker]" "$(dclt_argv "$F/basic")"
    assert_has "a plain word matches as a regex" \
        "[--follow] [api]" "$(dclt_argv "$F/basic" api)"
    out=$(dclt_argv "$F/basic" "'api|db'")
    assert_has "alternation matches the first"  "[api]" "$out"
    assert_has "alternation matches the second" "[db]"  "$out"
    assert_lacks "alternation excludes the rest" "[worker]" "$out"
    assert_has "an anchored pattern matches exactly one" \
        "[--follow] [api]" "$(dclt_argv "$F/basic" "'^api\$'")"
    # Services are iterated on the outside, so overlapping patterns cannot
    # produce the same service twice.
    out=$(dclt_argv "$F/basic" api "'ap'")
    assert_eq "overlapping patterns do not duplicate a service" \
        "1" "$(printf '%s' "$out" | grep -o '\[api\]' | wc -l | tr -d ' ')"

    section "$CURRENT_SHELL — dclt line count"
    assert_has "default tail is 100" \
        "[--tail] [100]" "$(dclt_argv "$F/basic")"
    assert_has "a bare number sets the tail" \
        "[--tail] [500]" "$(dclt_argv "$F/basic" 500 api)"
    assert_has "-n sets the tail too" \
        "[--tail] [500]" "$(dclt_argv "$F/basic" -n 500 api)"
    assert_has "-n all passes 'all' through" \
        "[--tail] [all]" "$(dclt_argv "$F/basic" -n all)"

    section "$CURRENT_SHELL — dclt flags"
    assert_has "follow is the default" \
        "[--follow]" "$(dclt_argv "$F/basic" api)"
    assert_lacks "-o drops --follow" \
        "[--follow]" "$(dclt_argv "$F/basic" -o api)"
    out=$(dclt_argv "$F/basic" -ot api)
    assert_has "-ot still applies timestamps"  "[--timestamps]" "$out"
    assert_lacks "-ot still suppresses follow" "[--follow]"     "$out"
    assert_has "-s emits --since" \
        "[--since] [10m]" "$(dclt_argv "$F/basic" -s 10m)"
    out=$(dclt_argv "$F/envfile" -e .env.prod)
    case "$out" in
        *"[--env-file] [.env.prod]"*"[logs]"*) pass "--env-file precedes logs" ;;
        *) fail "--env-file precedes logs" "--env-file before [logs]" "$out" ;;
    esac
    assert_has "-f selects the compose file" \
        "[-f] [base.yml]" "$(dclt_argv "$F/multifile" -f base.yml)"

    section "$CURRENT_SHELL — dclt output streams"
    # The whole point of -o is piping. A preview on stdout would poison it.
    out=$(dclt_argv "$F/basic" -o api)
    assert_lacks "stdout carries no preview"      "compose logs" "$out"
    assert_has  "stdout carries the log output"   "ARGV:"        "$out"
    out=$(dclt_err "$F/basic" -o api)
    assert_has  "stderr carries the preview"      "compose logs" "$out"
    assert_has  "preview shows the real command"  "docker compose" "$out"

    section "$CURRENT_SHELL — dclt errors"
    assert_eq "no match exits 1"        "1" "$(dclt_rc "$F/basic" zzz)"
    assert_eq "bad line count exits 1"  "1" "$(dclt_rc "$F/basic" -n abc)"
    assert_eq "-n without value exits 1" "1" "$(dclt_rc "$F/basic" -n)"
    assert_eq "unknown flag exits 1"    "1" "$(dclt_rc "$F/basic" -Z)"
    out=$(dclt_err "$F/basic" zzz)
    assert_has "no match lists what exists" "available:" "$out"
    assert_has "no match names the services" "worker"    "$out"

    section "$CURRENT_SHELL — dclt is read-only"
    # dclt must never prompt: it changes nothing. If it ever grows a
    # confirmation, this catches it — with no stdin, a prompt would hang or
    # fail rather than sail through.
    out=$("$CURRENT_SHELL" -c "
        cd '$F/basic' || exit 99
        source '$INIT'
        dclt api </dev/null" 2>/dev/null | strip_ansi)
    assert_has "runs with no stdin and no prompt" "ARGV:"   "$out"
    assert_lacks "never asks for confirmation"    "[yes/N]" "$out"
}

# ---------------------------------------------------------------------------
# Completion
#
# bash: the real completion function is invoked exactly as bash would invoke
#       it — COMP_WORDS / COMP_CWORD in, COMPREPLY out. This is the real thing.
#
# zsh:  compsys only exists inside a live completion, so `compadd` and `_files`
#       are stubbed and the function is driven directly. That covers the
#       branching and the data it feeds on — which is where the portability
#       bugs actually are — but NOT compsys wiring itself. Interactive TAB
#       remains a manual check.
# ---------------------------------------------------------------------------

run_completion_checks() {
    local F="$1" out

    if [[ "$CURRENT_SHELL" == "bash" ]]; then
        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcup ''); COMP_CWORD=1
            _dcup_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: bare word completes services" "api" "$out"

        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcup '-'); COMP_CWORD=1
            _dcup_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dash completes flags (-r)" "-r" "$out"
        assert_has "bash: dash completes flags (-P)" "-P" "$out"
        assert_lacks "bash: no -y flag is offered"   "-y" "$out"

        out=$(cd "$F/multifile" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcup -f ''); COMP_CWORD=2
            _dcup_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: -f completes yml files" "base.yml" "$out"

        out=$(cd "$F/profiles" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcup -P ''); COMP_CWORD=2
            _dcup_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: -P completes profiles" "debug" "$out"

        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dclt ''); COMP_CWORD=1
            _dclt_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dclt completes services" "worker" "$out"

        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dclt '-'); COMP_CWORD=1
            _dclt_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dclt offers -o" "-o" "$out"
        assert_has "bash: dclt offers -s" "-s" "$out"

        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dclt -n ''); COMP_CWORD=2
            _dclt_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dclt -n suggests counts" "500" "$out"
        assert_has "bash: dclt -n suggests all"    "all" "$out"

        out=$(cd "$F/basic" && bash -c "
            source '$INIT'
            COMP_WORDS=(dclt -s ''); COMP_CWORD=2
            _dclt_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dclt -s suggests durations" "10m" "$out"

        out=$(cd "$F/volumes" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcdown ''); COMP_CWORD=1
            _dcdown_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcdown completes services" "cache" "$out"

        out=$(cd "$F/volumes" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcdown '-'); COMP_CWORD=1
            _dcdown_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcdown offers -v" "-v" "$out"
        assert_has "bash: dcdown offers -O" "-O" "$out"
        return
    fi

    # zsh — stub compsys, drive the function directly.
    local stub='
        compadd() {
            local -a items
            if [[ "$1" == "-a" ]]; then items=(${(P)2}); else items=("$@"); fi
            print -l -- $items
        }
        _files() { print -l -- "__files__"; }
    '

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dcup ''); CURRENT=2
        _dcup_complete_zsh" 2>&1)
    assert_has "zsh: bare word completes services" "api" "$out"

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dcup '-'); CURRENT=2
        _dcup_complete_zsh" 2>&1)
    assert_has "zsh: dash completes flags (-r)" "-r" "$out"
    assert_has "zsh: dash completes flags (-P)" "-P" "$out"
    assert_lacks "zsh: no -y flag is offered"   "-y" "$out"

    out=$(cd "$F/profiles" && zsh -c "
        source '$INIT'
        $stub
        words=(dcup -P ''); CURRENT=3
        _dcup_complete_zsh" 2>&1)
    assert_has "zsh: -P completes profiles" "debug" "$out"

    out=$(cd "$F/multifile" && zsh -c "
        source '$INIT'
        $stub
        words=(dcup -f ''); CURRENT=3
        _dcup_complete_zsh" 2>&1)
    assert_has "zsh: -f delegates to _files" "__files__" "$out"

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dclt ''); CURRENT=2
        _dclt_complete_zsh" 2>&1)
    assert_has "zsh: dclt completes services" "worker" "$out"

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dclt '-'); CURRENT=2
        _dclt_complete_zsh" 2>&1)
    assert_has "zsh: dclt offers -o" "-o" "$out"
    assert_has "zsh: dclt offers -s" "-s" "$out"

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dclt -n ''); CURRENT=3
        _dclt_complete_zsh" 2>&1)
    assert_has "zsh: dclt -n suggests counts" "500" "$out"
    assert_has "zsh: dclt -n suggests all"    "all" "$out"

    out=$(cd "$F/basic" && zsh -c "
        source '$INIT'
        $stub
        words=(dclt -s ''); CURRENT=3
        _dclt_complete_zsh" 2>&1)
    assert_has "zsh: dclt -s suggests durations" "10m" "$out"

    out=$(cd "$F/volumes" && zsh -c "
        source '$INIT'
        $stub
        words=(dcdown ''); CURRENT=2
        _dcdown_complete_zsh" 2>&1)
    assert_has "zsh: dcdown completes services" "cache" "$out"

    out=$(cd "$F/volumes" && zsh -c "
        source '$INIT'
        $stub
        words=(dcdown '-'); CURRENT=2
        _dcdown_complete_zsh" 2>&1)
    assert_has "zsh: dcdown offers -v" "-v" "$out"
    assert_has "zsh: dcdown offers -O" "-O" "$out"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

printf '%sdocker-aliases v2 — e2e%s\n' "$C_HEAD" "$C_OFF"
printf '%s  host    : %s%s\n' "$C_DIM" "$(uname -s) $(uname -m)" "$C_OFF"
printf '%s  docker  : %s%s\n' "$C_DIM" "$($REAL_DOCKER --version 2>/dev/null)" "$C_OFF"
printf '%s  compose : %s%s\n' "$C_DIM" "$($REAL_DOCKER compose version 2>/dev/null)" "$C_OFF"

SHELLS=("${1:-}")
[[ -z "${SHELLS[0]}" ]] && SHELLS=(bash zsh)

for sh in "${SHELLS[@]}"; do
    if ! command -v "$sh" >/dev/null 2>&1; then
        printf '\n%s── %s not installed — skipped%s\n' "$C_BAD" "$sh" "$C_OFF"
        FAILED=$(( FAILED + 1 ))
        continue
    fi
    printf '%s  %-7s : %s%s\n' "$C_DIM" "$sh" "$("$sh" --version 2>&1 | head -1)" "$C_OFF"
    run_suite "$sh"
done

printf '\n%s────────────────────────%s\n' "$C_DIM" "$C_OFF"
if (( FAILED == 0 )); then
    printf '%sall %d checks passed%s\n' "$C_OK" "$PASSED" "$C_OFF"
    exit 0
fi
printf '%s%d passed, %d FAILED%s\n' "$C_BAD" "$PASSED" "$FAILED" "$C_OFF"
(( FAILED > 125 )) && exit 125
exit "$FAILED"
