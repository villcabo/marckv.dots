#!/usr/bin/env bash
# Run the installer scenarios across the distro containers.
#
#   ./run.sh                 every distro
#   ./run.sh debian11        just one
#
# Uses the repo-root docker-compose.yml, which mounts the repo read-only at
# /root/.marckv.dots. The scenarios write to /opt and /etc/profile.d, which is
# exactly why they run in a container and never on the host.
set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/../.." && pwd)"
CASE="${TESTS_DIR}/install-nvim.test.sh"

ALL="debian11 debian12 debian13 ubuntu20 ubuntu22 ubuntu24"
TARGETS="${*:-$ALL}"

cd "$REPO_DIR"
docker compose up -d $TARGETS >/dev/null 2>&1

failed=0
for distro in $TARGETS; do
    docker cp "$CASE" "marckv-${distro}:/tmp/install-nvim.test.sh" >/dev/null
    # Each distro starts from nothing: a leftover /opt/nvim from a previous run
    # would make S1 measure a repair instead of a fresh install.
    docker compose exec -T "$distro" bash -c '
        rm -rf /opt/nvim /opt/nvim.prev /opt/.nvim-stage.* /etc/profile.d/nvim.sh /tmp/nvim-*.tar.gz
        bash /tmp/install-nvim.test.sh
    ' || failed=1
done

echo ""
if [ "$failed" -eq 0 ]; then
    printf '\033[1;32mall scenarios passed\033[0m\n'
else
    printf '\033[1;31msome scenarios failed\033[0m\n'
fi
exit "$failed"
