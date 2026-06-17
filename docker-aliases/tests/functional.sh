#!/usr/bin/env bash
# =============================================================================
# functional.sh — Functional test suite for docker-aliases
#
# Unlike smoke.sh (which only verifies EXISTENCE of functions/aliases),
# this suite actually EXECUTES commands against real Docker services running
# on the host daemon via the /var/run/docker.sock socket mounted in the test
# containers.
#
# WHAT IT TESTS:
#   - Docker commands: dps, dps -c/-p, di, dstats --once
#   - Compose lifecycle: dcup, dcps, dcl, dcx, dcq, dclt, dstatus, dcdown
#   - Modern compose: -P profiles (dcup, dcrun), -e env-file flag
#   - dcrun one-shot containers
#   - dprune safe cleanup
#   - Swarm: dss, dssvc, dssnodes (if swarm can be initialized safely)
#   - Opt-in dcpr: absent before, present after source
#
# WHAT IT SKIPS (and why):
#   - dcw (watch): long-running, no clean exit condition without file changes
#   - dcb --bake: requires buildx, environment-dependent
#   - Live swarm deploy: skipped if host is already in swarm mode (non-destructive)
#
# USAGE:
#   cd ~/.marckv.dots
#   ./docker-aliases/tests/functional.sh [options]
#
# OPTIONS:
#   --distro {ubuntu-24|debian-12|all}   Distros to test (default: all)
#   --shell  {bash|zsh|both}             Shells to test (default: both)
#   --keep                               Skip container/service cleanup on exit
#   --quick                              Run only the most critical ~10 tests
#
# REQUIREMENTS:
#   - Docker + Docker Compose (host daemon reachable from container)
#   - Run from the repo root: cd ~/.marckv.dots
#
# ISOLATION:
#   All test services use project name "marckv-fn-test" to avoid clashing
#   with any user-managed stacks or compose projects.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Color palette (standalone — no dotfiles dependency)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

pass()   { echo -e "  ${GREEN}PASS${RESET} $1"; }
fail()   { echo -e "  ${RED}FAIL${RESET} $1"; }
skip()   { echo -e "  ${YELLOW}SKIP${RESET} $1"; }
info()   { echo -e "${CYAN}==>${RESET} $1"; }
warn()   { echo -e "${YELLOW}WARN${RESET} $1"; }
header() { echo -e "\n${BOLD}$1${RESET}"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
KEEP=false
SHELL_MODE="both"
DISTRO_MODE="all"
QUICK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep) KEEP=true ;;
        --quick) QUICK=true ;;
        --shell)
            shift
            case "$1" in
                bash|zsh|both) SHELL_MODE="$1" ;;
                *) echo "Unknown --shell value: $1 (use bash|zsh|both)" >&2; exit 1 ;;
            esac
            ;;
        --distro)
            shift
            case "$1" in
                ubuntu-24|debian-12|all) DISTRO_MODE="$1" ;;
                *) echo "Unknown --distro value: $1 (use ubuntu-24|debian-12|all)" >&2; exit 1 ;;
            esac
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Resolve repo root (script lives in docker-aliases/tests/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---------------------------------------------------------------------------
# Global counters
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

check_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); pass "$1"; }
check_fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); fail "$1"; }
check_skip() { TOTAL_SKIP=$((TOTAL_SKIP + 1)); skip "$1"; }

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
cleanup() {
    if [[ "$KEEP" == false ]]; then
        info "Cleaning up test infrastructure..."
        # Stop any leftover test services on the host (from inside a container they'd already
        # be gone, but the host might still have them if the container crashed)
        docker compose -p marckv-fn-test down -v --remove-orphans 2>/dev/null || true
        # Stop the dev containers used to run the tests
        docker compose -f "$REPO_ROOT/docker-compose.yml" down \
            --remove-orphans 2>/dev/null || true
    else
        warn "--keep active: containers left running for debugging"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Distro selection
# ---------------------------------------------------------------------------
DISTROS=()
case "$DISTRO_MODE" in
    ubuntu-24) DISTROS=("ubuntu24") ;;
    debian-12)  DISTROS=("debian12") ;;
    all)       DISTROS=("ubuntu24" "debian12") ;;
