#!/bin/bash
# install.sh the way a person runs it. Runs INSIDE a container, driven by run.sh.
#
# lifecycle.test.sh S6 covers the unattended run: root, no terminal. That is
# the one shape nobody uses at a desk. This file covers the others — a normal
# user with sudo and a password, answering in a terminal; declining; running it
# a second time; and copy mode — because "it passed as root over a pipe" says
# nothing about the prompt order, the sudo cache, or who ends up owning the
# files in the user's home.
#
# The answers go through script(1), never a pipe: install.sh's confirm() treats
# a non-terminal stdin as a yes, so a piped "n" would silently install.

INSTALLER_DIR=/root/.marckv.dots/installer
REAL_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
USR=tester
PW=pw-for-tests
UHOME=/home/$USR
LOAD_BASH='.marckv.dots/bash/.bashrc'
LOAD_DOCKER='docker-aliases/init.sh'
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "$2" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }

# as_user_tty <seconds> <log> <install.sh args> <answer>... — run install.sh as
# $USR in a pty, feeding one answer per line with a pause before each, so a
# prompt that flushes pending input (sudo may) still gets its answer.
#
# stdin must close exactly when install.sh finishes — not before, not after.
# Both mistakes were made here, and both hang:
#   kept open (a trailing `sleep`): script(1) never exits after its child does.
#     O1 sat 40 minutes after install.sh had already printed "Cancelled".
#   closed early (EOF right after the answers): script(1) spins at 100% CPU
#     and stops relaying the pty, so the install blocks writing to a terminal
#     nobody reads. The log stopped at the sudo prompt while 04 sat in
#     `git clone`, and steps 1-3 never reached it at all.
# So the command drops a marker when it ends, and the feeder holds stdin open
# until it sees it.
#
# The exit code travels in that marker too, not through script(1): with stdin
# still open when its child exits — which the feeder's polling makes the normal
# case — script returns 0 whatever the child returned (measured: `exit 3` came
# back 0). A failed install would have read as a pass. No marker at all means
# install.sh never finished, and that is reported as the timeout it is.
as_user_tty() {
    local limit="$1" log="$2" args="$3"; shift 3
    local done_flag="/tmp/os.done.$$.$RANDOM" feed="" a
    for a in "$@"; do feed="$feed sleep 3; printf '%s\\n' '$a';"; done
    rm -f "$done_flag"
    # Sized per call, never one generous number for all: a hang must fail fast
    # and name its scenario.
    timeout "$limit" su - "$USR" -c "
        cd ~/.marckv.dots/installer &&
        script -qec './install.sh $args; echo \$? > $done_flag' /dev/null \\
            < <($feed while [ ! -e $done_flag ]; do sleep 1; done)
    " >"$log" 2>&1
    local rc=124
    [ -s "$done_flag" ] && rc=$(cat "$done_flag")
    rm -f "$done_flag"
    # A timeout leaves script, install.sh and the feeder running, and they
    # would still be there, half way through, when the next scenario starts.
    [ "$rc" = 124 ] && pkill -9 -u "$USR" 2>/dev/null
    return "$rc"
}

printf '\n=== %s ===\n' "$(. /etc/os-release; echo "$PRETTY_NAME")"

# --- setup: a person with sudo, the repo in their home, no Neovim yet -------
#
# The repo goes to ~/.marckv.dots because 01's load line names that path, as
# every real install does. Neovim is removed so the run has to escalate to put
# it in /opt — the sudo path this file exists to exercise.
# Kill first: userdel refuses a user with live processes — silently here, with
# its output discarded — and a previous run's leftovers then kept running.
pkill -9 -u "$USR" 2>/dev/null; sleep 1
userdel -r "$USR" >/dev/null 2>&1
useradd -m -s /bin/bash "$USR" && echo "$USR:$PW" | chpasswd && usermod -aG sudo "$USR"
cp -a /root/.marckv.dots "$UHOME/.marckv.dots" && chown -R "$USR:$USR" "$UHOME/.marckv.dots"
rm -rf /opt/nvim /opt/nvim.prev /etc/profile.d/nvim.sh /tmp/nvim-*.tar.gz
rm -f /usr/local/bin/tree-sitter

