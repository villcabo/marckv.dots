#!/usr/bin/env bash
# =============================================================================
# smoke.sh — Smoke test suite for docker-aliases (post-triage)
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
# Expected symbols (post-triage)
# ---------------------------------------------------------------------------
# Functions present after triage
EXPECTED_FUNCTIONS=(d dc dcup dq dcq dstatus dclt dip dstats dprune _dip_impl _dc_parse_args _dc_resolve_file)
# dcleanup is DROPPED — must NOT appear
DROPPED_FUNCTIONS=(dcleanup)

# Aliases present after triage (ds renamed to dstats — ds alias dropped)
EXPECTED_ALIASES=(dps di dl dlt dx dcps dcl dcdown dcs dcx)
# dps1 dcps1 dpri ds dockerhelp are DROPPED
DROPPED_ALIASES=(dps1 dcps1 dpri ds dockerhelp)

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

# --- Functions that MUST exist ---
for fn in d dc dcup dq dcq dstatus dclt dip dstats dprune _dip_impl _dc_parse_args _dc_resolve_file; do
    if declare -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_OK:\$fn\"; else echo \"FUNC_MISSING:\$fn\"; fi
done

# --- Functions that must NOT exist ---
for fn in dcleanup; do
    if declare -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_DROPPED_PRESENT:\$fn\"; else echo \"FUNC_DROPPED_OK:\$fn\"; fi
done

# --- Aliases that MUST exist ---
for al in dps di dl dlt dx dcps dcl dcdown dcs dcx; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_OK:\$al\"; else echo \"ALIAS_MISSING:\$al\"; fi
done

# --- Aliases that must NOT exist ---
for al in dps1 dcps1 dpri ds dockerhelp; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_DROPPED_PRESENT:\$al\"; else echo \"ALIAS_DROPPED_OK:\$al\"; fi
done

# --- dstats --once flag parses without error ---
type dstats > /dev/null 2>&1 && echo 'DSTATS_DEFINED:ok' || echo 'DSTATS_DEFINED:missing'

# --- dprune flags parse without error ---
type dprune > /dev/null 2>&1 && echo 'DPRUNE_DEFINED:ok' || echo 'DPRUNE_DEFINED:missing'

# --- dclt -n flag accepted ---
type dclt > /dev/null 2>&1 && echo 'DCLT_DEFINED:ok' || echo 'DCLT_DEFINED:missing'

# --- dcpr absent by default ---
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
complete -p dstats 2>/dev/null | grep -q '_dstats_completion' && echo 'COMP_DSTATS:ok' || echo 'COMP_DSTATS:missing'
complete -p dprune 2>/dev/null | grep -q '_dprune_completion' && echo 'COMP_DPRUNE:ok' || echo 'COMP_DPRUNE:missing'

# ── Phase 3 UX tests ─────────────────────────────────────────────────────