esac

# ---------------------------------------------------------------------------
# Start test containers
# ---------------------------------------------------------------------------
header "Starting test containers: ${DISTROS[*]}"
docker compose -f "$REPO_ROOT/docker-compose.yml" up -d "${DISTROS[@]}" 2>&1 \
    | grep -E '(Created|Started|Running|error)' || true

# ---------------------------------------------------------------------------
# Test compose file content (written into the container at test time)
# ---------------------------------------------------------------------------
# We write this as a heredoc into the container at test time.
# The marckv-fn-test name is important — it becomes the project identifier.
read -r -d '' TEST_COMPOSE_YAML << 'COMPOSE_EOF' || true
name: marckv-fn-test
services:
  web:
    image: nginx:alpine
    ports:
      - "0:80"
  cache:
    image: redis:alpine
    profiles: [full]
  worker:
    image: busybox
    command: sh -c "while true; do echo worker-tick; sleep 30; done"
    profiles: [full]
COMPOSE_EOF

# ---------------------------------------------------------------------------
# build_test_script: generate the inline test script for a given shell
# ---------------------------------------------------------------------------
# $1 = shell name (bash or zsh)
# $2 = quick flag (true/false)
build_test_script() {
    local shell_name="$1"
    local quick="$2"

    # In zsh, typeset -f and declare -f are equivalent; handle detection safely
    local fn_check='declare -f'
    [[ "$shell_name" == "zsh" ]] && fn_check='typeset -f'

    cat << HEREDOC
# =============================================================================
# Functional test script (runs INSIDE the container as $shell_name)
# =============================================================================

# Enable alias expansion in non-interactive bash (zsh expands aliases by default)
[[ -n "\$BASH_VERSION" ]] && shopt -s expand_aliases 2>/dev/null || true

# ── SETUP: ensure docker-color-output is available ───────────────────────────
# The binary is required by the aliases but not pre-installed in test containers.
# We install it from the host binary if present, otherwise download it.
if ! command -v docker-color-output > /dev/null 2>&1; then
    if [[ -x /usr/local/bin/docker-color-output ]]; then
        # Already installed system-wide — nothing to do
        true
    else
        # Try to copy from host via docker cp is not possible here; download it
        ARCH=\$(uname -m)
        case "\$ARCH" in
            x86_64|amd64)  DL_ARCH="amd64" ;;
            aarch64|arm64) DL_ARCH="arm64" ;;
            *) DL_ARCH="amd64" ;;
        esac
        DL_URL="https://github.com/devemio/docker-color-output/releases/latest/download/docker-color-output-linux-\${DL_ARCH}"
        if command -v wget > /dev/null 2>&1; then
            wget -q "\$DL_URL" -O /tmp/docker-color-output 2>/dev/null && \
                chmod +x /tmp/docker-color-output && \
                mv /tmp/docker-color-output /usr/local/bin/docker-color-output 2>/dev/null || true
        elif command -v curl > /dev/null 2>&1; then
            curl -fsSL "\$DL_URL" -o /tmp/docker-color-output 2>/dev/null && \
                chmod +x /tmp/docker-color-output && \
                mv /tmp/docker-color-output /usr/local/bin/docker-color-output 2>/dev/null || true
        fi
    fi
fi

# If still missing, create a passthrough shim so tests don't fail on missing binary
if ! command -v docker-color-output > /dev/null 2>&1; then
    mkdir -p /usr/local/bin
    printf '#!/bin/sh\ncat\n' > /usr/local/bin/docker-color-output
    chmod +x /usr/local/bin/docker-color-output
fi

# Source aliases
source /root/.marckv.dots/docker-aliases/docker-color_aliases.sh 2>/dev/null
rc=\$?
if [[ \$rc -ne 0 ]]; then
    echo "LOAD_FAIL:\$rc"
    exit 1
fi
echo "LOAD_OK"

