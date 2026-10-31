#!/bin/bash
# nvim-unpack.sh scenarios, run as root inside a container started with
# --network none. /pack holds the .tgz, /repo.tar the repo with its .git.
#
# curl, wget and git are wrapped to log every call, so "it worked offline" is
# measured — nothing reached for the network — instead of inferred from the
# absence of an error message.
set -u
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; FAIL=$((FAIL + 1)); }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

. /etc/os-release
printf '\n=== %s ===\n' "$PRETTY_NAME"
PACK=$(ls /pack/marckv-nvim-*.tgz)
U=/root/.marckv.dots/installer/offline/nvim-unpack.sh

curl -sm 3 https://github.com >/dev/null 2>&1 && bad "no network" "github answered" || ok "no network"

# The baked-in test image ships a Neovim in /opt; it would stand in for one
# this pack installed.
rm -rf /opt/nvim /etc/profile.d/nvim.sh /usr/local/bin/fzf /usr/local/bin/tree-sitter /tmp/nvim-*
id development >/dev/null 2>&1 || useradd -m -s /bin/bash development

mkdir -p /usr/local/shim
for c in curl wget git; do
    real=$(PATH=/usr/bin:/bin command -v $c) || continue
    printf '#!/bin/sh\necho "$(id -un) %s $*" >> /tmp/net.log\nexec %s "$@"\n' "$c" "$real" > /usr/local/shim/$c
    chmod 755 /usr/local/shim/$c
done
: > /tmp/net.log; chmod 666 /tmp/net.log
SHIM='export PATH=/usr/local/shim:$PATH'

for u in root development; do
    h=$(getent passwd $u | cut -d: -f6)
    rm -rf "$h/.marckv.dots" && mkdir -p "$h/.marckv.dots" && tar -xf /repo.tar -C "$h/.marckv.dots" && chown -R $u: "$h/.marckv.dots"
done

# --- the GLIBC gate: the pack refuses what it cannot run on ------------------
have=$(ldd --version | head -n1 | awk '{print $NF}')
need=$(tar -xzOf "$PACK" pack/MANIFEST | sed -n 's/^GLIBC_NEEDED=//p')
if [ "$(printf '%s\n%s\n' "$need" "$have" | sort -V | tail -n1)" != "$have" ]; then
    printf '\nS0  GLIBC %s < %s: refuses\n' "$have" "$need"
    out=$($U "$PACK" -y </dev/null 2>&1); rc=$?; out=$(printf '%s' "$out" | strip)
    [ $rc -ne 0 ] && echo "$out" | grep -q "needs GLIBC" && ok "refuses, and says why" || bad "refuses" "rc=$rc $out"
    [ ! -e /opt/nvim ] && ok "installed nothing" || bad "installed nothing"
    printf '\n---- %s: %d ok, %d failed ----\n' "$VERSION_ID" "$PASS" "$FAIL"
    [ $FAIL -eq 0 ]; exit $?
fi

