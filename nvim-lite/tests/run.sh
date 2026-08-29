#!/usr/bin/env bash
# Run the nvim-lite treesitter scenarios across the distro containers.
#
#   ./run.sh                 every distro
#   ./run.sh debian11        just one — the GLIBC 2.31 case
#
# Uses the repo-root docker-compose.yml, which mounts the repo read-only at
# /root/.marckv.dots. Each run installs Neovim into /opt and clones the whole
# plugin set, so it is slow and belongs nowhere near the host.
set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/../.." && pwd)"
CASE="${TESTS_DIR}/treesitter.test.sh"

ALL="debian10 debian11 debian12 debian13 ubuntu20 ubuntu22 ubuntu24 ubuntu26"
TARGETS="${*:-$ALL}"

cd "$REPO_DIR"
docker compose up -d $TARGETS >/dev/null 2>&1

failed=0
for distro in $TARGETS; do
    docker cp "$CASE" "marckv-${distro}:/tmp/treesitter.test.sh" >/dev/null
    # From scratch every time: a parser left over from a previous run would
    # make the decisive assertion pass without the config having decided
    # anything.
    # /opt/nvim goes too. A binary left by another suite — install-nvim.sh's
    # own scenarios deliberately install one that cannot run — would otherwise
    # be inherited here and fail this suite for someone else's reason.
    docker compose exec -T "$distro" bash -c '
        rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ~/.config/nvim
        nvim --version >/dev/null 2>&1 || rm -rf /opt/nvim /etc/profile.d/nvim.sh
        # The CLI goes too. It lives outside the Neovim data directory, so it
        # used to survive every "clean" run — and a CLI left over from an
        # earlier run makes this suite pass with the version pin removed,
        # because the deps step finds one already there and installs nothing.
        # Two planted regressions went undetected before this line existed.
        rm -f /usr/local/bin/tree-sitter ~/.local/bin/tree-sitter
        bash /tmp/treesitter.test.sh
    ' || failed=1
done

echo ""
if [ "$failed" -eq 0 ]; then
    printf '\033[1;32mall scenarios passed\033[0m\n'
else
    printf '\033[1;31msome scenarios failed\033[0m\n'
fi
exit "$failed"