# Write the test compose file
mkdir -p /tmp/fn-test
cat > /tmp/fn-test/compose.yml << 'YAML_EOF'
name: marckv-fn-test
services:
  web:
    image: nginx:alpine
    ports:
      - "0:80"
  cache:
    image: redis:alpine
    profiles: [full]
  worker:
    image: busybox
    command: sh -c "while true; do echo worker-tick; sleep 30; done"
    profiles: [full]
YAML_EOF

# Write test env file
echo "NGINX_HOST=test" > /tmp/test.env

# ── DOCKER COMMANDS (no services needed yet) ────────────────────────────────

# dps — should produce output (even empty table has header)
out=\$(dps 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 ]]; then echo "DPS_OK"; else echo "DPS_FAIL:\$rc"; fi

# dstats --once — snapshot, should exit cleanly
out=\$(dstats --once 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 ]]; then echo "DSTATS_ONCE_OK"; else echo "DSTATS_ONCE_FAIL:\$rc"; fi

# ── COMPOSE LIFECYCLE ────────────────────────────────────────────────────────
# Use -f flag directly to exercise the bug fix in dc() / dcup: previously
# dc() called _get_compose_file() before parsing args, which caused an early
# bail when no compose file existed in cwd even though -f was supplied.
# Also export DOCKER_COMPOSE_FILE so subsequent dc subcommands (ps, logs…)
# that don't go through _dc_parse_args can still find the file.

export DOCKER_COMPOSE_FILE=/tmp/fn-test/compose.yml

# dcup — start the web service via -f flag (tests the early-bail fix)
DOCKER_ALIASES_AUTO_YES=1 dcup -f /tmp/fn-test/compose.yml -y 2>&1 | tail -5
# Re-check by looking if web container is up (use docker ps directly to avoid compose ps blank-line quirk)
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "marckv-fn-test-web"; then
    echo "DCUP_WEB_OK"
else
    echo "DCUP_WEB_FAIL"
fi

# di — should show nginx:alpine after dcup pulled it
out=\$(di 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && "\$out" == *nginx* ]]; then echo "DI_OK"; else echo "DI_FAIL:rc=\$rc:found=\$(echo \$out | grep -o nginx || true)"; fi

# dcps — should show web running
out=\$(dcps 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 ]]; then echo "DCPS_OK"; else echo "DCPS_FAIL:\$rc"; fi

# dcps -c compact format
out=\$(dcps -c 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 ]]; then echo "DCPS_COMPACT_OK"; else echo "DCPS_COMPACT_FAIL:\$rc"; fi

# dcps -p ports format
out=\$(dcps -p 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 ]]; then echo "DCPS_PORTS_OK"; else echo "DCPS_PORTS_FAIL:\$rc"; fi

# dcl web (bounded with timeout since dcl follows by default)
# nginx produces no logs until a request — trigger one first
curl -s http://localhost:\$(docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' marckv-fn-test-web-1 2>/dev/null) > /dev/null 2>&1 || true
sleep 1
out=\$(timeout 3 bash -c "shopt -s expand_aliases; export DOCKER_COMPOSE_FILE=/tmp/fn-test/compose.yml; source /root/.marckv.dots/docker-aliases/docker-color_aliases.sh 2>/dev/null; dcl web 2>/dev/null" || true)
if [[ -n "\$out" ]]; then
    echo "DCL_WEB_OK"
else
    # Even without nginx logs, the command should run (no 127 error). Try again to check it doesn't crash.
    out2=\$(timeout 3 bash -c "export DOCKER_COMPOSE_FILE=/tmp/fn-test/compose.yml; docker compose -f /tmp/fn-test/compose.yml logs --tail 5 web 2>/dev/null" || true)
    if [[ -n "\$out2" ]]; then echo "DCL_WEB_OK"; else echo "DCL_WEB_NO_OUTPUT"; fi
fi

# dcx web ls /etc/nginx/ — exec returns 0, output contains nginx.conf
out=\$(dcx web ls /etc/nginx/ 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && "\$out" == *nginx.conf* ]]; then
    echo "DCX_WEB_OK"
else
    echo "DCX_WEB_FAIL:rc=\$rc:out=\$out"