# --- O1: answering no changes nothing ---------------------------------------
printf '\nO1  "n" in a terminal leaves everything as it was\n'
as_user_tty 60 /tmp/os.o1.log "" n
rc=$?
[ $rc -eq 0 ] && ok "exits 0 (rc=$rc)" || bad "exits 0" "rc=$rc$([ $rc -eq 124 ] && echo ' — TIMED OUT: something is waiting on input')"
grep -q 'Cancelled' /tmp/os.o1.log && ok "says it cancelled" || bad "says it cancelled" "$(tail -2 /tmp/os.o1.log | tr -d '\r')"
grep -q 'password for' /tmp/os.o1.log && bad "no sudo prompt after a no" "it asked anyway" || ok "no sudo prompt after a no"
grep -Fq "$LOAD_BASH" "$UHOME/.bashrc" && bad "~/.bashrc untouched" "the load line is there" || ok "~/.bashrc untouched"
[ ! -e "$UHOME/.config/nvim" ] && ok "no ~/.config/nvim" || bad "no ~/.config/nvim"

# --- O1b: a wrong password stops it before anything changes -----------------
#
# sudo gives three tries, so three wrong answers. The whole point of asking for
# sudo up front is that a refusal lands before step 1 — not after bash and tmux
# are already installed and the run dies at step 4.
printf '\nO1b a wrong sudo password changes nothing\n'
as_user_tty 90 /tmp/os.o1b.log "" y wrong1 wrong2 wrong3
rc=$?
[ "$rc" != 0 ] && [ "$rc" != 124 ] && ok "fails (rc=$rc)" \
    || bad "fails without hanging" "rc=$rc$([ "$rc" = 124 ] && echo ' — TIMED OUT')"
grep -q 'sudo was not granted' /tmp/os.o1b.log && ok "says sudo was not granted" \
    || bad "says sudo was not granted" "$(tail -2 /tmp/os.o1b.log | tr -d '\r' | tr '\n' ' ')"
grep -q '\[1/4\]' /tmp/os.o1b.log && bad "stops before step 1" "step 1 ran" || ok "stops before step 1"
grep -Fq "$LOAD_BASH" "$UHOME/.bashrc" && bad "~/.bashrc untouched" "the load line is there" || ok "~/.bashrc untouched"

# --- O2: the real thing — y, then the sudo password, once -------------------
printf '\nO2  a normal user, in a terminal, with a sudo password\n'
t0=$(date +%s)
as_user_tty 1500 /tmp/os.o2.log "" y "$PW"
rc=$?
t1=$(date +%s)
[ $rc -eq 0 ] && ok "install exits 0 ($((t1 - t0))s)" \
    || bad "install exits 0" "rc=$rc — $(grep -E 'ERROR|Stopped' /tmp/os.o2.log | head -2 | tr -d '\r' | tr '\n' ' ')"

n=$(grep -c 'password for' /tmp/os.o2.log)
[ "$n" -eq 1 ] && ok "sudo asks for the password once" || bad "sudo asks for the password once" "asked $n times"
p=$(grep -n 'password for' /tmp/os.o2.log | head -1 | cut -d: -f1)
s=$(grep -n '\[1/4\]' /tmp/os.o2.log | head -1 | cut -d: -f1)
[ -n "$p" ] && [ -n "$s" ] && [ "$p" -lt "$s" ] \
    && ok "...and asks before step 1, not minutes in" \
    || bad "...and asks before step 1" "password at line ${p:-none}, step 1 at line ${s:-none}"

grep -Fq "$LOAD_BASH" "$UHOME/.bashrc" && ok "bash: ~/.bashrc loads the repo config" || bad "bash: ~/.bashrc loads the repo config"
grep -Fq "$LOAD_DOCKER" "$UHOME/.bash_aliases" 2>/dev/null && ok "docker: ~/.bash_aliases loads the aliases" || bad "docker: ~/.bash_aliases loads the aliases"
[ "$(readlink "$UHOME/.tmux.conf")" = "$UHOME/.marckv.dots/tmux/.tmux.conf" ] \
    && ok "tmux: ~/.tmux.conf points into the user's repo" || bad "tmux: ~/.tmux.conf points into the user's repo" "$(readlink "$UHOME/.tmux.conf")"
[ "$(readlink "$UHOME/.config/nvim")" = "$UHOME/.marckv.dots/nvim-lite" ] \
    && ok "nvim: ~/.config/nvim points into the user's repo" || bad "nvim: ~/.config/nvim points into the user's repo" "$(readlink "$UHOME/.config/nvim")"

[ -x /opt/nvim/bin/nvim ] && [ "$(stat -c %U /opt/nvim/bin/nvim)" = root ] \
    && ok "nvim: installed system-wide through sudo, owned by root" || bad "nvim: installed system-wide through sudo"
v=$(su - "$USR" -c 'nvim --version 2>/dev/null | head -1')
[ -n "$v" ] && ok "nvim: the user's next login shell runs it ($v)" || bad "nvim: the user's next login shell runs it" "not on PATH"
su - "$USR" -c 'bash -ic "declare -F mkcd" </dev/null' >/dev/null 2>&1 \
    && ok "bash: the user's next interactive shell has the repo's functions" \
    || bad "bash: the user's next interactive shell has the repo's functions"
