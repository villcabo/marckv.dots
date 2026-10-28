#!/bin/bash
# Scenarios for the contract every installer shares. Runs INSIDE a container.
#
# Driven by ../tests/run.sh. It exists because lib/common.sh made a promise —
# every script previews, takes -y, takes -h, rejects what it does not know, and
# never hangs waiting for an answer nobody can give — and a promise nothing
# checks is a comment.
#
# It does not test what each installer installs. install-nvim.test.sh does that
# for the one case where the distro decides the outcome. This one tests the
# shape: the same flags, the same exit codes, from all of them.

INSTALLER_DIR=/root/.marckv.dots/installer
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "$2" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }

# The numbered installers plus the gradle helper: these own install/status/uninstall.
LIFECYCLE="01-install-bash 02-install-docker-aliases 03-install-tmux 04-install-nvim-lite 05-install-atuin install-bash-extensions-gradle-functions"
# These two are helpers with their own flags — same base contract, no three verbs.
HELPERS="clean-nvim-data install-nvim"
# The one-shot installer. Same --help and unknown-flag contract, but kept out of
# S3 and S4: with no terminal it runs the WHOLE setup — apt, a Neovim download,
# every plugin — which is not a hang but does outlast S3's two minutes. S6 runs
# it end to end instead, with a timeout sized for that.
ONESHOT="install"
ALL="$LIFECYCLE $HELPERS $ONESHOT"

printf '\n=== %s ===\n' "$(. /etc/os-release; echo "$PRETTY_NAME")"

# --- S1: -h is understood by every one of them ------------------------------
printf '\nS1  every installer answers --help\n'
for s in $ALL; do
    out=$("$INSTALLER_DIR/$s.sh" --help 2>&1)
    rc=$?
    if [ $rc -eq 0 ] && [ -n "$out" ]; then
        ok "$s"
    else
        bad "$s" "rc=$rc, $(echo "$out" | head -1)"
    fi
done

# --- S2: an unknown flag is refused, and refused the same way ---------------
#
# rc=1 and not 0: a caller that typos a flag must not be told the install went
# fine. This is the half a hand-written parser gets wrong most often.
printf '\nS2  an unknown flag exits 1\n'
for s in $ALL; do
    "$INSTALLER_DIR/$s.sh" --definitely-not-a-flag >/dev/null 2>&1
    rc=$?
    [ $rc -eq 1 ] && ok "$s" || bad "$s" "rc=$rc (expected 1)"
done

# --- S3: nothing hangs when there is nobody to answer -----------------------
#
# The regression this catches is real and was silent: under `set -e` a `read`
# with no terminal killed install-nvim.sh at the prompt — rc=1, no message,
# after printing the preview. `ssh host ./install-nvim.sh` looked like a crash.
# A hang would be worse, so the timeout is part of the assertion.
printf '\nS3  no installer hangs on a closed stdin\n'
for s in $LIFECYCLE $HELPERS; do
    timeout 120 "$INSTALLER_DIR/$s.sh" </dev/null >/dev/null 2>&1
    rc=$?
    [ $rc -eq 124 ] && bad "$s" "timed out — it is waiting for input" || ok "$s (rc=$rc)"
done

# --- S4: the full lifecycle, for the scripts that claim one -----------------
printf '\nS4  install -> status -> uninstall\n'
for s in $LIFECYCLE; do
    trouble=""
    for phase in install status uninstall; do
        "$INSTALLER_DIR/$s.sh" "$phase" -y >/tmp/lc.$s.$phase.log 2>&1 \
            || trouble="$trouble $phase(rc=$?)"
    done
    # One log at a time: `tail -2 /tmp/lc.$s.*.log` across several files makes
    # tail print headers and then reject the option ("used in invalid context"),
    # so the failure arrived with an empty explanation.
    if [ -z "$trouble" ]; then
        ok "$s"
    else
        first_bad="${trouble%%(*}"; first_bad="${first_bad# }"
        bad "$s" "failed:$trouble — $(tail -1 "/tmp/lc.$s.$first_bad.log" 2>/dev/null)"
    fi
done

# --- S5: -y is the only way to say yes to a delete --------------------------
#
# The asymmetry is deliberate. confirm() assumes yes with no terminal, because
# a symlink it puts down has an uninstall. confirm_destructive() does not,
# because `./clean-nvim-data.sh < /dev/null` has no undo. Exit 2, not 1, so a
# caller can tell "you declined" from "I could not ask".
printf '\nS5  a delete refuses to happen unattended\n'
rm -rf ~/.local/share/nvim && mkdir -p ~/.local/share/nvim/lazy
"$INSTALLER_DIR/clean-nvim-data.sh" </dev/null >/dev/null 2>&1
rc=$?
[ $rc -eq 2 ] && ok "exits 2 with no terminal and no -y" || bad "exits 2" "rc=$rc"
[ -d ~/.local/share/nvim ] && ok "the data is still there" || bad "the data is still there" "it was deleted"
"$INSTALLER_DIR/clean-nvim-data.sh" -y </dev/null >/dev/null 2>&1
[ ! -d ~/.local/share/nvim ] && ok "-y does delete it" || bad "-y does delete it" "still present"

