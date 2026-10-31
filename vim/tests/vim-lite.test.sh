#!/bin/bash
# vim-lite scenarios, run as root inside one distro container.
#
# The repo is mounted read-only at /root/.marckv.dots, which doubles as a check:
# anything vim-lite tried to write into ~/.vim (the repo, through the symlink)
# would fail loudly instead of leaving an untracked file behind.
#
# Vim is asked questions headless (`vim -Nes`), with the expression to evaluate
# passed through the environment instead of quoted into the command line. The
# two things only a terminal shows — the start screen and startup errors — run
# in a pty through script(1), with stdin held open until the command is done:
# closing it early makes script(1) spin (see installer/tests/oneshot.test.sh).
set -u

REPO=/root/.marckv.dots
I="$REPO/installer/06-install-vim.sh"
FIX="$REPO/nvim-lite/tests/fixtures"
STATE="$HOME/.local/state/vim"
PASS=0
FAIL=0
SKIP=0
ok()   { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mskip\033[0m %s\n' "$1"; SKIP=$((SKIP + 1)); }

# veval <expr> [ex command run first] — the value of a Vim expression, with
# vim-lite loaded, from inside the fixtures directory.
veval() {
    VEXPR="$1" VCMD="${2:-}" TERM="${VTERM:-xterm-256color}" \
        bash -c 'cd "$0" && vim -Nes -u ~/.vim/vimrc \
            -c "if !empty(\$VCMD) | silent! execute \$VCMD | endif" \
            -c "call writefile([string(eval(\$VEXPR))], \"/tmp/veval\")" -c "qa!"' "$FIX" </dev/null >/dev/null 2>&1
    cat /tmp/veval 2>/dev/null
    rm -f /tmp/veval
}

# tty_run <command> — run it in a pty; stdin stays open until it is done.
tty_run() {
    local flag="/tmp/tty.done.$$"
    rm -f "$flag"
    timeout 60 script -qec "$1; touch $flag" /dev/null \
        < <(for i in $(seq 60); do [ -e "$flag" ] && break; sleep 1; done) >/dev/null 2>&1
    rm -f "$flag"
}

. /etc/os-release
printf '\n=== %s ===\n' "$PRETTY_NAME"
rm -rf "$HOME/.vim" "$HOME/.vimrc" "$HOME"/.vim.backup.* "$STATE"

# --- S1: vim-tiny gets the basics and no errors ----------------------------
#
# vim-tiny has no +eval, so it can only take the top of vimrc. What matters is
# that it starts without an error on every launch.
printf '\nS1  vim-tiny reads vimrc without errors\n'
apt-get update -qq >/dev/null 2>&1
if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq vim-tiny >/dev/null 2>&1 && command -v vim.tiny >/dev/null; then
    out=$(cd /tmp && vim.tiny -u "$REPO/vim/vimrc" -es -c 'set directory?' -c 'qa!' </dev/null 2>&1)
    rc=$?
    [ $rc -eq 0 ] && ok "starts with exit 0" || bad "starts with exit 0" "rc=$rc: $(echo "$out" | head -2)"
    echo "$out" | grep -q 'E[0-9]\+:' && bad "no E-errors" "$(echo "$out" | grep 'E[0-9]' | head -2)" || ok "no E-errors"
    echo "$out" | grep -q '.local/state/vim/swap' && ok "swap files go to ~/.local/state/vim" \
        || bad "swap files go to ~/.local/state/vim" "$out"
else
    skip "vim-tiny not installable here"
fi

# --- S2: install, with Vim missing ------------------------------------------
printf '\nS2  install (root: Vim comes from apt if missing)\n'
had_vim=$(vim --version 2>/dev/null | grep -c '+eval')
bash "$I" -y >/tmp/s2.log 2>&1
rc=$?
[ $rc -eq 0 ] && ok "exits 0" || bad "exits 0" "rc=$rc; $(tail -3 /tmp/s2.log)"
[ "$(readlink "$HOME/.vim")" = "$REPO/vim" ] && ok "~/.vim links to the repo" || bad "~/.vim links to the repo" "$(readlink "$HOME/.vim")"
if ! vim --version 2>/dev/null | grep -q '+eval'; then
    bad "full Vim present after install" "$(tail -3 /tmp/s2.log)"
    printf '\n---- %s: %d ok, %d failed, %d skipped ----\n' "$VERSION_ID" "$PASS" "$FAIL" "$SKIP"
    exit 1
fi
[ "$had_vim" = 0 ] && { grep -q 'Vim installed' /tmp/s2.log && ok "installed Vim from apt" || bad "installed Vim from apt"; }
VV=$(veval 'v:version')
printf '       vim %s\n' "$VV"

if [ "$(veval 'has("patch-8.1.1372")')" = 0 ]; then
    # Debian 10's 8.1.0875: plugin/lite.vim steps aside; only vimrc applies.
    [ "$(veval 'get(g:, "loaded_lite", 0)')" = 0 ] && ok "Vim before 8.1.1372: lite.vim steps aside" || bad "lite.vim steps aside"
    tty_run "vim -c 'redir! > /tmp/msgs | silent messages | redir END | qa!'"
    grep -q 'E[0-9]\+:' /tmp/msgs 2>/dev/null && bad "starts without errors" "$(grep 'E[0-9]' /tmp/msgs | head -2)" || ok "starts without errors"
    printf '\n---- %s: %d ok, %d failed, %d skipped ----\n' "$VERSION_ID" "$PASS" "$FAIL" "$SKIP"
    [ $FAIL -eq 0 ]; exit $?
fi

# --- S3: starts clean, start screen ------------------------------------------
printf '\nS3  starts clean, with the start screen\n'
rm -f /tmp/msgs /tmp/start
tty_run "cd $FIX && TERM=xterm-256color vim -c 'autocmd VimEnter * call writefile(getline(1, \"\$\"), \"/tmp/start\") | redir! > /tmp/msgs | silent messages | redir END | qa!'"
if [ -f /tmp/msgs ]; then
    grep -q 'E[0-9]\+:' /tmp/msgs && bad "no errors on startup" "$(grep 'E[0-9]' /tmp/msgs | head -3)" || ok "no errors on startup"
else
    bad "no errors on startup" "vim did not run in the pty"
fi
grep -q 'vim-lite' /tmp/start 2>/dev/null && ok "start screen shows vim-lite and the keys" || bad "start screen shows" "$(head -3 /tmp/start 2>/dev/null)"
grep -q 'Find file' /tmp/start 2>/dev/null && ok "...including the key list" || bad "...including the key list"

# --- S4: colours --------------------------------------------------------------
printf '\nS4  colours\n'
[ "$(veval 'g:colors_name')" = "'gentleman'" ] && ok "256color terminal: gentleman" || bad "256color terminal: gentleman" "$(veval 'g:colors_name')"
c=$(VTERM=linux veval 'g:colors_name')
[ "$c" = "'habamax'" ] || [ "$c" = "'desert'" ] && ok "linux console: falls back ($c)" || bad "linux console: falls back" "$c"
[ "$(veval 'hlexists("LiteModeN")')" = 1 ] && ok "statusline mode colours defined" || bad "statusline mode colours defined"
veval 'LiteStatus()' 'let g:statusline_winid = win_getid()' | grep -q 'LiteMode' && ok "statusline draws the mode badge" || bad "statusline draws the mode badge"

# --- S5: swap, undo and netrw stay out of the edited dir and the repo ---------
printf '\nS5  state stays in ~/.local/state/vim\n'
mkdir -p /tmp/etcdir && echo 'a=1' > /tmp/etcdir/app.conf
s=$(VEXPR='swapname("%")' bash -c 'vim -Nes -u ~/.vim/vimrc -c "edit /tmp/etcdir/app.conf" -c "normal! Ax" -c "call writefile([eval(\$VEXPR)], \"/tmp/veval\")" -c "qa!"' </dev/null >/dev/null 2>&1; cat /tmp/veval)
case "$s" in "$STATE/swap/"*) ok "swap file under ~/.local/state/vim/swap" ;; *) bad "swap file under ~/.local/state/vim/swap" "$s" ;; esac
[ -z "$(ls -A /tmp/etcdir | grep -v '^app.conf$')" ] && ok "nothing left next to the edited file" || bad "nothing left next to the edited file" "$(ls -A /tmp/etcdir)"
[ "$(veval '&undodir')" = "'$STATE/undo//'" ] && ok "undo under ~/.local/state/vim" || bad "undo under ~/.local/state/vim" "$(veval '&undodir')"
[ "$(veval 'g:netrw_home')" = "'$STATE'" ] && ok "netrw history out of ~/.vim" || bad "netrw history out of ~/.vim"
for d in swap backup undo; do [ -d "$STATE/$d" ] || bad "creates $STATE/$d"; done
ok "state directories exist"

