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

# Destinations the shimmed containers claim to live in, so dcd has somewhere
# real to cd into.
mkdir -p "${WORK}/fake-project" "${WORK}/other-project"

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
#
# dcx probes the container for bash before opening a shell. There is no real
# container here, so the answer is driven by DAV2_FAKE_BASH — which lets the
# suite exercise BOTH the bash branch and the sh fallback.
#
# dcver probes each container for git.properties. Answered from an invented
# world so the parsing, the dirty flag and the "not found" row are all
# exercised: cleanapp has one, dirtyapp has a dirty one, nothing has none.
case "\$*" in
    *"@@PATH@@"*)
        for a in "\$@"; do
            case "\$a" in
                cleanapp)
                    printf '@@PATH@@/app/resources/git.properties\n'
                    printf 'app.version=1.1.0-d3cabc9\ngit.branch=main\n'
                    printf 'git.commit.id.abbrev=d3cabc9\ngit.dirty=false\n'
                    printf 'git.commit.time=2024-04-18T16\\:56\\:45-0400\n'
                    exit 0 ;;
                dirtyapp)
                    printf '@@PATH@@/app/BOOT-INF/classes/git.properties\n'
                    printf 'app.version=2.0.0-aabbccd\ngit.branch=develop\n'
                    printf 'git.commit.id.abbrev=aabbccd\ngit.dirty=true\n'
                    printf 'git.commit.time=2024-04-18T16\\:56\\:45-0400\n'
                    exit 0 ;;
                nothing) exit 1 ;;
            esac
        done
        exit 1 ;;
esac
case "\$*" in
    *"command -v bash"*)
        [ "\${DAV2_FAKE_BASH:-0}" = "1" ] && exit 0 || exit 1 ;;
esac
#
# dcd reaches for the host's containers, which do not exist in here. The shim
# invents a small, fixed world so the grouping logic is testable:
#   fx-api, fx-db  → one project, one directory   (several matches, NOT ambiguous)
#   other-api      → a second project             (a pattern spanning both IS)
#   plain-box      → no compose labels at all
#
# dps and dcps ask for their own formats. Answered with rows that carry the
# messy real-world port strings, so compaction is exercised through the command
# and not only in isolation. Checked BEFORE the plain {{.Names}} case, which
# would otherwise swallow dps's format too.
# inspect is settled FIRST: dcd asks for the compose project LABEL, so a
# format-based match below would hijack it.
if [ "\$1" = "inspect" ]; then
    shift
    for c in "\$@"; do
        case "\$c" in --format|*"{{"*) continue ;; esac
        case "\$c" in
            fx-api)    printf 'running\nfixture-proj\napi\n${WORK}/fake-project\n${WORK}/fake-project/docker-compose.yml,${WORK}/fake-project/docker-compose.override.yml\n' ;;
            fx-db)     printf 'exited\nfixture-proj\ndb\n${WORK}/fake-project\n${WORK}/fake-project/docker-compose.yml,${WORK}/fake-project/docker-compose.override.yml\n' ;;
            other-api) printf 'running\nother-proj\napi\n${WORK}/other-project\n${WORK}/other-project/docker-compose.yml\n' ;;
            plain-box) printf 'running\n\n\n\n\n' ;;
            *) exit 1 ;;
        esac
    done
    exit 0
fi

case "\$*" in
    *"{{.Names}}"*"{{.RunningFor}}"*)
        printf 'fx-api\ta1b2c3d4e5f6\tnginx:alpine\tUp 2 hours\t3 weeks ago\t2026-06-30 22:04:16 -0400 -04\t0.0.0.0:9080->9080/tcp, [::]:9080->9080/tcp\n'
        printf 'fx-db\tb2c3d4e5f6a1\tpostgres:18-alpine\tUp 2 hours (healthy)\tAbout an hour ago\t2026-07-23 01:00:00 -0400 -04\t5432/tcp\n'
        printf 'other-api\tc3d4e5f6a1b2\tquay.io/example/very-long-image-name:1.2.3\tUp 1 hour\t2 months ago\t2026-05-20 10:00:00 -0400 -04\t0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp\n'
        printf 'plain-box\td4e5f6a1b2c3\talpine:latest\tExited (137) 3 minutes ago\t5 days ago\t2026-07-18 08:00:00 -0400 -04\t\n'
        exit 0 ;;
    *"{{.Service}}"*)
        printf 'api\ta1b2c3d4e5f6\tnginx:alpine\tUp 2 hours\t3 weeks ago\t2026-06-30 22:04:16 -0400 -04\t127.0.0.1:8080->80/tcp\n'
        printf 'db\tb2c3d4e5f6a1\tpostgres:18-alpine\tUp 2 hours (unhealthy)\t5 days ago\t2026-07-18 08:00:00 -0400 -04\t5432/tcp\n'
        printf 'dns\tc3d4e5f6a1b2\tcoredns:1.11\tUp 2 hours\tAbout a minute ago\t2026-07-23 05:00:00 -0400 -04\t0.0.0.0:53->53/udp\n'
        exit 0 ;;