su - "$USR" -c 'bash -ic "type dps" </dev/null' >/dev/null 2>&1 \
    && ok "docker: the user's next interactive shell has dps" || bad "docker: the user's next interactive shell has dps"

n=$(ls "$UHOME/.local/share/nvim/lazy" 2>/dev/null | wc -l)
[ "$n" -gt 0 ] && ok "nvim: plugins synced into the user's home ($n)" || bad "nvim: plugins synced into the user's home" "lazy/ is empty"
# The one that matters most for a sudo install: nothing in the user's home may
# end up owned by root, or their next plain `nvim` cannot update its own data.
r=$(find "$UHOME" -user root 2>/dev/null | head -3)
[ -z "$r" ] && ok "nothing in the user's home is owned by root" || bad "nothing in the user's home is owned by root" "$r"
su - "$USR" -c 'nvim --headless "+qa" </dev/null' >/dev/null 2>&1 \
    && ok "nvim: the config loads headless as the user" || bad "nvim: the config loads headless as the user"

# --- O3: running it again finishes cleanly and duplicates nothing ------------
printf '\nO3  a second run, as a person would after an interrupted one\n'
t0=$(date +%s)
as_user_tty 1500 /tmp/os.o3.log "" y "$PW"
rc=$?
t1=$(date +%s)
[ $rc -eq 0 ] && ok "second install exits 0 ($((t1 - t0))s)" \
    || bad "second install exits 0" "rc=$rc — $(grep -E 'ERROR|Stopped' /tmp/os.o3.log | head -2 | tr -d '\r' | tr '\n' ' ')"
n=$(grep -cF "$LOAD_BASH" "$UHOME/.bashrc")
[ "$n" -eq 1 ] && ok "~/.bashrc has the load line once" || bad "~/.bashrc has the load line once" "$n times"
n=$(grep -cF "$LOAD_DOCKER" "$UHOME/.bash_aliases")
[ "$n" -eq 1 ] && ok "~/.bash_aliases has the load line once" || bad "~/.bash_aliases has the load line once" "$n times"
[ -L "$UHOME/.config/nvim" ] && ok "~/.config/nvim is still the symlink" || bad "~/.config/nvim is still the symlink"
r=$(find "$UHOME" -user root 2>/dev/null | head -3)
[ -z "$r" ] && ok "still nothing owned by root" || bad "still nothing owned by root" "$r"

# --- O4: copy mode -----------------------------------------------------------
#
# For a server that should not depend on the repo staying where it is: the
# config is a real directory, and it keeps working with the repo gone.
printf '\nO4  -c copies the nvim-lite config\n'
su - "$USR" -c 'rm -rf ~/.config/nvim'
as_user_tty 1500 /tmp/os.o4.log "-c" y "$PW"
rc=$?
[ $rc -eq 0 ] && ok "install -c exits 0" || bad "install -c exits 0" "rc=$rc — $(grep -E 'ERROR|Stopped' /tmp/os.o4.log | head -2 | tr -d '\r' | tr '\n' ' ')"
[ -d "$UHOME/.config/nvim" ] && [ ! -L "$UHOME/.config/nvim" ] \
    && ok "~/.config/nvim is a real directory" || bad "~/.config/nvim is a real directory"
mv "$UHOME/.marckv.dots" "$UHOME/.marckv.dots.away"
su - "$USR" -c 'nvim --headless "+qa" </dev/null' >/dev/null 2>&1 \
    && ok "nvim still loads with the repo moved away" || bad "nvim still loads with the repo moved away"
mv "$UHOME/.marckv.dots.away" "$UHOME/.marckv.dots"

# --- O5: uninstall as the user ------------------------------------------------
printf '\nO5  uninstall -y as the user\n'
su - "$USR" -c '~/.marckv.dots/installer/install.sh uninstall -y </dev/null' >/tmp/os.o5.log 2>&1 \
    && ok "uninstall exits 0" || bad "uninstall exits 0" "$(tail -1 /tmp/os.o5.log)"
grep -Fq "$LOAD_BASH" "$UHOME/.bashrc" && bad "the bash line is gone" || ok "the bash line is gone"
[ ! -e "$UHOME/.config/nvim" ] && ls -d "$UHOME"/.config/nvim.backup.* >/dev/null 2>&1 \
    && ok "the copied config was moved to a backup, not deleted" || bad "the copied config was moved to a backup"
[ -x /opt/nvim/bin/nvim ] && ok "the system-wide Neovim is kept" || bad "the system-wide Neovim is kept"

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$VERSION_ID")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