# --- S6: the one-shot installer, end to end ----------------------------------
#
# What it replaces is eight commands and two hand-typed `source` lines, so the
# assertions are the ones a person would make afterwards — in a NEW login
# shell, because "nvim is on PATH" inside the installer's own process proves
# nothing about the next terminal. The run itself has no terminal and no -y:
# that is the closed-stdin contract, and also how it runs over ssh.
printf '\nS6  install.sh runs the whole setup, and undoes it\n'
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ~/.tmux ~/.tmux.conf
"$INSTALLER_DIR/install.sh" uninstall -y </dev/null >/dev/null 2>&1 || true
# The PATH a real server starts with. These images bake /opt/nvim/bin into
# ENV PATH (the root Dockerfile preinstalls Neovim there), which hid the bug
# this run exists to catch: a Neovim just installed into /opt is NOT on the
# PATH of the process that installed it. Measured: with the image's PATH the
# check below passed even with the fix removed.
timeout 1500 env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$INSTALLER_DIR/install.sh" </dev/null >/tmp/os.install.log 2>&1
rc=$?
if [ $rc -eq 0 ]; then ok "install, unattended (rc=0)"
else bad "install, unattended" "rc=$rc — $(grep -E 'ERROR|Stopped' /tmp/os.install.log | head -2 | tr '\n' ' ')"; fi

grep -Fq '.marckv.dots/bash/.bashrc' ~/.bashrc \
    && ok "bash: ~/.bashrc loads the repo config" || bad "bash: ~/.bashrc loads the repo config"
grep -Fq 'docker-aliases/init.sh' ~/.bash_aliases 2>/dev/null \
    && ok "docker: ~/.bash_aliases loads the aliases" || bad "docker: ~/.bash_aliases loads the aliases"
[ -L ~/.tmux.conf ] && ok "tmux: ~/.tmux.conf is linked" || bad "tmux: ~/.tmux.conf is linked"
[ -L ~/.config/nvim ] && ok "nvim: ~/.config/nvim is linked" || bad "nvim: ~/.config/nvim is linked"

# A new login shell, which reads /etc/profile.d — what the next terminal sees.
v=$(bash -lc 'nvim --version 2>/dev/null | head -1')
[ -n "$v" ] && ok "nvim: a new login shell runs it ($v)" || bad "nvim: a new login shell runs it" "nvim not on PATH"
# And the bash config actually loads there: a function only bash/ defines.
bash -ic 'declare -F mkcd >/dev/null' </dev/null >/dev/null 2>&1 \
    && ok "bash: a new interactive shell has the repo's functions" \
    || bad "bash: a new interactive shell has the repo's functions"
n=$(ls ~/.local/share/nvim/lazy 2>/dev/null | wc -l)
[ "$n" -gt 0 ] && ok "nvim: plugins synced ($n in lazy/)" || bad "nvim: plugins synced" "lazy/ is empty"
grep -q 'Neovim is not installed' /tmp/os.install.log \
    && bad "nvim: the config step found the Neovim just installed" "the PATH bug is back" \
    || ok "nvim: the config step found the Neovim just installed"

"$INSTALLER_DIR/install.sh" status >/tmp/os.status.log 2>&1 \
    && ok "status (rc=0)" || bad "status" "rc=$? — $(tail -1 /tmp/os.status.log)"

"$INSTALLER_DIR/install.sh" uninstall </dev/null >/dev/null 2>&1
rc=$?
[ $rc -eq 2 ] && ok "uninstall refuses a pipe (rc=2)" || bad "uninstall refuses a pipe" "rc=$rc (expected 2)"
[ -L ~/.config/nvim ] && [ -d ~/.local/share/nvim/lazy ] \
    && ok "...and nothing was removed" || bad "...and nothing was removed" "it deleted anyway"

"$INSTALLER_DIR/install.sh" uninstall -y </dev/null >/tmp/os.uninstall.log 2>&1 \
    && ok "uninstall -y (rc=0)" || bad "uninstall -y" "rc=$? — $(tail -1 /tmp/os.uninstall.log)"
grep -Fq '.marckv.dots/bash/.bashrc' ~/.bashrc && bad "uninstall removed the bash line" || ok "uninstall removed the bash line"
[ ! -e ~/.config/nvim ] && [ ! -e ~/.tmux.conf ] \
    && ok "uninstall removed the nvim and tmux links" || bad "uninstall removed the nvim and tmux links"
bash -lc 'nvim --version' >/dev/null 2>&1 \
    && ok "uninstall kept the Neovim binary" || bad "uninstall kept the Neovim binary"

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$VERSION_ID")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