esac
case "\$* " in
    *"ps -a "*|*"--format {{.Names}}"*)
        printf 'fx-api\nfx-db\nother-api\nplain-box\n'; exit 0 ;;
esac
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

    section "$CURRENT_SHELL — no workstation-only tools"
    # These are excellent and they are on the author's machine. None of them is
    # on a fresh Debian server, which is where these aliases get used. An `sd`
    # slipped into dcver and only the distro matrix caught it — this catches the
    # next one before the matrix has to.
    local tool hits
    for tool in sd rg fd bat eza exa jq yq delta dust procs fzf; do
        hits=$(grep -rnE "(^|[;&|(\\\`]|\\\$\\()[[:space:]]*${tool}[[:space:]]" \
            "$V2_DIR/commands" "$V2_DIR/lib" "$V2_DIR/completions" "$V2_DIR/init.sh" \
            2>/dev/null | grep -v '^\s*#' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
        assert_eq "no '$tool' in the sources" "" "$hits"
    done

    section "$CURRENT_SHELL — properties parsing"
    # Java .properties escapes ":" on write, so a timestamp arrives as
    # 2024-04-18T16\:56\:45 and reads like a typo if passed through raw.
    local pv
    pv() { "$CURRENT_SHELL" -c "source '$INIT'; _prop_value '$1' '$2'" 2>/dev/null; }
    assert_eq "a plain value is read" "main" \
        "$(pv git.branch 'git.branch=main')"
    assert_eq "escaped colons are undone" "2024-04-18T16:56:45-0400" \
        "$(pv git.commit.time 'git.commit.time=2024-04-18T16\:56\:45-0400')"
    assert_eq "escaped hashes too" "fix #136" \
        "$(pv git.msg 'git.msg=fix \#136')"
    # A key that is a prefix of another must not match it.
    assert_eq "keys match exactly" "7" \
        "$(pv git.commit.id.abbrev 'git.commit.id=abcdefg1234
git.commit.id.abbrev=7')"

    section "$CURRENT_SHELL — dcver"
    out=$(ps_out "$F/versions" dcver)
    assert_has "the table is titled"            "compose versions" "$out"
    assert_has "version comes from app.version" "1.1.0-d3cabc9"    "$out"
    assert_has "a second service is listed"     "2.0.0-aabbccd"    "$out"
    assert_has "the short commit is shown"      "d3cabc9"          "$out"
    assert_has "the branch is shown"            "develop"          "$out"
    # THE flag: a dirty build cannot be reproduced from the commit it names.
    assert_has "a dirty build is flagged"       "dirty"            "$out"
    # …and a clean one must NOT be, or the flag stops meaning anything.
    out=$(ps_out "$F/versions" dcver cleanapp)
    assert_lacks "a clean build is not flagged" "dirty"            "$out"
    assert_has  "the filter narrows it"         "1 of 1"           "$out"
    # A service without the file is reported, not silently dropped.
    out=$(ps_out "$F/versions" dcver)
    assert_has "a missing file is stated"       "no git.properties" "$out"
    assert_has "and counted honestly"           "2 of 3"            "$out"
    # The 40-char hash and the merge-commit paragraph v1 printed are gone.
    assert_lacks "no full-length commit hash"   "d3cabc9876e722"    "$out"

    out=$(ps_out "$F/versions" dcver -r cleanapp)
    assert_has "raw mode dumps every field"     "git.commit.id.abbrev" "$out"
    assert_has "raw mode says where it found it" "/app/resources"      "$out"
    # Raw means raw: the file as it is on disk, escaping included. The table is
    # where values get cleaned up.
    assert_has "raw keeps the file verbatim"    "16\\:56"             "$out"

    assert_eq "an unknown flag exits 1" "1" \
        "$("$CURRENT_SHELL" -c "cd '$F/versions'; source '$INIT'; dcver -Z" >/dev/null 2>&1; printf '%s' "$?")"
    out=$("$CURRENT_SHELL" -c "cd '$F/versions'; source '$INIT'; dcver zzz" 2>&1 | strip_ansi)
    assert_has "no match lists what exists" "available:" "$out"

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

    section "$CURRENT_SHELL — no workstation-only tools"
    # These are excellent and they are on the author's machine. None of them is
    # on a fresh Debian server, which is where these aliases get used. An `sd`
    # slipped into dcver and only the distro matrix caught it — this catches the
    # next one before the matrix has to.
    local tool hits
    for tool in sd rg fd bat eza exa jq yq delta dust procs fzf; do
        hits=$(grep -rnE "(^|[;&|(\\\`]|\\\$\\()[[:space:]]*${tool}[[:space:]]" \
            "$V2_DIR/commands" "$V2_DIR/lib" "$V2_DIR/completions" "$V2_DIR/init.sh" \
            2>/dev/null | grep -v '^\s*#' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
        assert_eq "no '$tool' in the sources" "" "$hits"
    done

    section "$CURRENT_SHELL — properties parsing"
    # Java .properties escapes ":" on write, so a timestamp arrives as
    # 2024-04-18T16\:56\:45 and reads like a typo if passed through raw.
    local pv
    pv() { "$CURRENT_SHELL" -c "source '$INIT'; _prop_value '$1' '$2'" 2>/dev/null; }
    assert_eq "a plain value is read" "main" \
        "$(pv git.branch 'git.branch=main')"
    assert_eq "escaped colons are undone" "2024-04-18T16:56:45-0400" \
        "$(pv git.commit.time 'git.commit.time=2024-04-18T16\:56\:45-0400')"
    assert_eq "escaped hashes too" "fix #136" \
        "$(pv git.msg 'git.msg=fix \#136')"
    # A key that is a prefix of another must not match it.
    assert_eq "keys match exactly" "7" \
        "$(pv git.commit.id.abbrev 'git.commit.id=abcdefg1234
git.commit.id.abbrev=7')"

    section "$CURRENT_SHELL — dcver"
    out=$(ps_out "$F/versions" dcver)
    assert_has "the table is titled"            "compose versions" "$out"
    assert_has "version comes from app.version" "1.1.0-d3cabc9"    "$out"
    assert_has "a second service is listed"     "2.0.0-aabbccd"    "$out"
    assert_has "the short commit is shown"      "d3cabc9"          "$out"
    assert_has "the branch is shown"            "develop"          "$out"
    # THE flag: a dirty build cannot be reproduced from the commit it names.
    assert_has "a dirty build is flagged"       "dirty"            "$out"
    # …and a clean one must NOT be, or the flag stops meaning anything.
    out=$(ps_out "$F/versions" dcver cleanapp)
    assert_lacks "a clean build is not flagged" "dirty"            "$out"
    assert_has  "the filter narrows it"         "1 of 1"           "$out"
    # A service without the file is reported, not silently dropped.
    out=$(ps_out "$F/versions" dcver)
    assert_has "a missing file is stated"       "no git.properties" "$out"
    assert_has "and counted honestly"           "2 of 3"            "$out"
    # The 40-char hash and the merge-commit paragraph v1 printed are gone.
    assert_lacks "no full-length commit hash"   "d3cabc9876e722"    "$out"

    out=$(ps_out "$F/versions" dcver -r cleanapp)
    assert_has "raw mode dumps every field"     "git.commit.id.abbrev" "$out"
    assert_has "raw mode says where it found it" "/app/resources"      "$out"
    # Raw means raw: the file as it is on disk, escaping included. The table is
    # where values get cleaned up.
    assert_has "raw keeps the file verbatim"    "16\\:56"             "$out"

    assert_eq "an unknown flag exits 1" "1" \
        "$("$CURRENT_SHELL" -c "cd '$F/versions'; source '$INIT'; dcver -Z" >/dev/null 2>&1; printf '%s' "$?")"
    out=$("$CURRENT_SHELL" -c "cd '$F/versions'; source '$INIT'; dcver zzz" 2>&1 | strip_ansi)
    assert_has "no match lists what exists" "available:" "$out"

    section "$CURRENT_SHELL — profiles"
    # Profiles decide WHICH SERVICES EXIST, so a service list built without them
    # describes a different project. Getting this wrong made the preview name
    # one service while the command it printed would start two.
    out=$("$CURRENT_SHELL" -c "cd '$F/profiles'; source '$INIT'; _get_compose_services" 2>/dev/null)
    assert_has  "unprofiled services always show" "api"      "$out"
    assert_lacks "profiled ones stay hidden"      "debugger" "$out"

    out=$("$CURRENT_SHELL" -c "cd '$F/profiles'; source '$INIT'; _get_compose_services --profiles debug" 2>/dev/null)
    assert_has  "a profile reveals its services" "debugger" "$out"
    assert_lacks "and only its own"              "seeder"   "$out"

    out=$("$CURRENT_SHELL" -c "cd '$F/profiles'; source '$INIT'; _get_compose_services --profiles dev,debug" 2>/dev/null)
    assert_has "comma-separated profiles, first"  "seeder"   "$out"
    assert_has "comma-separated profiles, second" "debugger" "$out"

    # THE RULE: the services named in the preview must be the services the
    # printed command would actually act on.
    out=$(dcup_out "$F/profiles" -P debug)
    assert_has "the preview lists the profiled service" "debugger"          "$out"
    assert_has "and the command enables that profile"   "--profile debug"   "$out"
    out=$(dcup_out "$F/profiles")
    assert_lacks "with no -P it stays out of both"      "debugger"          "$out"

    # COMPOSE_PROFILES in .env — docker applies it unprompted, so discovery
    # must reflect it without us passing anything.
    out=$("$CURRENT_SHELL" -c "cd '$F/composeprofiles'; source '$INIT'; _get_compose_services" 2>/dev/null)
    assert_has  "COMPOSE_PROFILES from .env is honoured" "dev_only"   "$out"
    assert_lacks "and does not enable other profiles"    "debug_only" "$out"

    # -P REPLACES COMPOSE_PROFILES rather than adding to it. Verified against
    # real docker; discovery has to agree or the preview drifts again.
    out=$("$CURRENT_SHELL" -c "cd '$F/composeprofiles'; source '$INIT'; _get_compose_services --profiles debug" 2>/dev/null)
    assert_has  "-P brings in its own profile"     "debug_only" "$out"
    assert_lacks "-P REPLACES the .env profiles"   "dev_only"   "$out"

    section "$CURRENT_SHELL — COMPOSE_FILE"
    # docker's own variable, holding a SEPARATED LIST of files. Reading only its
    # first entry is how a five-file project starts one of them — and how TAB
    # offered a single service in a project that has five.
    out=$("$CURRENT_SHELL" -c "cd '$F/composefile'; source '$INIT'; _resolve_compose_files" 2>/dev/null)
    assert_has "the first listed file is used"  "docker-compose.yml"       "$out"
    assert_has "the second one too"             "docker-compose.extra.yml" "$out"
    assert_has "and the third"                  "docker-compose.more.yml"  "$out"
    # Setting COMPOSE_FILE disables docker's automatic override merge, so adding
    # the sibling back would diverge from docker in the other direction.
    assert_lacks "the override is NOT merged in" "docker-compose.override.yml" "$out"

    out=$("$CURRENT_SHELL" -c "cd '$F/composefile'; source '$INIT'; _get_compose_services" 2>/dev/null)
    assert_has "services come from the whole list"   "extra" "$out"
    assert_has "including the last file's"           "more"  "$out"
    assert_lacks "and not from the unlisted override" "must_not_appear" "$out"

    # The env var outranks .env, exactly as docker resolves it.
    out=$("$CURRENT_SHELL" -c "
        cd '$F/composefile'
        COMPOSE_FILE=docker-compose.yml
        export COMPOSE_FILE
        source '$INIT'
        _resolve_compose_files" 2>/dev/null)
    assert_lacks "the environment overrides .env" "extra" "$out"

    out=$("$CURRENT_SHELL" -c "cd '$F/composefile-sep'; source '$INIT'; _resolve_compose_files" 2>/dev/null)
    assert_has "COMPOSE_PATH_SEPARATOR is honoured" "docker-compose.extra.yml" "$out"

    # The command must ACT on all of them, not merely display them.
    out=$(dcup_argv "$F/composefile")
    assert_has "dcup passes the first file"  "[-f] [docker-compose.yml]"       "$out"
    assert_has "dcup passes the second"      "[-f] [docker-compose.extra.yml]" "$out"
    assert_has "dcup passes the third"       "[-f] [docker-compose.more.yml]"  "$out"

    section "$CURRENT_SHELL — override auto-detection"
    # `docker compose` merges docker-compose.override.yml on its own, but ONLY
    # when no -f is passed. Every command here passes -f so the preview can name
    # the file, which silently dropped the override until this was fixed.
    out=$(dcup_argv "$F/override")
    assert_has "dcup takes the base file"     "[-f] [docker-compose.yml]"          "$out"
    assert_has "dcup adds the override"       "[-f] [docker-compose.override.yml]" "$out"
    out=$(dclt_argv "$F/override" -o)
    assert_has "dclt adds the override too"   "[-f] [docker-compose.override.yml]" "$out"
    out=$(dcdown_argv "$F/override")
    assert_has "dcdown adds the override too" "[-f] [docker-compose.override.yml]" "$out"
    # The service that only exists in the override is the real proof.
    out=$(dcup_out "$F/override")
    assert_has "the override-only service is visible" "sidecar" "$out"
    # An explicitly chosen file is taken at its word, exactly as docker does.
    out=$(dcup_argv "$F/multifile" -f base.yml)
    assert_lacks "an explicit -f gets no sibling guessed for it" \
        "docker-compose.override.yml" "$out"

    run_dclt_checks "$F"
    run_dcdown_checks "$F"
    run_dcx_checks "$F"
    run_dcd_checks "$F"
    run_ps_checks "$F"

    section "$CURRENT_SHELL — completion"
    run_completion_checks "$F"
}

# ---------------------------------------------------------------------------
# dcx
# ---------------------------------------------------------------------------

# dcx_argv <dir> <args...> → argv only
dcx_argv() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcx $*
    " 2>/dev/null | strip_ansi | grep '^ARGV:'
}

# dcx_argv_bash <dir> <args...> → same, pretending the image ships bash
dcx_argv_bash() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        export DAV2_FAKE_BASH=1
        source '$INIT'
        dcx $*
    " 2>/dev/null | strip_ansi | grep '^ARGV:'
}