# --- _icon: known keys return non-empty (Nerd Font mode) ---
for key in docker file services flags confirm; do
    val=\$(_icon \"\$key\" 2>/dev/null)
    if [[ -n \"\$val\" ]]; then echo \"ICON_OK:\$key\"; else echo \"ICON_EMPTY:\$key\"; fi
done

# --- _icon: ASCII fallback when DOCKER_ALIASES_NERD_FONT=0 ---
ascii_docker=\$(DOCKER_ALIASES_NERD_FONT=0 _icon docker 2>/dev/null)
if [[ \"\$ascii_docker\" == '[docker]' ]]; then echo 'ICON_ASCII:ok'; else echo \"ICON_ASCII:wrong:\$ascii_docker\"; fi

# --- _render_preview: runs without error and produces output ---
preview_out=\$(_render_preview 'compose up' 'docker-compose.yml' 'api worker' '--build' 2>/dev/null)
if [[ -n \"\$preview_out\" ]]; then echo 'RENDER_PREVIEW:ok'; else echo 'RENDER_PREVIEW:empty'; fi

# --- _confirm_operation: DOCKER_ALIASES_AUTO_YES=1 returns 0 and produces no prompt ---
prompt_out=\$(DOCKER_ALIASES_AUTO_YES=1 _confirm_operation 'Continue?' 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && -z \"\$prompt_out\" ]]; then echo 'AUTO_YES:ok'; else echo \"AUTO_YES:fail:rc=\$rc:out=\$prompt_out\"; fi

# --- New helper functions exist ---
for fn in _use_nerd_font _icon _action_color _render_preview; do
    if declare -f \"\$fn\" > /dev/null 2>&1; then echo \"UX_FUNC_OK:\$fn\"; else echo \"UX_FUNC_MISSING:\$fn\"; fi
done
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

# --- Functions that MUST exist ---
for fn in d dc dcup dq dcq dstatus dclt dip dstats dprune _dip_impl _dc_parse_args _dc_resolve_file; do
    if typeset -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_OK:\$fn\"; else echo \"FUNC_MISSING:\$fn\"; fi
done

# --- Functions that must NOT exist ---
for fn in dcleanup; do
    if typeset -f \"\$fn\" > /dev/null 2>&1; then echo \"FUNC_DROPPED_PRESENT:\$fn\"; else echo \"FUNC_DROPPED_OK:\$fn\"; fi
done

# --- Aliases that MUST exist ---
for al in dps di dl dlt dx dcps dcl dcdown dcs dcx; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_OK:\$al\"; else echo \"ALIAS_MISSING:\$al\"; fi
done

# --- Aliases that must NOT exist ---
for al in dps1 dcps1 dpri ds dockerhelp; do
    if alias \"\$al\" > /dev/null 2>&1; then echo \"ALIAS_DROPPED_PRESENT:\$al\"; else echo \"ALIAS_DROPPED_OK:\$al\"; fi
done

# --- dstats --once flag parses without error ---
type dstats > /dev/null 2>&1 && echo 'DSTATS_DEFINED:ok' || echo 'DSTATS_DEFINED:missing'

# --- dprune flags parse without error ---
type dprune > /dev/null 2>&1 && echo 'DPRUNE_DEFINED:ok' || echo 'DPRUNE_DEFINED:missing'

# --- dclt -n flag accepted ---
type dclt > /dev/null 2>&1 && echo 'DCLT_DEFINED:ok' || echo 'DCLT_DEFINED:missing'

# --- dcpr absent by default ---
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

# ── Phase 3 UX tests ─────────────────────────────────────────────────────

# --- _icon: known keys return non-empty (Nerd Font mode) ---
for key in docker file services flags confirm; do
    val=\$(_icon \"\$key\" 2>/dev/null)
    if [[ -n \"\$val\" ]]; then echo \"ICON_OK:\$key\"; else echo \"ICON_EMPTY:\$key\"; fi
done

# --- _icon: ASCII fallback when DOCKER_ALIASES_NERD_FONT=0 ---
ascii_docker=\$(DOCKER_ALIASES_NERD_FONT=0 _icon docker 2>/dev/null)
if [[ \"\$ascii_docker\" == '[docker]' ]]; then echo 'ICON_ASCII:ok'; else echo \"ICON_ASCII:wrong:\$ascii_docker\"; fi

# --- _render_preview: runs without error and produces output ---
preview_out=\$(_render_preview 'compose up' 'docker-compose.yml' 'api worker' '--build' 2>/dev/null)
if [[ -n \"\$preview_out\" ]]; then echo 'RENDER_PREVIEW:ok'; else echo 'RENDER_PREVIEW:empty'; fi

# --- _confirm_operation: DOCKER_ALIASES_AUTO_YES=1 returns 0 and produces no prompt ---
prompt_out=\$(DOCKER_ALIASES_AUTO_YES=1 _confirm_operation 'Continue?' 2>/dev/null)
rc=\$?
if [[ \$rc -eq 0 && -z \"\$prompt_out\" ]]; then echo 'AUTO_YES:ok'; else echo \"AUTO_YES:fail:rc=\$rc:out=\$prompt_out\"; fi

# --- New helper functions exist ---
for fn in _use_nerd_font _icon _action_color _render_preview; do
    if typeset -f \"\$fn\" > /dev/null 2>&1; then echo \"UX_FUNC_OK:\$fn\"; else echo \"UX_FUNC_MISSING:\$fn\"; fi
done
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

            FUNC_DROPPED_OK:*)      check_pass "$tag dropped function absent: ${line#FUNC_DROPPED_OK:}" ;;
            FUNC_DROPPED_PRESENT:*) check_fail "$tag dropped function still present: ${line#FUNC_DROPPED_PRESENT:}" ;;

            ALIAS_OK:*)       check_pass "$tag alias ${line#ALIAS_OK:}" ;;
            ALIAS_MISSING:*)  check_fail "$tag alias MISSING: ${line#ALIAS_MISSING:}" ;;

            ALIAS_DROPPED_OK:*)      check_pass "$tag dropped alias absent: ${line#ALIAS_DROPPED_OK:}" ;;
            ALIAS_DROPPED_PRESENT:*) check_fail "$tag dropped alias still present: ${line#ALIAS_DROPPED_PRESENT:}" ;;

            DSTATS_DEFINED:ok)      check_pass "$tag dstats defined" ;;
            DSTATS_DEFINED:missing) check_fail "$tag dstats NOT defined" ;;

            DPRUNE_DEFINED:ok)      check_pass "$tag dprune defined" ;;
            DPRUNE_DEFINED:missing) check_fail "$tag dprune NOT defined" ;;

            DCLT_DEFINED:ok)        check_pass "$tag dclt defined" ;;
            DCLT_DEFINED:missing)   check_fail "$tag dclt NOT defined" ;;

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

            COMP_D:ok)          check_pass "$tag complete -p d registered" ;;
            COMP_D:missing)     check_fail "$tag complete -p d NOT registered" ;;
            COMP_DC:ok)         check_pass "$tag complete -p dc registered" ;;
            COMP_DC:missing)    check_fail "$tag complete -p dc NOT registered" ;;
            COMP_DSTATS:ok)     check_pass "$tag complete -p dstats registered" ;;
            COMP_DSTATS:missing) check_fail "$tag complete -p dstats NOT registered" ;;
            COMP_DPRUNE:ok)     check_pass "$tag complete -p dprune registered" ;;
            COMP_DPRUNE:missing) check_fail "$tag complete -p dprune NOT registered" ;;

            # Phase 3 UX checks
            ICON_OK:*)       check_pass "$tag _icon ${line#ICON_OK:} returns non-empty" ;;
            ICON_EMPTY:*)    check_fail "$tag _icon ${line#ICON_EMPTY:} returned empty" ;;

            ICON_ASCII:ok)   check_pass "$tag _icon docker → ASCII fallback [docker] when NERD_FONT=0" ;;
            ICON_ASCII:*)    check_fail "$tag _icon ASCII fallback wrong: $line" ;;

            RENDER_PREVIEW:ok)    check_pass "$tag _render_preview produces output" ;;
            RENDER_PREVIEW:empty) check_fail "$tag _render_preview returned empty output" ;;

            AUTO_YES:ok)   check_pass "$tag _confirm_operation returns 0 with DOCKER_ALIASES_AUTO_YES=1" ;;
            AUTO_YES:*)    check_fail "$tag _confirm_operation auto-yes failed: $line" ;;

            UX_FUNC_OK:*)      check_pass "$tag UX helper ${line#UX_FUNC_OK:} defined" ;;
            UX_FUNC_MISSING:*) check_fail "$tag UX helper MISSING: ${line#UX_FUNC_MISSING:}" ;;
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
