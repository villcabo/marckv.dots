#!/bin/bash
# marckv update's signature check, run as root inside a test container.
#
#   docker compose exec -T ubuntu24 bash /root/.marckv.dots/bash/tests/verify-update.test.sh
#
# Three keys made on the spot: the owner's, an attacker's, and one standing in
# for GitHub's web-flow key. A bare repo plays origin, a clone plays the host,
# and every way a commit could be slipped in is tried against the host.
set -u
REPO=${REPO:-/root/.marckv.dots}
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; FAIL=$((FAIL + 1)); }

command -v gpg >/dev/null || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gnupg; } >/dev/null 2>&1
. /etc/os-release
printf '\n=== %s  (%s) ===\n' "$PRETTY_NAME" "$(gpg --version | head -1)"

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
export GNUPGHOME="$W/signers"            # where the SIGNING keys live
mkdir -m 700 "$GNUPGHOME"
for who in owner attacker github; do
    gpg --batch --quiet --passphrase '' --quick-gen-key "$who <$who@test>" ed25519 sign never 2>/dev/null
done
fpr() { gpg --batch --with-colons --list-keys "$1@test" | awk -F: '$1=="fpr"{print $10; exit}'; }
OWNER=$(fpr owner) ATTACKER=$(fpr attacker) GITHUB=$(fpr github)

# commit_as <key|none> <message> [git commit args...] — in the laptop clone
commit_as() {
    local key=$1 msg=$2; shift 2
    if [ "$key" = none ]; then
        git -C "$W/laptop" -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m "$msg" "$@"
    else
        git -C "$W/laptop" -c commit.gpgsign=true -c user.signingkey="$key" -c core.hooksPath=/dev/null commit -q --allow-empty -m "$msg" "$@"
    fi
}
push() { git -C "$W/laptop" push -q -f origin HEAD:main 2>/dev/null; }

# --- origin: the repo as it is, plus the test keys in keys/ ------------------
git config --global user.name t; git config --global user.email t@test
git config --global init.defaultBranch main; git config --global --add safe.directory '*'
mkdir -p "$W/laptop" && cp -a "$REPO/." "$W/laptop/" && rm -rf "$W/laptop/.git"
gpg --batch --armor --export "$OWNER" > "$W/laptop/keys/marckv.asc"
gpg --batch --armor --export "$GITHUB" > "$W/laptop/keys/github-web-flow.asc"
# symbolic-ref, not init -b or init.defaultBranch: git 2.25 (Ubuntu 20.04)
# has neither, and an origin left on master clones empty.
git -C "$W/laptop" init -q && git -C "$W/laptop" symbolic-ref HEAD refs/heads/main && git -C "$W/laptop" add -A
commit_as "$OWNER" "base"
git init -q --bare "$W/origin.git" && git -C "$W/origin.git" symbolic-ref HEAD refs/heads/main
git -C "$W/laptop" remote add origin "$W/origin.git" && push
git clone -q "$W/origin.git" "$W/host"

# update [args] — marckv update on the host, in a fresh shell; prints the output
update() {
    env -u GNUPGHOME HOME="$W" MARCKV_DOTS_DIR="$W/host" bash -c '
        source "$MARCKV_DOTS_DIR/bash/colors.sh"; source "$MARCKV_DOTS_DIR/bash/marckv.sh"
        _marckv_reload() { echo reloaded; }
        marckv update "$@"; echo "rc=$?"' _ "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
}
host_head() { git -C "$W/host" rev-parse HEAD; }
reset_origin() { git -C "$W/laptop" reset -q --hard "$1"; push; }

good=$(git -C "$W/laptop" rev-parse HEAD)

printf '\nS1  a commit signed by the owner\n'
commit_as "$OWNER" "owner change"; push
out=$(update)
[ "$(host_head)" = "$(git -C "$W/laptop" rev-parse HEAD)" ] && ok "taken" || bad "taken" "$out"
echo "$out" | grep -q 'Verified: 1 new commit' && ok "says it verified 1 commit" || bad "says verified" "$out"
good=$(host_head)

refused() {  # <label>
    local before; before=$(host_head)
    out=$(update)
    if [ "$(host_head)" = "$before" ] && echo "$out" | grep -q 'not signed by a trusted key' && echo "$out" | grep -q 'rc=1'; then
        ok "$1: refused, host unchanged"
    else
        bad "$1: refused" "$out"
    fi
    [ -z "$(git -C "$W/host" status --porcelain)" ] || bad "$1: working tree untouched"
    reset_origin "$good"
}