# --- S6: <Space><Space> and <Space>/ ------------------------------------------
printf '\nS6  find and grep\n'
if [ "$(veval 'exists("+findfunc")')" = 1 ]; then
    [ "$(veval 'bufname("%")' 'find compo')" = "'docker-compose.yml'" ] && ok "fuzzy :find compo -> docker-compose.yml" \
        || bad "fuzzy :find" "$(veval 'bufname("%")' 'find compo')"
    [ "$(veval 'exists("*wildtrigger")')" = 1 ] && ok "live menu available (wildtrigger)" || skip "no wildtrigger in this Vim"
else
    [ "$(veval 'bufname("%")' 'find docker-compose.yml')" = "'docker-compose.yml'" ] && ok "no findfunc: plain :find still works" \
        || bad "plain :find" "$(veval 'bufname("%")' 'find docker-compose.yml')"
fi
[ "$(veval 'maparg("<leader><leader>", "n")')" = "':find '" ] && ok "<Space><Space> is :find" || bad "<Space><Space> is :find"
g=$(veval 'LiteGrepComplete("", "Grep server_name", 0)')
echo "$g" | grep -q 'nginx.conf:[0-9]*:' && ok "live grep finds server_name in nginx.conf" || bad "live grep" "$g"
[ "$(veval 'len(getqflist())' 'Grep listen')" -ge 1 ] 2>/dev/null && ok "Grep without a pick fills the quickfix list" || bad "Grep fills quickfix"
r=$(veval '[bufname("%"), line(".")]' 'Grep x nginx.conf:24:9: server_name')
[ "$(veval 'type(LiteRecentComplete("x", "", 0))')" = 3 ] && ok "recent files list builds" || bad "recent files list builds"
[ "$r" = "['nginx.conf', 24]" ] && ok "picking a match opens it at its line" || bad "picking a match opens it" "$r"

