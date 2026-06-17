#!/usr/bin/env bash
# =============================================================================
# smoke.sh — Smoke test suite for docker-aliases restructure
#
# Tests: bash + zsh, ubuntu24 + debian12 containers
# Usage: cd ~/.marckv.dots && ./docker-aliases/tests/smoke.sh [options]
#
# Options:
#   --keep              Skip container cleanup on exit (for debugging)
#   --shell {bash|zsh|both}   Which shell(s) to test (default: both)
#   --distro {ubuntu24|debian12|all}  Which distro(s) to test (default: all)
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

pass() { echo -e "  ${GREEN}PASS${RESET} $1"; }
fail() { echo -e "  ${RED}FAIL${RESET} $1"; }
info() { echo -e "${CYAN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}WARN${RESET} $1"; }
header() { echo -e "\n${BOLD}$1${RESET}"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
KEEP=false
SHELL_MODE="both"
DISTRO_MODE="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep) KEEP=true ;;
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
                ubuntu24|debian12|all) DISTRO_MODE="$1" ;;
                *) echo "Unknown --distro value: $1 (use ubuntu24|debian12|all)" >&2; exit 1 ;;
            esac
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Determine repo root (script lives in docker-aliases/tests/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
cleanup() {
    if [[ "$KEEP" == false ]]; then
        info "Stopping containers..."
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
    ubuntu24) DISTROS=("ubuntu24") ;;
    debian12)  DISTROS=("debian12") ;;
    all)       DISTROS=("ubuntu24" "debian12") ;;
esac

# ---------------------------------------------------------------------------
# Start containers
# ---------------------------------------------------------------------------
header "Starting containers: ${DISTROS[*]}"
docker compose -f "$REPO_ROOT/docker-compose.yml" up -d "${DISTROS[@]}" 2>&1 \
    | grep -E '(Created|Started|Running|error)' || true

# ---------------------------------------------------------------------------
# Global counters
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0

check_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); pass "$1"; }
check_fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); fail "$1"; }

# ---------------------------------------------------------------------------
# Expected symbols
# ---------------------------------------------------------------------------
EXPECTED_FUNCTIONS=(d dc dcup dq dcq dstatus dcleanup dclt dip _dip_impl _dc_parse_args _dc_resolve_file)
EXPECTED_ALIASES=(dps dps1 di dl dlt dpri ds dx dcps dcps1 dcl dcdown dcs dcx)

# ---------------------------------------------------------------------------
# bash_test_script: inline script run inside the container via bash
# ---------------------------------------------------------------------------
bash_test_script() {
    local distro="$1"
    header "[$distro / bash] Sourcing loader"
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        bash -c "
cd /root/.marckv.dots

# --- Source loader ---
source docker-aliases/docker-color_aliases.sh 2>/dev/null
rc=\$?
echo \"SOURCE_EXIT:\$rc\"

# --- Functions ---
for fn in d dc dcup dq dcq dstatus dcleanup dclt dip _dip_impl _dc_parse_args _dc_resolve_file; do
    if declare -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_OK:\$fn\"; else echo \"FUNC_MISSING:\$fn\"; fi
done

# --- Aliases ---
for al in dps dps1 di dl dlt dpri ds dx dcps dcps1 dcl dcdown dcs dcx; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_OK:\$al\"; else echo \"ALIAS_MISSING:\$al\"; fi
done

# --- dcpr absent ---
if type dcpr > /dev/null 2>&1; then echo 'DCPR_DEFAULT:present'; else echo 'DCPR_DEFAULT:absent'; fi

# --- dcpr opt-in ---
source docker-aliases/extra/git-properties.sh
if type dcpr > /dev/null 2>&1; then echo 'DCPR_OPTIN:present'; else echo 'DCPR_OPTIN:absent'; fi

# --- Stub no-ops ---
BEFORE=\$(declare -F | wc -l)
source docker-aliases/compose-modern.sh
AFTER=\$(declare -F | wc -l)
echo \"STUB_MODERN:\$BEFORE:\$AFTER\"

source docker-aliases/swarm.sh
AFTER2=\$(declare -F | wc -l)
echo \"STUB_SWARM:\$BEFORE:\$AFTER2\"

# --- Completions ---
complete -p d  2>/dev/null | grep -q '_d_completion'  && echo 'COMP_D:ok'  || echo 'COMP_D:missing'
complete -p dc 2>/dev/null | grep -q '_dc_completion' && echo 'COMP_DC:ok' || echo 'COMP_DC:missing'
" 2>/dev/null
}

