#!/usr/bin/env bash
# docker-aliases — test runner.
#
#   ./run.sh              every case, in bash and zsh
#   ./run.sh bash         one shell only
#   ./run.sh bash dcup    one shell, one case
#
# bats itself runs in bash, but the code under test has to behave identically
# in bash and zsh — every portability bug this suite has caught lived in that
# gap. So the suite runs once per shell with DA_SHELL naming which one, and a
# failure tells you the shell it happened in.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

C_OK=$'\033[1;32m'; C_BAD=$'\033[1;31m'; C_DIM=$'\033[2m'
C_HEAD=$'\033[1;36m'; C_OFF=$'\033[0m'

command -v bats >/dev/null 2>&1 || {
    printf '%sbats not found%s — install it, or run inside the test images:\n' "$C_BAD" "$C_OFF" >&2
    printf '  docker compose exec ubuntu24 /repo/docker-aliases/tests/run.sh\n' >&2
    exit 127
}

REAL_DOCKER="$(command -v docker || true)"
[[ -z "$REAL_DOCKER" ]] && { printf '%sdocker CLI not found%s\n' "$C_BAD" "$C_OFF" >&2; exit 127; }

# The workspace is built ONCE and shared by every case file: fixtures are
# copied out of the read-only repo mount, and the shimmed docker goes first on
# PATH so nothing here can touch a real container.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -r "${TESTS_DIR}/fixtures" "${WORK}/fixtures"
mkdir -p "${WORK}/fake-project" "${WORK}/other-project"

# shellcheck source=./helpers/shim.bash
source "${TESTS_DIR}/helpers/shim.bash"
_write_shim "$WORK" "$REAL_DOCKER"

export DA_WORK="$WORK"

shells=(bash zsh)
[[ $# -ge 1 ]] && shells=("$1")

cases=("${TESTS_DIR}"/cases/*.bats)
if [[ $# -ge 2 ]]; then
    cases=("${TESTS_DIR}/cases/$2.bats")
    [[ -f "${cases[0]}" ]] || { printf '%sno such case: %s%s\n' "$C_BAD" "$2" "$C_OFF" >&2; exit 1; }
fi

printf '%sdocker-aliases — tests%s\n' "$C_HEAD" "$C_OFF"
printf '%s  host    : %s%s\n' "$C_DIM" "$(uname -s) $(uname -m)" "$C_OFF"
printf '%s  bats    : %s%s\n' "$C_DIM" "$(bats --version)" "$C_OFF"
printf '%s  docker  : %s%s\n' "$C_DIM" "$($REAL_DOCKER --version 2>/dev/null)" "$C_OFF"

failed=0
total=0

for sh in "${shells[@]}"; do
    if ! command -v "$sh" >/dev/null 2>&1; then
        printf '\n%s── %s not installed — skipped%s\n' "$C_BAD" "$sh" "$C_OFF"
        failed=$(( failed + 1 ))
        continue
    fi

    printf '\n%s── %s%s %s(%s)%s\n' \
        "$C_HEAD" "$sh" "$C_OFF" "$C_DIM" "$("$sh" --version 2>&1 | head -1)" "$C_OFF"

    if DA_SHELL="$sh" bats "${cases[@]}"; then
        n=$(DA_SHELL="$sh" bats --count "${cases[@]}" 2>/dev/null || echo 0)
        total=$(( total + n ))
    else
        failed=$(( failed + 1 ))
    fi
done

printf '\n%s────────────────────────%s\n' "$C_DIM" "$C_OFF"
if (( failed == 0 )); then
    printf '%sall %d checks passed%s\n' "$C_OK" "$total" "$C_OFF"
    exit 0
fi
printf '%s%d shell(s) FAILED%s\n' "$C_BAD" "$failed" "$C_OFF"
exit "$failed"
