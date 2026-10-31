#!/usr/bin/env bash
# Run nvim-unpack.sh in a container per distro, each started with
# --network none, concurrently.
#
#   PACK=~/marckv-nvim-v0.12.6.tgz ./run.sh            the five supported distros + Debian 11
#   PACK=… ./run.sh debian12                            one
#
# PACK is built beforehand by installer/offline/nvim-pack.sh; without it the
# run builds one first. The containers come from the repo-root compose images
# and are thrown away (--rm), so nothing they install survives the run.
set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/../../.." && pwd)"

# Debian 11 is not supported: it is here to prove the pack refuses it.
ALL="ubuntu22 ubuntu24 ubuntu26 debian12 debian13 debian11"
TARGETS="${*:-$ALL}"

cd "$REPO_DIR"
docker compose build $TARGETS >/dev/null 2>&1 || true

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
if [ -z "${PACK:-}" ]; then
    "$REPO_DIR/installer/offline/nvim-pack.sh" -o "$OUT" -y
    PACK=$(ls "$OUT"/marckv-nvim-*.tgz)
fi
[ -f "$PACK" ] || { echo "No pack: $PACK" >&2; exit 1; }

# The repo as a host has it after a clone: tracked files and .git, so the
# unpacker can compare nvim-lite against what the pack was built for.
tar -c --exclude=./nvim -C "$REPO_DIR" . > "$OUT/repo.tar"

for distro in $TARGETS; do
    (
        rc=0
        docker run --rm --network none --restart no -e LANG=C.UTF-8 \
            -v "$PACK:/pack/$(basename "$PACK"):ro" \
            -v "$OUT/repo.tar:/repo.tar:ro" \
            -v "$REPO_DIR/nvim-lite/tests/fixtures:/fixtures:ro" \
            -v "$TESTS_DIR/unpack.test.sh:/unpack.test.sh:ro" \
            --entrypoint bash "marckvdots-testings-${distro}" /unpack.test.sh \
            </dev/null >"$OUT/$distro.log" 2>&1 || rc=$?
        echo "$rc" >"$OUT/$distro.rc"
    ) &
done
wait

failed=0
for distro in $TARGETS; do
    cat "$OUT/$distro.log"
    [ "$(cat "$OUT/$distro.rc")" = 0 ] || failed=1
done
echo
[ $failed -eq 0 ] && echo "all distros passed" || { echo "some scenarios failed"; exit 1; }
