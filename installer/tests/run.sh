#!/usr/bin/env bash
# Run the installer scenarios across the distro containers.
#
#   ./run.sh                 every distro, both cases
#   ./run.sh debian11        just one distro
#
# Uses the repo-root docker-compose.yml, which mounts the repo read-only at
# /root/.marckv.dots. The scenarios write to /opt and /etc/profile.d, which is
# exactly why they run in a container and never on the host.
set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/../.." && pwd)"
CASES="install-nvim.test.sh lifecycle.test.sh"

ALL="debian11 debian12 debian13 ubuntu20 ubuntu22 ubuntu24"
TARGETS="${*:-$ALL}"

cd "$REPO_DIR"
docker compose up -d $TARGETS >/dev/null 2>&1

failed=0
for distro in $TARGETS; do
    for case in $CASES; do
        docker cp "${TESTS_DIR}/${case}" "marckv-${distro}:/tmp/${case}" >/dev/null
    done
    # tmux is a dependency of one scenario, not the thing under test. Installed
    # best-effort: lifecycle.test.sh says "skipped" rather than failing without it.
    docker compose exec -T "$distro" bash -c \
        'command -v tmux >/dev/null || { apt-get update -qq && apt-get install -y -qq tmux; } >/dev/null 2>&1' || true
    # Each distro starts from nothing: a leftover /opt/nvim from a previous run
    # would make S1 measure a repair instead of a fresh install.
    docker compose exec -T "$distro" bash -c "
        rm -rf /opt/nvim /opt/nvim.prev /opt/.nvim-stage.* /etc/profile.d/nvim.sh /tmp/nvim-*.tar.gz
        rc=0
        for case in $CASES; do bash /tmp/\$case || rc=1; done
        exit \$rc
    " || failed=1
done

echo ""
if [ "$failed" -eq 0 ]; then
    printf '\033[1;32mall scenarios passed\033[0m\n'
else
    printf '\033[1;31msome scenarios failed\033[0m\n'
fi
exit "$failed"