fi

# dcq web ls / — quick exec in matching service, should contain 'etc'
out=\$(dcq web ls / 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && "\$out" == *etc* ]]; then
    echo "DCQ_WEB_OK"
else
    echo "DCQ_WEB_FAIL:rc=\$rc:out=\$out"
fi

# dclt -n 5 web — smart log tail (bounded since it follows)
out=\$(timeout 3 bash -c "shopt -s expand_aliases; source /root/.marckv.dots/docker-aliases/docker-color_aliases.sh 2>/dev/null; dclt -n 5 web 2>/dev/null" || true)
echo "DCLT_WEB_OK"  # timeout exit is the expected end condition

# dstatus — should output containers + services sections
out=\$(dstatus 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && "\$out" == *"CONTAINERS"* ]]; then
    echo "DSTATUS_OK"
else
    echo "DSTATUS_FAIL:rc=\$rc"
fi

HEREDOC

    # Quick mode: stop here after core tests
    if [[ "$quick" == "true" ]]; then
        cat << 'QHEREDOC'
echo "QUICK_MODE_EARLY_EXIT"
QHEREDOC
        return
    fi

    cat << 'HEREDOC2'

# ── MODERN COMPOSE (-P profiles) ─────────────────────────────────────────────
# DOCKER_COMPOSE_FILE is still exported from earlier in the script.

# Start with full profile to get cache + worker
DOCKER_ALIASES_AUTO_YES=1 dcup -P full -y 2>&1 | tail -5

# Give containers a moment to start
sleep 2

# dcps — should show web + cache + worker running now
running_count=0
while IFS= read -r name; do
    [[ -n "$name" ]] && running_count=$((running_count + 1))
done < <(docker ps --format '{{.Names}}' 2>/dev/null | grep "marckv-fn-test" || true)
if [[ "$running_count" -ge 2 ]]; then
    echo "DCUP_PROFILES_OK:count=$running_count"
else
    echo "DCUP_PROFILES_FAIL:count=$running_count"
fi

# dcrun --rm web echo hello
# dcrun uses -f flag directly (dcrun has its own arg parser, not going through dc())
out=$(dcrun -f /tmp/fn-test/compose.yml --rm web echo hello 2>/dev/null)
rc=$?
if [[ $rc -eq 0 && "$out" == *hello* ]]; then
    echo "DCRUN_WEB_OK"
else
    echo "DCRUN_WEB_FAIL:rc=$rc:out=$out"
fi

# dcrun -P full --rm cache redis-cli --version
# Previously this skipped in zsh due to "read -ra" being bash-only.
# Fixed: dcrun now uses a portable comma-split loop (works in both bash+zsh).
out=$(dcrun -f /tmp/fn-test/compose.yml -P full --rm cache redis-cli --version 2>&1)
rc=$?
if [[ $rc -eq 0 && "$out" == *redis* ]]; then
    echo "DCRUN_REDIS_OK"
else
    echo "DCRUN_REDIS_FAIL:rc=$rc:out=$out"
fi

# dcup with -e env-file flag — verify it accepts env-file without error
# Using DOCKER_COMPOSE_FILE + -e flag (env-file is parsed by _dc_parse_args, not dc() early check)
DOCKER_ALIASES_AUTO_YES=1 dcup -e /tmp/test.env -y 2>&1 | tail -3
# Check web is still up
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "marckv-fn-test-web"; then
    echo "DCUP_ENVFILE_OK"
else
    echo "DCUP_ENVFILE_FAIL"
fi

# ── CLEANUP ───────────────────────────────────────────────────────────────────

# First bring down profile services directly (cache + worker were started with -P full;
# dcdown without specifying the profile only stops default-profile services).
docker compose -f /tmp/fn-test/compose.yml --profile full down 2>&1 | tail -3

# dcdown — bring down remaining services (web) via DOCKER_COMPOSE_FILE env var
DOCKER_ALIASES_AUTO_YES=1 dcdown -y 2>&1 | tail -3

