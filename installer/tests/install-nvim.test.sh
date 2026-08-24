#!/bin/bash
# Scenarios for install-nvim.sh. Runs INSIDE a container, as root.
#
# Driven by ../tests/run.sh, which copies this into each distro container. It
# is not run on the host on purpose: every scenario writes to /opt and
# /etc/profile.d and would replace a real Neovim install.
#
# The distro matters more here than anywhere else in this repo, because the
# thing under test is which Neovim binary a given GLIBC can run. Debian 11 and
# Ubuntu 20.04 sit on GLIBC 2.31 and take a different path from the rest — S3
# only means anything there.

I=/root/.marckv.dots/installer/install-nvim.sh
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "$2" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }
wipe() { rm -rf /opt/nvim /opt/nvim.prev /opt/.nvim-stage.* /etc/profile.d/nvim.sh; }

GLIBC=$(ldd --version | head -1 | awk '{print $NF}')
printf '\n=== %s  (GLIBC %s) ===\n' "$(. /etc/os-release; echo "$PRETTY_NAME")" "$GLIBC"

# --- S1: a clean install under this repo's own umask ------------------------
#
# umask 027 is what bash/environment.sh sets, so it is what root actually has
# when installing from a shell this repo configured. Neovim's tarball has no
# entry for its own top-level directory, so tar creates that one with the umask
# — which used to make /opt/nvim 0750 and lock every other user out.
printf '\nS1  clean install under umask 027\n'
wipe
( umask 027; printf 'yes\n' | bash "$I" ) > /tmp/s1.log 2>&1
rc=$?
[ $rc -eq 0 ] && ok "succeeds" || bad "succeeds" "rc=$rc; $(tail -3 /tmp/s1.log)"
mode=$(stat -c '%a' /opt/nvim 2>/dev/null)
[ "$mode" = "755" ] && ok "/opt/nvim is 755 despite umask 027" || bad "/opt/nvim is 755" "got $mode"
/opt/nvim/bin/nvim --version >/dev/null 2>&1 && ok "the binary starts" || bad "the binary starts"
printf '       installed: %s\n' "$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)"

# --- S2: a non-root user can actually use it --------------------------------
#
# The bug this suite exists for looked exactly like "not installed": $PATH
# pointed at /opt/nvim/bin and the user could not enter the directory.
printf '\nS2  a non-root user can reach it\n'
id testuser >/dev/null 2>&1 || useradd -m testuser 2>/dev/null
su - testuser -c 'command -v nvim >/dev/null' 2>/dev/null && ok "finds it on PATH" || bad "finds it on PATH"
su - testuser -c 'nvim --version >/dev/null 2>&1' && ok "can execute it" || bad "can execute it"

# --- S3: an incompatible release must not destroy a working one -------------
printf '\nS3  incompatible release: fails without breaking what works\n'
before=$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)
printf 'yes\n' | bash "$I" --version v0.12.5 > /tmp/s3.log 2>&1
rc=$?
if [ "$GLIBC" = "2.31" ]; then
    [ $rc -ne 0 ] && ok "exits non-zero" || bad "exits non-zero" "rc=$rc"
    grep -q "cannot run on this system" /tmp/s3.log && ok "says why" || bad "says why" "$(tail -3 /tmp/s3.log)"
    grep -q "still installed and working" /tmp/s3.log && ok "says nothing changed" || bad "says nothing changed"
    after=$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)
    [ "$before" = "$after" ] && ok "previous install intact ($after)" || bad "previous install intact" "before=$before after=$after"
    ls -d /opt/.nvim-stage.* >/dev/null 2>&1 && bad "leaves no staging dir" "$(ls -d /opt/.nvim-stage.* 2>/dev/null)" || ok "leaves no staging dir"
else
    [ $rc -eq 0 ] && ok "installs fine on a newer GLIBC" || bad "installs" "rc=$rc; $(tail -3 /tmp/s3.log)"
fi

# --- S4: repair an install that is already broken ---------------------------
printf '\nS4  repairs an existing install\n'
chmod 750 /opt/nvim
[ "$(stat -c '%a' /opt/nvim)" = "750" ] && printf '       (broken on purpose: 750)\n'
# Answered "no" so NOTHING is reinstalled and only the repair path can have
# run. Answering "yes" would have the staging chmod fix the mode anyway, and
# the test would pass with the repair deleted.
printf 'no\n' | bash "$I" --version v0.10.3 > /tmp/s4.log 2>&1
grep -q "Permissions repaired" /tmp/s4.log && ok "detects and reports it" || bad "detects and reports it" "$(grep -i perm /tmp/s4.log | head -2)"
[ "$(stat -c '%a' /opt/nvim)" = "755" ] && ok "leaves it 755 WITHOUT reinstalling" || bad "leaves it 755 without reinstalling" "got $(stat -c '%a' /opt/nvim)"
su - testuser -c 'nvim --version >/dev/null 2>&1' && ok "the user can run it now" || bad "the user can run it now"

# --- S5: the unversioned cache is cleaned up --------------------------------
printf '\nS5  removes the old unversioned cache\n'
: > /tmp/nvim-linux-x86_64.tar.gz
: > /tmp/nvim-linux64.tar.gz
printf 'no\n' | bash "$I" --version v0.10.3 > /tmp/s5.log 2>&1
grep -q "stale unversioned cache" /tmp/s5.log && ok "reports the removal" || bad "reports the removal"
[ ! -f /tmp/nvim-linux-x86_64.tar.gz ] && [ ! -f /tmp/nvim-linux64.tar.gz ] && ok "they are gone" || bad "they are gone"

# --- S6: the cache is keyed by version --------------------------------------
#
# The invariant is not "version X is cached" — which version gets downloaded
# depends on the distro's GLIBC. It is that NO cache uses the bare name, the
# one that let a stale tarball stand in for any version asked for later.
printf '\nS6  the cache is keyed by version\n'
bare=$(ls /tmp/nvim-linux64.tar.gz /tmp/nvim-linux-x86_64.tar.gz 2>/dev/null | wc -l)
tagged=$(ls /tmp/nvim-v*-*.tar.gz 2>/dev/null | wc -l)
[ "$bare" -eq 0 ] && ok "no cache left under a bare name" || bad "no bare-name cache" "$(ls /tmp/nvim-linux*.tar.gz 2>/dev/null)"
[ "$tagged" -ge 1 ] && ok "caches carry the tag ($(ls /tmp/nvim-v*-*.tar.gz 2>/dev/null | head -1 | xargs basename))" || bad "caches carry the tag" "$(ls /tmp/nvim-*.tar.gz 2>/dev/null)"

# --- S7: a version that does not exist --------------------------------------
# The download itself fails here rather than the binary, so this covers the
# other failure path, and it behaves the same on every distro.
printf '\nS7  a nonexistent version fails without touching the install\n'
before=$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)
printf 'yes\n' | bash "$I" --version v99.99.99 > /tmp/s7.log 2>&1
rc=$?
[ $rc -ne 0 ] && ok "exits non-zero" || bad "exits non-zero" "rc=$rc"
after=$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)
[ "$before" = "$after" ] && [ -n "$after" ] && ok "install intact ($after)" || bad "install intact" "before=$before after=$after"
ls -d /opt/.nvim-stage.* >/dev/null 2>&1 && bad "leaves no staging dir" "$(ls -d /opt/.nvim-stage.* 2>/dev/null)" || ok "leaves no staging dir"

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$ID$VERSION_ID")" "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