printf '\nS2  what must be refused\n'
commit_as none "unsigned";                               push; refused "unsigned commit"
commit_as "$ATTACKER" "attacker";                         push; refused "signed by another key"
commit_as "$GITHUB" "edited on the web";                  push; refused "plain commit signed by GitHub's key"
commit_as "$OWNER" "fine"; commit_as none "unsigned on top"; push; refused "good commit + unsigned one"
gpg --batch --armor --export "$ATTACKER" > "$W/laptop/keys/marckv.asc"
git -C "$W/laptop" add keys/marckv.asc
commit_as "$ATTACKER" "swap the trusted key";             push; refused "commit that swaps keys/ for its own"

printf '\nS3  merges signed by GitHub\n'
git -C "$W/laptop" checkout -q -b feat
commit_as "$OWNER" "feature work"
git -C "$W/laptop" checkout -q main
git -C "$W/laptop" -c commit.gpgsign=true -c user.signingkey="$GITHUB" -c core.hooksPath=/dev/null merge -q --no-ff feat -m "Merge pull request #1"
push
out=$(update)
[ "$(host_head)" = "$(git -C "$W/laptop" rev-parse HEAD)" ] && ok "GitHub-signed merge of owner commits: taken" || bad "GitHub merge taken" "$out"
good=$(host_head)
git -C "$W/laptop" checkout -q -b evil
commit_as "$ATTACKER" "hidden in a PR"
git -C "$W/laptop" checkout -q main
git -C "$W/laptop" -c commit.gpgsign=true -c user.signingkey="$GITHUB" -c core.hooksPath=/dev/null merge -q --no-ff evil -m "Merge pull request #2"
push; refused "GitHub-signed merge hiding an attacker commit"

printf '\nS4  offline, from a bundle\n'
commit_as "$OWNER" "via bundle"
git -C "$W/laptop" bundle create -q "$W/ok.bundle" main
out=$(update --from "$W/ok.bundle")
[ "$(host_head)" = "$(git -C "$W/laptop" rev-parse HEAD)" ] && ok "signed bundle: taken" || bad "signed bundle" "$out"
[ "$(git -C "$W/host" rev-parse origin/main)" = "$(host_head)" ] && ok "origin/main moved with it" || bad "origin/main moved"
good=$(host_head)
commit_as none "unsigned via bundle"
git -C "$W/laptop" bundle create -q "$W/bad.bundle" main
before_om=$(git -C "$W/host" rev-parse origin/main)
out=$(update --from "$W/bad.bundle")
[ "$(host_head)" = "$good" ] && echo "$out" | grep -q 'not signed' && ok "unsigned bundle: refused" || bad "unsigned bundle" "$out"
[ "$(git -C "$W/host" rev-parse origin/main)" = "$before_om" ] && ok "...and origin/main did not move" || bad "origin/main moved on a refusal"
reset_origin "$good"

printf '\nS5  --no-verify, and what verifying needs\n'
commit_as none "unsigned, taken on purpose"; push
out=$(update --no-verify)
[ "$(host_head)" = "$(git -C "$W/laptop" rev-parse HEAD)" ] && echo "$out" | grep -q 'without checking' && ok "--no-verify takes it, with a warning" || bad "--no-verify" "$out"
commit_as "$OWNER" "next"; push
mv "$W/host/keys" "$W/keys.away"
out=$(update)
echo "$out" | grep -q 'no trusted key' && echo "$out" | grep -q 'rc=1' && ok "no keys/ in the copy: refused" || bad "no keys/" "$out"
mv "$W/keys.away" "$W/host/keys"
mkdir -p "$W/nogpg" && for c in git bash env sed awk grep mktemp rm readlink cut head date ls dirname basename cat; do ln -sf "$(command -v $c)" "$W/nogpg/$c"; done
out=$(PATH="$W/nogpg" update)
echo "$out" | grep -q 'gpg is not installed' && ok "no gpg: refused, says why" || bad "no gpg" "$out"
# update() runs with HOME=$W: a ~/.gnupg there means gpg wrote to the account
[ -e "$W/.gnupg" ] && bad "the account's own ~/.gnupg was created" || ok "the account's own ~/.gnupg untouched"

printf '\n---- %s: %d ok, %d failed ----\n' "$VERSION_ID" "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