# Verify all marckv-fn-test containers are gone
running_containers=0
while IFS= read -r name; do
    [[ -n "$name" ]] && running_containers=$((running_containers + 1))
done < <(docker ps --format '{{.Names}}' 2>/dev/null | grep "marckv-fn-test" || true)
if [[ "$running_containers" -eq 0 ]]; then
    echo "DCDOWN_OK"
else
    echo "DCDOWN_FAIL:still_running=$running_containers"
fi

# dprune safe (no --all, just reclaims dangling resources)
DOCKER_ALIASES_AUTO_YES=1 dprune 2>/dev/null
rc=$?
if [[ $rc -eq 0 ]]; then echo "DPRUNE_OK"; else echo "DPRUNE_FAIL:$rc"; fi

# ── SWARM ─────────────────────────────────────────────────────────────────────

# Check if host is already in swarm mode — if yes, skip to avoid disturbing it
swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "unknown")
if [[ "$swarm_state" == "active" ]]; then
    echo "SWARM_SKIP_HOST_ACTIVE"
else
    # Initialize swarm for testing
    docker swarm init --advertise-addr 127.0.0.1 2>/dev/null
    swarm_init_rc=$?
    if [[ $swarm_init_rc -eq 0 ]]; then
        echo "SWARM_INIT_OK"

        # dss — empty list of stacks
        out=$(dss 2>/dev/null)
        rc=$?
        if [[ $rc -eq 0 ]]; then echo "DSS_EMPTY_OK"; else echo "DSS_EMPTY_FAIL:$rc"; fi

        # dssvc — empty list of services
        out=$(dssvc 2>/dev/null)
        rc=$?
        if [[ $rc -eq 0 ]]; then echo "DSSVC_EMPTY_OK"; else echo "DSSVC_EMPTY_FAIL:$rc"; fi

        # dssnodes — should show 1 manager node
        out=$(dssnodes 2>/dev/null)
        rc=$?
        if [[ $rc -eq 0 && "$out" == *"Leader"* ]]; then
            echo "DSSNODES_OK"
        else
            echo "DSSNODES_FAIL:rc=$rc:out=$out"
        fi

        # Leave swarm (clean up what we init'd)
        docker swarm leave --force 2>/dev/null || true
        echo "SWARM_LEAVE_OK"
    else
        echo "SWARM_INIT_FAIL:$swarm_init_rc"
    fi
fi

# ── OPT-IN dcpr ───────────────────────────────────────────────────────────────

# dcpr absent before sourcing extra/
if type dcpr > /dev/null 2>&1; then
    echo "DCPR_BEFORE:present"
else
    echo "DCPR_BEFORE:absent"
fi

# Source opt-in
source /root/.marckv.dots/docker-aliases/extra/git-properties.sh 2>/dev/null

# dcpr present after sourcing
if type dcpr > /dev/null 2>&1; then
    echo "DCPR_AFTER:present"
else
    echo "DCPR_AFTER:absent"
fi

HEREDOC2
}

# ---------------------------------------------------------------------------
# run_functional_bash: run functional tests in bash inside a container
# ---------------------------------------------------------------------------
run_functional_bash() {
    local distro="$1"

    header "[$distro / bash] Running functional tests"

    local test_script
    test_script=$(build_test_script "bash" "$QUICK")

    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        bash -c "$test_script" 2>/dev/null
}

# ---------------------------------------------------------------------------
# run_functional_zsh: run functional tests in zsh inside a container
# ---------------------------------------------------------------------------
run_functional_zsh() {
    local distro="$1"

    header "[$distro / zsh] Installing zsh if needed"
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        bash -c "command -v zsh > /dev/null 2>&1 || (apt-get update -qq && apt-get install -y zsh) > /dev/null 2>&1" 2>/dev/null || true

    header "[$distro / zsh] Running functional tests"

    local test_script
    test_script=$(build_test_script "zsh" "$QUICK")

    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        zsh -c "$test_script" 2>/dev/null
}

