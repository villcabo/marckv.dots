#!/usr/bin/env bash
# Run the vim-lite scenarios across the distro containers, concurrently.
#
#   ./run.sh                 every distro
#   ./run.sh debian11        just one — Vim 8.2, no live pickers
#
# Uses the repo-root docker-compose.yml, which mounts the repo read-only at
# /root/.marckv.dots. The scenarios install packages with apt and write to the
# container's home, so they never run on the host. Output is buffered per
# distro and printed whole, in order.
set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/../.." && pwd)"
CASE="vim-lite.test.sh"

ALL="debian10 debian11 debian12 debian13 ubuntu20 ubuntu22 ubuntu24 ubuntu26"
TARGETS="${*:-$ALL}"

cd "$REPO_DIR"
docker compose up -d $TARGETS >/dev/null 2>&1

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
for distro in $TARGETS; do
    (
        docker cp "${TESTS_DIR}/${CASE}" "marckv-${distro}:/tmp/${CASE}" >/dev/null
        rc=0
        docker compose exec -T "$distro" bash "/tmp/${CASE}" </dev/null >"$OUT/$distro" 2>&1 || rc=$?
        echo "$rc" >"$OUT/$distro.rc"
    ) &
done
wait

failed=0
for distro in $TARGETS; do
    cat "$OUT/$distro"
    [ "$(cat "$OUT/$distro.rc")" = 0 ] || failed=1
done

echo
[ $failed -eq 0 ] && echo "all distros passed" || { echo "some scenarios failed"; exit 1; }
