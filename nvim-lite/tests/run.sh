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

# The distros run CONCURRENTLY.
#
# Measured on one container: `Lazy! sync` cloning 21 repositories takes 36 s of
# the ~45 s a distro costs, parser compilation 7 s, and the 32-file check 2 s.
# The dominant cost is network latency, which is exactly what overlaps well —
# eight simultaneous clone sets do not contend the way eight compilations would.
#
# The containers share nothing: separate filesystems, separate Neovim data
# directories, no common state. There was never a reason for them to take turns.
#
# The obvious alternative was tried first and was worse: collapsing S7's 32
# Neovim invocations into one session that opens every fixture took 35.7 s
# against 2 s, because `:edit` inside one headless session does not trigger the
# same attach path and nearly every file waits out its timeout. Measure before
# optimising, including — especially — the optimisation that sounds obvious.
#
# Output is buffered per distro and printed whole at the end; eight interleaved
# logs are unreadable. PARALLEL=1 restores the serial run for watching a
# failure live.
PARALLEL="${PARALLEL:-8}"

# Containers are prepared ONCE and reused until the config changes.
#
# Every run used to wipe ~/.local/share/nvim, the state, the cache and the
# tree-sitter CLI, then rebuild from nothing. That was not caution for its own
# sake — leftover state had produced false results twice: a CLI surviving a
# "clean" run made two planted regressions pass, and a broken /opt/nvim
# inherited from another suite failed Ubuntu 20.04 for a reason that had
# nothing to do with what was under test.
#
# But wiping every time costs the whole setup every time, and in a parallel run
# that is the wall: eight `Lazy! sync` runs cloning 21 repositories each,
# competing for one network link. Cutting 100 s of pointless waiting out of the
# assertions saved 13 minutes of WORK and one minute of clock, because the
# clock was never waiting on the assertions.
#
# So the guarantee is kept and the cost is not: a fingerprint of everything
# that determines what gets installed is recorded inside the container. Same
# fingerprint and a working install means reuse; anything else means a full
# rebuild. REBUILD=1 forces one.
fingerprint() {
    {
        cat "$REPO_DIR"/nvim-lite/lua/config/*.lua
        cat "$REPO_DIR"/nvim-lite/lua/plugins/*.lua
        cat "$REPO_DIR"/nvim-lite/init.lua "$REPO_DIR"/nvim-lite/lazyvim.json "$REPO_DIR"/nvim-lite/VERSION
        cat "$REPO_DIR"/installer/04-install-nvim-lite.sh "$REPO_DIR"/installer/install-nvim.sh
    } 2>/dev/null | sha256sum | cut -c1-16
}
FP=$(fingerprint)
STAMP=/root/.nvim-lite-test-fingerprint

# prepare_or_reuse <distro> — echo "reuse" or "rebuild"
prepare_or_reuse() {
    local distro="$1"
    if [ "${REBUILD:-0}" = "1" ]; then
        printf 'rebuild'
        return
    fi
    docker compose exec -T "$distro" sh -c "
        [ \"\$(cat $STAMP 2>/dev/null)\" = '$FP' ] &&
        [ -d ~/.local/share/nvim/lazy ] &&
        PATH=\$PATH:/opt/nvim/bin nvim --version >/dev/null 2>&1
    " >/dev/null 2>&1 && printf 'reuse' || printf 'rebuild'
}

if [ "$PARALLEL" -gt 1 ]; then
    OUTDIR=$(mktemp -d)
    trap 'rm -rf "$OUTDIR"' EXIT

    for distro in $TARGETS; do
        (
            docker cp "$CASE" "marckv-${distro}:/tmp/treesitter.test.sh" >/dev/null 2>&1
            mode=$(prepare_or_reuse "$distro")
            if [ "$mode" = "rebuild" ]; then
                docker compose exec -T "$distro" bash -c "
                    rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ~/.config/nvim
                    nvim --version >/dev/null 2>&1 || rm -rf /opt/nvim /etc/profile.d/nvim.sh
                    rm -f /usr/local/bin/tree-sitter ~/.local/bin/tree-sitter
                    rm -f $STAMP
                " >/dev/null 2>&1
            fi
            docker compose exec -T "$distro" bash -c '
                bash /tmp/treesitter.test.sh
            ' > "$OUTDIR/$distro.log" 2>&1
            rc=$?
            printf '%s' "$rc" > "$OUTDIR/$distro.rc"
            printf '%s' "$mode" > "$OUTDIR/$distro.mode"
            # Only a passing run earns the stamp. A failed one leaves the
            # container unmarked so the next attempt starts clean rather than
            # inheriting whatever state the failure left behind.
            [ "$rc" = "0" ] && docker compose exec -T "$distro" sh -c "printf '%s' '$FP' > $STAMP" >/dev/null 2>&1
        ) &
    done
    wait

    failed=0
    for distro in $TARGETS; do
        cat "$OUTDIR/$distro.log" 2>/dev/null
        printf '       [%s]\n' "$(cat "$OUTDIR/$distro.mode" 2>/dev/null)"
        [ "$(cat "$OUTDIR/$distro.rc" 2>/dev/null)" = "0" ] || failed=1
    done

    echo ""
    if [ "$failed" -eq 0 ]; then
        printf '\033[1;32mall scenarios passed\033[0m\n'
    else
        printf '\033[1;31msome scenarios failed\033[0m\n'
    fi
    printf '\n\033[1mTo see it yourself:\033[0m\n'
    for distro in $TARGETS; do
        printf '  docker compose exec -it marckv-%s nvim /root/.marckv.dots/nvim-lite/tests/fixtures/docker-compose.yml\n' "$distro"
    done
    exit "$failed"
fi

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

# The containers are left as the scenarios left them — Neovim installed, config
# linked, plugins synced — so the result can be looked at rather than trusted.
# Reading "treesitter" in a log is not the same as seeing the file.
echo ""
printf '\033[1mTo see it yourself:\033[0m\n'
for distro in $TARGETS; do
    printf '  docker compose exec -it marckv-%s nvim /root/.marckv.dots/nvim-lite/tests/fixtures/docker-compose.yml\n' "$distro"
done
printf '\n  All the fixtures: \033[33m/root/.marckv.dots/nvim-lite/tests/fixtures/\033[0m\n'
printf '  Inside nvim, :Lazy shows what is installed, :checkhealth nvim-treesitter what parses.\n'

exit "$failed"