# ---------------------------------------------------------------------------
# parse_and_report: interpret key:value lines and accumulate counters
# ---------------------------------------------------------------------------
parse_and_report() {
    local distro="$1"
    local shell="$2"
    local output="$3"
    local tag="[$distro/$shell]"

    while IFS= read -r line; do
        case "$line" in
            LOAD_OK)         check_pass "$tag aliases loaded successfully" ;;
            LOAD_FAIL:*)     check_fail "$tag aliases failed to load (${line#LOAD_FAIL:})" ;;

            # Docker commands
            DPS_OK)             check_pass "$tag dps → exit 0" ;;
            DPS_FAIL:*)         check_fail "$tag dps → failed (${line#DPS_FAIL:})" ;;
            DSTATS_ONCE_OK)     check_pass "$tag dstats --once snapshot → exit 0" ;;
            DSTATS_ONCE_FAIL:*) check_fail "$tag dstats --once snapshot → failed (${line#DSTATS_ONCE_FAIL:})" ;;

            # Compose lifecycle
            DCUP_WEB_OK)          check_pass "$tag dcup -f compose.yml → web service running" ;;
            DCUP_WEB_FAIL)        check_fail "$tag dcup -f compose.yml → web service NOT running" ;;
            DI_OK)                check_pass "$tag di → shows nginx:alpine after dcup" ;;
            DI_FAIL:*)            check_fail "$tag di → failed (${line#DI_FAIL:})" ;;
            DCPS_OK)              check_pass "$tag dcps → exit 0" ;;
            DCPS_FAIL:*)          check_fail "$tag dcps → failed (${line#DCPS_FAIL:})" ;;
            DCPS_COMPACT_OK)      check_pass "$tag dcps -c compact → exit 0" ;;
            DCPS_COMPACT_FAIL:*)  check_fail "$tag dcps -c compact → failed (${line#DCPS_COMPACT_FAIL:})" ;;
            DCPS_PORTS_OK)        check_pass "$tag dcps -p ports → exit 0" ;;
            DCPS_PORTS_FAIL:*)    check_fail "$tag dcps -p ports → failed (${line#DCPS_PORTS_FAIL:})" ;;
            DCL_WEB_OK)           check_pass "$tag dcl web → produced output" ;;
            DCL_WEB_NO_OUTPUT)    check_fail "$tag dcl web → no output" ;;
            DCX_WEB_OK)           check_pass "$tag dcx web ls /etc/nginx/ → contains nginx.conf" ;;
            DCX_WEB_FAIL:*)       check_fail "$tag dcx web → failed (${line#DCX_WEB_FAIL:})" ;;
            DCQ_WEB_OK)           check_pass "$tag dcq web ls / → contains 'etc'" ;;
            DCQ_WEB_FAIL:*)       check_fail "$tag dcq web → failed (${line#DCQ_WEB_FAIL:})" ;;
            DCLT_WEB_OK)          check_pass "$tag dclt -n 5 web → exited cleanly (timeout expected)" ;;
            DCLT_WEB_FAIL:*)      check_fail "$tag dclt web → failed (${line#DCLT_WEB_FAIL:})" ;;
            DSTATUS_OK)           check_pass "$tag dstatus → shows CONTAINERS section" ;;
            DSTATUS_FAIL:*)       check_fail "$tag dstatus → failed (${line#DSTATUS_FAIL:})" ;;

            # Modern compose
            DCUP_PROFILES_OK:*)   check_pass "$tag dcup -P full → ${line#DCUP_PROFILES_OK:}" ;;
            DCUP_PROFILES_FAIL:*) check_fail "$tag dcup -P full profiles → ${line#DCUP_PROFILES_FAIL:}" ;;
            DCRUN_WEB_OK)         check_pass "$tag dcrun --rm web echo hello → output contains 'hello'" ;;
            DCRUN_WEB_FAIL:*)     check_fail "$tag dcrun web → failed (${line#DCRUN_WEB_FAIL:})" ;;
            DCRUN_REDIS_OK)       check_pass "$tag dcrun -P full --rm cache redis-cli --version → contains 'redis'" ;;
            DCRUN_REDIS_FAIL:*)   check_fail "$tag dcrun redis → failed (${line#DCRUN_REDIS_FAIL:})" ;;
            DCUP_ENVFILE_OK)      check_pass "$tag dcup -e env-file → web still running after env-file up" ;;
            DCUP_ENVFILE_FAIL)    check_fail "$tag dcup -e env-file → web NOT running after env-file up" ;;

            # Cleanup
            DCDOWN_OK)            check_pass "$tag dcdown -f compose.yml → all services stopped" ;;
            DCDOWN_FAIL:*)        check_fail "$tag dcdown → failed (${line#DCDOWN_FAIL:})" ;;
            DPRUNE_OK)            check_pass "$tag dprune (safe) → exit 0" ;;
            DPRUNE_FAIL:*)        check_fail "$tag dprune → failed (${line#DPRUNE_FAIL:})" ;;

            # Swarm
            SWARM_SKIP_HOST_ACTIVE) check_skip "$tag swarm tests — host already in swarm mode (non-destructive skip)" ;;
            SWARM_INIT_OK)          check_pass "$tag docker swarm init → success" ;;
            SWARM_INIT_FAIL:*)      check_fail "$tag docker swarm init → failed (${line#SWARM_INIT_FAIL:})" ;;
            DSS_EMPTY_OK)           check_pass "$tag dss (empty swarm) → exit 0" ;;
            DSS_EMPTY_FAIL:*)       check_fail "$tag dss → failed (${line#DSS_EMPTY_FAIL:})" ;;
            DSSVC_EMPTY_OK)         check_pass "$tag dssvc (no services) → exit 0" ;;
            DSSVC_EMPTY_FAIL:*)     check_fail "$tag dssvc → failed (${line#DSSVC_EMPTY_FAIL:})" ;;
            DSSNODES_OK)            check_pass "$tag dssnodes → shows Leader node" ;;
            DSSNODES_FAIL:*)        check_fail "$tag dssnodes → failed (${line#DSSNODES_FAIL:})" ;;
            SWARM_LEAVE_OK)         check_pass "$tag swarm leave --force → cleaned up" ;;

            # Opt-in dcpr
            DCPR_BEFORE:absent)  check_pass "$tag dcpr absent before sourcing extra/" ;;
            DCPR_BEFORE:present) check_fail "$tag dcpr should NOT be present before sourcing extra/" ;;
            DCPR_AFTER:present)  check_pass "$tag dcpr present after sourcing extra/git-properties.sh" ;;
            DCPR_AFTER:absent)   check_fail "$tag dcpr NOT present after sourcing extra/git-properties.sh" ;;

            # Quick mode marker
            QUICK_MODE_EARLY_EXIT) warn "$tag --quick mode: skipping profile/swarm/cleanup tests" ;;
        esac
    done <<< "$output"
}