# --- S7: the rest of the keys ------------------------------------------------
printf '\nS7  keys and commands\n'
if [ "$(veval '!empty(globpath(&packpath, "pack/*/opt/comment"))')" = 1 ]; then
    veval 'maparg("gc", "n")' | grep -q comment && ok "gc comments (Vim's comment package)" || bad "gc comments"
else
    skip "no comment package in this Vim"
fi
[ "$(veval 'exists(":W")')" = 2 ] && ok ":W saves through sudo" || bad ":W exists"
veval 'maparg("<C-h>", "n")' | grep -q Navigate && ok "<C-h> moves between splits and tmux panes" || bad "<C-h> navigation"
[ "$(veval 'exists(":LiteVersion")')" = 2 ] && ok ":LiteVersion" || bad ":LiteVersion"
[ "$(veval 'maparg("<Esc>", "n")')" = "''" ] && ok "<Esc> not mapped (arrow keys keep working)" || bad "<Esc> not mapped"

# --- S8: big files ------------------------------------------------------------
printf '\nS8  big files\n'
head -c 3000000 /dev/zero | tr '\0' 'a' | fold -w 100 > /tmp/big.log
r=$(veval '[get(b:, "lite_bigfile", 0), &syntax]' 'edit /tmp/big.log')
[ "$r" = "[1, 'OFF']" ] && ok "3 MB log: syntax off" || bad "3 MB log: syntax off" "$r"
r=$(veval '[get(b:, "lite_bigfile", 0), &syntax]' 'edit docker-compose.yml')
[ "$r" = "[0, 'yaml']" ] && ok "small yaml: syntax on" || bad "small yaml: syntax on" "$r"

# --- S9: the installer's refusals, copy mode, status, uninstall ---------------
printf '\nS9  installer lifecycle\n'
bash "$I" status >/tmp/s9.log 2>&1 && grep -q 'linked' /tmp/s9.log && ok "status: linked" || bad "status: linked" "$(cat /tmp/s9.log)"
bash "$I" uninstall -y >/dev/null 2>&1; [ ! -e "$HOME/.vim" ] && ok "uninstall removes the link" || bad "uninstall removes the link"

echo 'set number' > "$HOME/.vimrc"
bash "$I" -y >/tmp/s9.log 2>&1; rc=$?
[ $rc -ne 0 ] && grep -q 'reads it instead' /tmp/s9.log && ok "refuses past a ~/.vimrc it did not write" || bad "refuses past ~/.vimrc" "rc=$rc"
[ "$(cat "$HOME/.vimrc")" = 'set number' ] && ok "...and leaves it alone" || bad "...and leaves it alone"
rm -f "$HOME/.vimrc"

mkdir -p "$HOME/.vim/mine"
bash "$I" -y >/tmp/s9.log 2>&1; rc=$?
[ $rc -ne 0 ] && [ -d "$HOME/.vim/mine" ] && ok "refuses a ~/.vim it did not create" || bad "refuses foreign ~/.vim" "rc=$rc"
rm -rf "$HOME/.vim"

bash "$I" --copy -y >/dev/null 2>&1
[ -d "$HOME/.vim" ] && [ ! -L "$HOME/.vim" ] && [ -f "$HOME/.vim/plugin/lite.vim" ] && ok "--copy makes a real directory" || bad "--copy"
bash "$I" --copy -y >/dev/null 2>&1
ls -d "$HOME"/.vim.backup.* >/dev/null 2>&1 && ok "a second --copy backs the first one up" || bad "second --copy backs up"
[ "$(veval 'get(g:, "loaded_lite", 0)')" = 1 ] && ok "the copy loads" || bad "the copy loads"
bash "$I" uninstall -y >/dev/null 2>&1
[ ! -e "$HOME/.vim" ] && [ "$(ls -d "$HOME"/.vim.backup.* | wc -l)" -ge 2 ] && ok "uninstall moves a copy to a backup" || bad "uninstall moves a copy to a backup"
rm -rf "$HOME"/.vim.backup.*
bash "$I" -y >/dev/null 2>&1

printf '\n---- %s: %d ok, %d failed, %d skipped ----\n' "$VERSION_ID" "$PASS" "$FAIL" "$SKIP"
[ $FAIL -eq 0 ]