dcx_err() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcx $*
    " 2>&1 >/dev/null | strip_ansi
}

dcx_rc() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        dcx $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

run_dcx_checks() {
    local F="$1" out

    section "$CURRENT_SHELL — dcx help"
    out=$(in_shell "$F/multimatch" 'dcx --help')
    assert_has "help shows USAGE"                  "USAGE"          "$out"
    assert_has "help explains the shell fallback"  "falling back"   "$out"
    assert_has "help warns flags precede pattern"  "BEFORE"         "$out"

    section "$CURRENT_SHELL — dcx shell selection"
    # The daily tax this command exists to remove: alpine has no bash.
    assert_has "no bash in the image falls back to sh" \
        "[api] [sh]" "$(dcx_argv "$F/multimatch" "'^api\$'")"
    assert_has "bash is used when the image has it" \
        "[api] [bash]" "$(dcx_argv_bash "$F/multimatch" "'^api\$'")"
    assert_lacks "an explicit command skips the probe entirely" \
        "[sh]" "$(dcx_argv "$F/multimatch" "'^api\$'" ls)"

    section "$CURRENT_SHELL — dcx argument handling"
    # The parse must stop at the pattern, or -la is read as a dcx flag.
    out=$(dcx_argv "$F/multimatch" "'^api\$'" ls -la /app)
    assert_has "the command survives intact"        "[ls] [-la] [/app]" "$out"
    assert_lacks "its flags are not eaten by dcx"   "unknown flag"      "$out"
    assert_has "-u becomes --user" \
        "[--user] [root]" "$(dcx_argv "$F/multimatch" -u root "'^api\$'")"
    assert_has "-w becomes --workdir" \
        "[--workdir] [/app]" "$(dcx_argv "$F/multimatch" -w /app "'^api\$'" npm test)"
    # Non-interactive by definition here, so the TTY must be dropped.
    assert_has "no TTY is requested when there is no terminal" \
        "[--no-tty]" "$(dcx_argv "$F/multimatch" "'^api\$'")"

    section "$CURRENT_SHELL — dcx refuses to guess"
    out=$(dcx_err "$F/multimatch" api)
    assert_has "says how many matched"        "matched 2 services" "$out"
    assert_has "lists the ambiguous services" "api-worker"         "$out"
    assert_has "suggests an anchored pattern" "^api"               "$out"
    assert_eq  "an ambiguous pattern exits 1" "1" "$(dcx_rc "$F/multimatch" api)"
    assert_has "an anchored pattern resolves it" \
        "[api] [sh]" "$(dcx_argv "$F/multimatch" "'^api\$'")"

    section "$CURRENT_SHELL — dcx errors"
    assert_eq "no match exits 1"          "1" "$(dcx_rc "$F/multimatch" zzz)"
    assert_eq "a missing pattern exits 1" "1" "$(dcx_rc "$F/multimatch")"
    assert_eq "unknown flag exits 1"      "1" "$(dcx_rc "$F/multimatch" -Z api)"
    assert_eq "-u without value exits 1"  "1" "$(dcx_rc "$F/multimatch" -u)"
    out=$(dcx_err "$F/multimatch")
    assert_has "explains that a pattern is required" "pattern is required" "$out"

    section "$CURRENT_SHELL — dcx preview"
    out=$(dcx_err "$F/multimatch" "'^api\$'")
    assert_has "preview names the action"   "compose exec" "$out"
    assert_has "preview names the service"  "api"          "$out"
    assert_lacks "it never asks to confirm" "[yes/N]"      "$out"
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
# dcd
# ---------------------------------------------------------------------------

# dcd_out <args...> → stdout only (the path, in -p mode)
dcd_out() {
    "$CURRENT_SHELL" -c "
        cd '$WORK' || exit 99
        source '$INIT'
        dcd $*
    " 2>/dev/null
}

# dcd_err <args...> → stderr only (the details block)
dcd_err() {
    "$CURRENT_SHELL" -c "
        cd '$WORK' || exit 99
        source '$INIT'
        dcd $*
    " 2>&1 >/dev/null | strip_ansi
}

# dcd_pwd <args...> → where the shell ended up
dcd_pwd() {
    "$CURRENT_SHELL" -c "
        cd '$WORK' || exit 99
        source '$INIT'
        dcd $* >/dev/null 2>&1
        pwd
    " 2>/dev/null
}

dcd_rc() {
    "$CURRENT_SHELL" -c "
        cd '$WORK' || exit 99
        source '$INIT'
        dcd $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

run_dcd_checks() {
    local out

    section "$CURRENT_SHELL — dcd help"
    out=$("$CURRENT_SHELL" -c "source '$INIT'; dcd --help" 2>&1 | strip_ansi)
    assert_has "help shows USAGE"                "USAGE"          "$out"
    assert_has "help documents -p for scripting" "scripting"      "$out"
    assert_has "help states env vars are hidden" "never shown"    "$out"

    section "$CURRENT_SHELL — dcd jumping"
    # Several containers of ONE project is the normal case, not an ambiguity.
    assert_eq "many containers, one project, still jumps" \
        "${WORK}/fake-project" "$(dcd_pwd fx)"
    assert_eq "-p prints the path on stdout" \
        "${WORK}/fake-project" "$(dcd_out -p fx)"
    assert_eq "-p leaves the shell where it was" \
        "${WORK}" "$(dcd_pwd -p fx)"
    assert_eq "-i does not move either" \
        "${WORK}" "$(dcd_pwd -i fx)"
    assert_eq "an anchored pattern still works" \
        "${WORK}/fake-project" "$(dcd_pwd "'^fx-api\$'")"

    section "$CURRENT_SHELL — dcd details"
    out=$(dcd_err -i fx)
    assert_has "names the project"              "fixture-proj"  "$out"
    assert_has "counts what is running"         "1/2 running"   "$out"
    assert_has "lists the services"             "db"            "$out"
    assert_has "shows the compose file"         "docker-compose.yml"          "$out"
    assert_has "shows the override too"         "docker-compose.override.yml" "$out"
    assert_has "shows the directory"            "fake-project"  "$out"
    # Compose files are stored absolute; showing them relative to the project
    # keeps the block readable.
    assert_lacks "paths are not repeated in full" \
        "${WORK}/fake-project/docker-compose.yml" "$out"

    section "$CURRENT_SHELL — dcd privacy"
    # docker inspect hands over environment variables freely. dcd must not.
    out=$(dcd_err -i fx)
    assert_lacks "no environment section" "Env"      "$out"
    assert_lacks "no variable assignments" "PASSWORD" "$out"

    section "$CURRENT_SHELL — dcd refuses to guess"
    out=$(dcd_err api)
    assert_has "says how many projects it spans" "spans 2 projects" "$out"
    assert_has "names the first project"         "fixture-proj"     "$out"
    assert_has "names the second project"        "other-proj"       "$out"
    assert_eq  "spanning two projects exits 1"   "1" "$(dcd_rc api)"
    assert_eq  "and does not move the shell"     "${WORK}" "$(dcd_pwd api)"

    section "$CURRENT_SHELL — dcd errors"
    assert_eq "no match exits 1"          "1" "$(dcd_rc zzz)"
    assert_eq "a missing pattern exits 1" "1" "$(dcd_rc)"
    assert_eq "unknown flag exits 1"      "1" "$(dcd_rc -Z fx)"
    assert_eq "two patterns exit 1"       "1" "$(dcd_rc fx other)"
    out=$(dcd_err plain-box)
    assert_has "a non-compose container is explained" "docker compose" "$out"
    assert_eq  "and exits 1"              "1" "$(dcd_rc plain-box)"
}

# ---------------------------------------------------------------------------
# dps / dcps
# ---------------------------------------------------------------------------

# ports <raw> [show_exposed] → the compacted rendering
ports() {
    "$CURRENT_SHELL" -c "
        source '$INIT'
        _compact_ports '$1' '${2:-false}'
    " 2>/dev/null
}

ps_out() {
    local dir="$1"; shift
    "$CURRENT_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 | strip_ansi
}

run_ps_checks() {
    local F="$1" out

    section "$CURRENT_SHELL — nerd font icons"
    # The whole suite runs with DOCKER_ALIASES_NERD_FONT=0, so for a long time
    # nothing here ever executed the Nerd Font branch — and it shipped with
    # every glyph replaced by an empty string. A blank icon looks exactly like
    # a working one that the terminal cannot draw, so nobody noticed.
    local icon bytes
    for icon in docker file services flags cmd dir volumes warn confirm health; do
        bytes=$("$CURRENT_SHELL" -c "
            DOCKER_ALIASES_NERD_FONT=1
            export DOCKER_ALIASES_NERD_FONT
            source '$INIT'
            _icon $icon" 2>/dev/null | wc -c | tr -d ' ')
        assert_eq "icon '$icon' emits a glyph" "3" "$bytes"
    done
    # And it must be a real glyph, not the '*' every unknown name falls back to.
    out=$("$CURRENT_SHELL" -c "
        DOCKER_ALIASES_NERD_FONT=1
        export DOCKER_ALIASES_NERD_FONT
        source '$INIT'
        _icon health" 2>/dev/null)
    assert_lacks "health is not the unknown-icon fallback" "*" "$out"

    section "$CURRENT_SHELL — port compaction"
    # The whole reason dps1 / dpsp existed: this string is 76 characters wide.
    assert_eq "unpublished ports are dropped, published kept" \
        "9080 9443" \
        "$(ports '8080/tcp, 8443/tcp, 0.0.0.0:9080->9080/tcp, 9000/tcp, 0.0.0.0:9443->9443/tcp')"
    assert_eq "the v4/v6 pair collapses to one" \
        "3001→3000" "$(ports '0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp')"
    assert_eq "an identical host and container port shows once" \
        "5432" "$(ports '0.0.0.0:5432->5432/tcp')"
    assert_eq "a localhost binding is marked" \
        "lo:8080→80" "$(ports '127.0.0.1:8080->80/tcp')"
    assert_eq "a non-tcp protocol is kept" \
        "53/udp" "$(ports '0.0.0.0:53->53/udp')"
    assert_eq "exposed-only yields nothing by default" \
        "" "$(ports '5432/tcp, 8080/tcp')"
    assert_eq "and is marked with ~ when asked for" \
        "~5432 ~8080" "$(ports '5432/tcp, 8080/tcp' true)"
    # A port published on IPv6 only must not vanish with the dedupe.
    assert_eq "an IPv6-only publish still appears" \
        "3001→3000" "$(ports '[::]:3001->3000/tcp')"
    assert_eq "empty in, empty out" "" "$(ports '')"

    section "$CURRENT_SHELL — dps"
    out=$(ps_out "$F/basic" dps)
    assert_has "header names the scope"      "docker ps"    "$out"
    assert_has "header counts the rows"      "4 of 4"       "$out"
    assert_has "the header follows docker ps" "CONTAINER ID  IMAGE  " "$out"
    assert_has "and ends with NAMES, as docker does" "NAMES" "$out"
    assert_has "the id is shown in full"     "a1b2c3d4e5f6" "$out"
    assert_has "the image is shown"          "nginx:alpine" "$out"
    # The tag is the point of the column: a cut one cannot tell you which build.
    assert_has "long images are NOT truncated" \
        "quay.io/example/very-long-image-name:1.2.3" "$out"
    assert_lacks "nothing in the row is ellipsized" "…" "$out"
    assert_has "ports arrive compacted"      "9080"         "$out"
    assert_lacks "no raw docker port syntax" "0.0.0.0:"     "$out"
    assert_lacks "no /tcp noise"             "/tcp"         "$out"
    assert_has "a container with none shows a dash" "—"     "$out"
    out=$(ps_out "$F/basic" dps -x)
    assert_has "-x reveals the exposed ones" "~5432" "$out"
    out=$(ps_out "$F/basic" dps fx)
    assert_has "a pattern filters"           "2 of 4"    "$out"
    assert_has "and says what it filtered on" "filter:"  "$out"
    assert_lacks "excluding the rest"        "other-api" "$out"

    section "$CURRENT_SHELL — dcps"
    out=$(ps_out "$F/basic" dcps)
    assert_has "header names the scope"     "compose ps" "$out"
    assert_has "service comes first"        "SERVICE"    "$out"
    assert_has "the id is shown"            "a1b2c3d4e5f6" "$out"
    assert_has "the image is shown"         "postgres:18-alpine" "$out"
    assert_has "service is the last column"  "SERVICE" "$out"
    assert_has "the localhost mark survives" "lo:8080→80" "$out"
    assert_has "udp survives"                "53/udp"     "$out"
    out=$(ps_out "$F/basic" dcps db)
    assert_has "a pattern filters services" "1 of 3" "$out"

    section "$CURRENT_SHELL — status and duration compaction"
    dur() { "$CURRENT_SHELL" -c "source '$INIT'; _short_duration '$1'" 2>/dev/null; }
    st()  { "$CURRENT_SHELL" -c "source '$INIT'; _short_status '$1'"   2>/dev/null; }
    assert_eq "hours shorten"            "5h"  "$(dur '5 hours ago')"
    assert_eq "weeks shorten"            "3w"  "$(dur '3 weeks ago')"
    # minutes and months both start with m and must not collide
    assert_eq "minutes become m"         "20m" "$(dur '20 minutes ago')"
    assert_eq "months become mo"         "2mo" "$(dur '2 months ago')"
    assert_eq "docker's 'About an hour'" "1h"  "$(dur 'About an hour ago')"
    assert_eq "docker's 'About a minute'" "1m" "$(dur 'About a minute ago')"
    # In ASCII mode the three health states stay distinguishable on purpose:
    # whoever lost the Nerd Font may have lost colour too, and with one glyph
    # for all three it is the colour that carries the meaning.
    assert_eq "healthy is marked"        "Up 5h +" "$(st 'Up 5 hours (healthy)')"
    assert_eq "unhealthy reads different" "Up 2m !" "$(st 'Up 2 minutes (unhealthy)')"
    assert_eq "starting reads different" "Up 3s ~" "$(st 'Up 3 seconds (starting)')"
    # The exit code is the whole point of the line: 137 is an OOM kill.
    assert_eq "an exit code survives"    "Exit 137 · 3m" "$(st 'Exited (137) 3 minutes ago')"
    assert_eq "a clean exit survives"    "Exit 0 · 2d"   "$(st 'Exited (0) 2 days ago')"
    out=$(ps_out "$F/basic" dps)
    assert_has "the OOM exit code reaches the table" "137" "$out"
    assert_has "created is relative by default"      "3w"  "$out"
    out=$(ps_out "$F/basic" dps -t)
    assert_has "-t switches to a date"    "2026-06-30" "$out"
    assert_lacks "and drops the doubled zone offset" "-0400 -04" "$out"

    section "$CURRENT_SHELL — ps errors"
    assert_eq "dps rejects an unknown flag"  "1" \
        "$("$CURRENT_SHELL" -c "cd '$F/basic'; source '$INIT'; dps -Z" >/dev/null 2>&1; printf '%s' "$?")"
    assert_eq "dcps rejects an unknown flag" "1" \
        "$("$CURRENT_SHELL" -c "cd '$F/basic'; source '$INIT'; dcps -Z" >/dev/null 2>&1; printf '%s' "$?")"
    out=$(ps_out "$F/basic" dps zzzz)
    assert_has "no match still renders a table" "0 of 4"    "$out"
    assert_has "and says so plainly"    "nothing to show"   "$out"
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

        # A half-typed command already naming a profile must offer that
        # profile's services — otherwise TAB describes a different project.
        out=$(cd "$F/profiles" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcup -P debug ''); COMP_CWORD=3
            _dcup_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: services follow the typed -P" "debugger" "$out"

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

        out=$(cd "$F/multimatch" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcx ''); COMP_CWORD=1
            _dcx_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcx completes services first" "api-worker" "$out"

        out=$(cd "$F/multimatch" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcx api ''); COMP_CWORD=2
            _dcx_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: after the pattern it offers commands" "bash" "$out"
        assert_lacks "after the pattern it stops offering services" "api-worker" "$out"

        out=$(cd "$F/multimatch" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcx -u ''); COMP_CWORD=2
            _dcx_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: -u suggests root" "root" "$out"

        out=$(cd "$WORK" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcd ''); COMP_CWORD=1
            _dcd_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcd completes containers host-wide" "other-api" "$out"

        out=$(cd "$WORK" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcd '-'); COMP_CWORD=1
            _dcd_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcd offers -p" "-p" "$out"
        assert_has "bash: dcd offers -i" "-i" "$out"

        out=$(cd "$F/versions" && bash -c "
            source '$INIT'
            COMP_WORDS=(dcver ''); COMP_CWORD=1
            _dcver_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"" 2>&1)
        assert_has "bash: dcver completes services" "dirtyapp" "$out"
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

    out=$(cd "$F/profiles" && zsh -c "
        source '$INIT'
        $stub
        words=(dcup -P debug ''); CURRENT=4
        _dcup_complete_zsh" 2>&1)
    assert_has "zsh: services follow the typed -P" "debugger" "$out"

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

    out=$(cd "$F/multimatch" && zsh -c "
        source '$INIT'
        $stub
        words=(dcx ''); CURRENT=2
        _dcx_complete_zsh" 2>&1)
    assert_has "zsh: dcx completes services first" "api-worker" "$out"

    out=$(cd "$F/multimatch" && zsh -c "
        source '$INIT'
        $stub
        words=(dcx api ''); CURRENT=3
        _dcx_complete_zsh" 2>&1)
    assert_has "zsh: after the pattern it offers commands" "bash" "$out"
    assert_lacks "after the pattern it stops offering services" "api-worker" "$out"

    out=$(cd "$F/multimatch" && zsh -c "
        source '$INIT'
        $stub
        words=(dcx -u ''); CURRENT=3
        _dcx_complete_zsh" 2>&1)
    assert_has "zsh: -u suggests root" "root" "$out"

    out=$(cd "$WORK" && zsh -c "
        source '$INIT'
        $stub
        words=(dcd ''); CURRENT=2
        _dcd_complete_zsh" 2>&1)
    assert_has "zsh: dcd completes containers host-wide" "other-api" "$out"

    out=$(cd "$WORK" && zsh -c "
        source '$INIT'
        $stub
        words=(dcd '-'); CURRENT=2
        _dcd_complete_zsh" 2>&1)
    assert_has "zsh: dcd offers -p" "-p" "$out"
    assert_has "zsh: dcd offers -i" "-i" "$out"

    out=$(cd "$F/versions" && zsh -c "
        source '$INIT'
        $stub
        words=(dcver ''); CURRENT=2
        _dcver_complete_zsh" 2>&1)
    assert_has "zsh: dcver completes services" "dirtyapp" "$out"
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