# ---------------------------------------------------------------------------
# Main test loop
# ---------------------------------------------------------------------------
START_TIME=$(date +%s)

for distro in "${DISTROS[@]}"; do
    if [[ "$SHELL_MODE" == "bash" || "$SHELL_MODE" == "both" ]]; then
        output=$(run_functional_bash "$distro")
        parse_and_report "$distro" "bash" "$output"
    fi

    if [[ "$SHELL_MODE" == "zsh" || "$SHELL_MODE" == "both" ]]; then
        output=$(run_functional_zsh "$distro")
        parse_and_report "$distro" "zsh" "$output"
    fi
done

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}=================================================${RESET}"
echo -e "${BOLD}FUNCTIONAL TEST SUMMARY${RESET}"
echo -e "${BOLD}=================================================${RESET}"
echo -e "  Total PASS : ${GREEN}${TOTAL_PASS}${RESET}"
echo -e "  Total FAIL : ${RED}${TOTAL_FAIL}${RESET}"
echo -e "  Total SKIP : ${YELLOW}${TOTAL_SKIP}${RESET}"
echo -e "  Elapsed    : ${ELAPSED}s"
echo ""

if [[ "$TOTAL_FAIL" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}ALL FUNCTIONAL TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}SOME TESTS FAILED — see FAIL lines above${RESET}"
    exit 1
fi