# ---------------------------------------------------------------------------
# zsh_test_script: inline script run inside the container via zsh
# ---------------------------------------------------------------------------
zsh_test_script() {
    local distro="$1"
    header "[$distro / zsh] Installing zsh if needed"
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        bash -c "command -v zsh > /dev/null 2>&1 || (apt-get update -qq && apt-get install -y zsh) > /dev/null 2>&1" 2>/dev/null || true

    header "[$distro / zsh] Sourcing loader"
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec "$distro" \
        zsh -c "
cd /root/.marckv.dots

# --- Source loader ---
source docker-aliases/docker-color_aliases.sh 2>/dev/null
rc=\$?
echo \"SOURCE_EXIT:\$rc\"

# --- Functions ---
for fn in d dc dcup dq dcq dstatus dcleanup dclt dip _dip_impl _dc_parse_args _dc_resolve_file; do
    if typeset -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_OK:\$fn\"; else echo \"FUNC_MISSING:\$fn\"; fi
done

# --- Aliases ---
for al in dps dps1 di dl dlt dpri ds dx dcps dcps1 dcl dcdown dcs dcx; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_OK:\$al\"; else echo \"ALIAS_MISSING:\$al\"; fi
done

# --- dcpr absent ---
type dcpr > /dev/null 2>&1 && echo 'DCPR_DEFAULT:present' || echo 'DCPR_DEFAULT:absent'

# --- dcpr opt-in ---
source docker-aliases/extra/git-properties.sh 2>/dev/null
type dcpr > /dev/null 2>&1 && echo 'DCPR_OPTIN:present' || echo 'DCPR_OPTIN:absent'

# --- Stub no-ops ---
BEFORE=\$(typeset -f | grep '^[a-z_]' | wc -l)
source docker-aliases/compose-modern.sh
AFTER=\$(typeset -f | grep '^[a-z_]' | wc -l)
echo \"STUB_MODERN:\$BEFORE:\$AFTER\"

source docker-aliases/swarm.sh
AFTER2=\$(typeset -f | grep '^[a-z_]' | wc -l)
echo \"STUB_SWARM:\$BEFORE:\$AFTER2\"
" 2>/dev/null
}

# ---------------------------------------------------------------------------
# parse_and_report: interpret key:value lines and accumulate pass/fail
# ---------------------------------------------------------------------------
parse_and_report() {
    local distro="$1"
    local shell="$2"
    local output="$3"
    local tag="[$distro/$shell]"

    while IFS= read -r line; do
        case "$line" in
            SOURCE_EXIT:0)   check_pass "$tag loader source → exit 0" ;;
            SOURCE_EXIT:*)   check_fail "$tag loader source → exit non-0 ($line)" ;;
            FUNC_OK:*)       check_pass "$tag function ${line#FUNC_OK:}" ;;
            FUNC_MISSING:*)  check_fail "$tag function MISSING: ${line#FUNC_MISSING:}" ;;
            ALIAS_OK:*)      check_pass "$tag alias ${line#ALIAS_OK:}" ;;
            ALIAS_MISSING:*) check_fail "$tag alias MISSING: ${line#ALIAS_MISSING:}" ;;
            DCPR_DEFAULT:absent)  check_pass "$tag dcpr absent by default (opt-in only)" ;;
            DCPR_DEFAULT:present) check_fail "$tag dcpr should NOT be defined by default" ;;
            DCPR_OPTIN:present)   check_pass "$tag dcpr available after explicit source" ;;
            DCPR_OPTIN:absent)    check_fail "$tag dcpr NOT available after opt-in source" ;;
            STUB_MODERN:*)
                IFS=':' read -r _ before after <<< "$line"
                if [[ "$before" == "$after" ]]; then
                    check_pass "$tag compose-modern.sh stub: no functions added"
                else
                    check_fail "$tag compose-modern.sh stub: added functions (before=$before after=$after)"
                fi
                ;;
            STUB_SWARM:*)
                IFS=':' read -r _ before after <<< "$line"
                if [[ "$before" == "$after" ]]; then
                    check_pass "$tag swarm.sh stub: no functions added"
                else
                    check_fail "$tag swarm.sh stub: added functions (before=$before after=$after)"
                fi
                ;;
            COMP_D:ok)      check_pass "$tag complete -p d registered" ;;
            COMP_D:missing) check_fail "$tag complete -p d NOT registered" ;;
            COMP_DC:ok)     check_pass "$tag complete -p dc registered" ;;
            COMP_DC:missing) check_fail "$tag complete -p dc NOT registered" ;;
        esac
    done <<< "$output"
}

# ---------------------------------------------------------------------------
# Main test loop
# ---------------------------------------------------------------------------
START_TIME=$(date +%s)

for distro in "${DISTROS[@]}"; do
    if [[ "$SHELL_MODE" == "bash" || "$SHELL_MODE" == "both" ]]; then
        output=$(bash_test_script "$distro")
        parse_and_report "$distro" "bash" "$output"
    fi

    if [[ "$SHELL_MODE" == "zsh" || "$SHELL_MODE" == "both" ]]; then
        output=$(zsh_test_script "$distro")
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
echo -e "${BOLD}SMOKE TEST SUMMARY${RESET}"
echo -e "${BOLD}=================================================${RESET}"
echo -e "  Total PASS : ${GREEN}${TOTAL_PASS}${RESET}"
echo -e "  Total FAIL : ${RED}${TOTAL_FAIL}${RESET}"
echo -e "  Elapsed    : ${ELAPSED}s"
echo ""

if [[ "$TOTAL_FAIL" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}ALL TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}SOME TESTS FAILED — see FAIL lines above${RESET}"
    exit 1
fi