check_user() {  # $1 = user
    local u=$1 out f
    out=$(su - $u -c "$SHIM; cd ~/samples && for f in docker-compose.yml nginx.conf Dockerfile app.ini main.tf deploy.json; do
        nvim --headless \"\$f\" '+lua vim.defer_fn(function() local b = vim.api.nvim_get_current_buf(); io.stdout:write(vim.fn.expand(\"%\") .. \" \" .. tostring(vim.treesitter.highlighter.active[b] ~= nil) .. \"\\n\"); vim.cmd(\"redir! >> /tmp/msgs.$u | silent messages | redir END | qa!\") end, 2500)'
    done" 2>&1 | strip)
    for f in docker-compose.yml nginx.conf Dockerfile app.ini main.tf deploy.json; do
        echo "$out" | grep -q "^$f true$" || { bad "$u: treesitter on $f" "$(echo "$out" | grep "^$f" || echo "$out" | tail -3)"; return; }
    done
    ok "$u: treesitter highlights all 6 deployment files"
    grep -qiE 'E[0-9]+:|error' /tmp/msgs.$u 2>/dev/null && bad "$u: no errors in :messages" "$(grep -iE 'E[0-9]+:|error' /tmp/msgs.$u | head -3)" \
        || ok "$u: no errors in :messages"
}

for u in root development; do
    h=$(getent passwd $u | cut -d: -f6)
    mkdir -p $h/samples && cp -a /fixtures/. $h/samples/ && chown -R $u: $h/samples
    printf '\nS%s  %s\n' "$([ $u = root ] && echo 1 || echo 2)" "$([ $u = root ] && echo 'root: unpack' || echo 'development, no sudo: unpack after root')"
    out=$(su - $u -c "$SHIM; ~/.marckv.dots/installer/offline/nvim-unpack.sh $PACK -y </dev/null" 2>&1); rc=$?; out=$(printf '%s' "$out" | strip)
    [ $rc -eq 0 ] && ok "$u: exits 0" || bad "$u: exits 0" "rc=$rc $(echo "$out" | tail -5)"
    echo "$out" | grep -qi 'password' && bad "$u: never asks for a password" || ok "$u: never asks for a password"
    [ "$(readlink $h/.config/nvim)" = "$h/.marckv.dots/nvim-lite" ] && ok "$u: config linked" || bad "$u: config linked"
    [ -f $h/.local/share/nvim/marckv-pack.manifest ] && ok "$u: manifest recorded" || bad "$u: manifest recorded"
    check_user $u
done

[ -x /opt/nvim/bin/nvim ] && ok "Neovim system-wide in /opt/nvim (root installed it)" || bad "Neovim in /opt/nvim"
[ ! -e /home/development/.local/nvim ] && ok "development reused root's Neovim (no copy in ~/.local)" || bad "development reused root's Neovim"
[ -x /usr/local/bin/fzf ] && [ -x /usr/local/bin/tree-sitter ] && ok "fzf and tree-sitter in /usr/local/bin" || bad "fzf and tree-sitter"

printf '\nS3  nothing reached for the network\n'
net=$(grep -E ' (curl|wget) |git .*(clone|fetch|pull|ls-remote|http)' /tmp/net.log)
[ -z "$net" ] && ok "no curl, wget, clone or fetch — $(wc -l < /tmp/net.log) local git calls (gitsigns)" || bad "no network calls" "$net"

printf '\nS4  unpacking again (an update) keeps the previous data aside\n'
out=$(su - development -c "$SHIM; ~/.marckv.dots/installer/offline/nvim-unpack.sh $PACK -y </dev/null" 2>&1); rc=$?; out=$(printf '%s' "$out" | strip)
[ $rc -eq 0 ] && ok "second unpack exits 0" || bad "second unpack" "$(echo "$out" | tail -3)"
ls -d /home/development/.local/share/nvim.backup.* >/dev/null 2>&1 && ok "previous data moved to a backup" || bad "previous data moved to a backup"
echo "$out" | grep -q 'already installed' && ok "Neovim not reinstalled when it is current" || bad "Neovim not reinstalled"
rm -f /tmp/msgs.development; check_user development
out=$(su - development -c '~/.marckv.dots/installer/offline/nvim-unpack.sh status' 2>&1 | strip)
echo "$out" | grep -q 'NVIM_TAG=' && ok "status shows the pack's manifest" || bad "status" "$out"

printf '\nS5  marckv update --from warns when the pack no longer matches\n'
upd() {  # $1 = path to change, $2 = message
    su - development -c "
        g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null \"\$@\"; }
        rm -rf /tmp/laptop && git clone -q ~/.marckv.dots /tmp/laptop && cd /tmp/laptop &&
        git checkout -q -B main && echo '-- $2' >> $1 && g commit -qam '$2' && g bundle create -q /tmp/u.bundle main
        export MARCKV_DOTS_DIR=~/.marckv.dots
        source ~/.marckv.dots/bash/colors.sh; source ~/.marckv.dots/bash/marckv.sh
        marckv update --from /tmp/u.bundle" 2>&1 | strip
}
su - development -c 'git -C ~/.marckv.dots checkout -q -B main' >/dev/null 2>&1
out=$(upd README.md "docs: unrelated")
echo "$out" | grep -q 'docs: unrelated' && ok "an update that leaves nvim-lite alone goes through" || bad "unrelated update" "$out"
echo "$out" | grep -q 'offline pack' && bad "...without a pack warning" "$out" || ok "...without a pack warning"
out=$(upd nvim-lite/lua/config/options.lua "feat(nvim): new option")
echo "$out" | grep -q 'changed since its offline pack was built' && ok "an update that changes nvim-lite/lua warns to rebuild the pack" || bad "pack warning" "$out"

printf '\n---- %s: %d ok, %d failed ----\n' "$VERSION_ID" "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
