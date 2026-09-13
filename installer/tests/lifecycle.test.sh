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
ALL="$LIFECYCLE $HELPERS"

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
for s in $ALL; do
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

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$VERSION_ID")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
