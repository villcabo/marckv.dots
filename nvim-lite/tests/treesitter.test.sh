#!/bin/bash
# Scenarios for nvim-lite's treesitter setup. Runs INSIDE a container, as root.
#
# Driven by ./run.sh. Not run on the host: it installs Neovim into /opt and
# replaces ~/.config/nvim.
#
# What is under test is a decision, not a colour: whether this machine can
# BUILD parsers, and whether it therefore ends up with one for yaml. The config
# used to decide that by looking for the `tree-sitter` CLI, which ships with
# neither Neovim's tarball nor any distro package here — so on every server the
# answer was "no" and nothing was installed. Nobody noticed, because Vim's
# legacy regex syntax keeps the file looking coloured.

REPO=/root/.marckv.dots
FIX="$REPO/nvim-lite/tests/fixtures/docker-compose.yml"
FIXDIR_PTY="$REPO/nvim-lite/tests/fixtures"
export PATH="$PATH:/opt/nvim/bin"
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "$2" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }

GLIBC=$(ldd --version | head -1 | awk '{print $NF}')
printf '\n=== %s  (GLIBC %s) ===\n' "$(. /etc/os-release; echo "$PRETTY_NAME")" "$GLIBC"

# --- setup: Neovim, chosen by the installer from this machine's GLIBC --------
#
# The test is whether nvim RUNS, not whether the file is there. `command -v`
# was the first version of this and it was wrong in the same way the installer
# itself used to be: a leftover binary built for a newer GLIBC sits in /opt,
# answers `command -v` perfectly and dies the moment it is executed. That made
# Ubuntu 20.04 report six failures that had nothing to do with what was under
# test.
if ! nvim --version >/dev/null 2>&1; then
    printf 'yes\n' | bash "$REPO/installer/install-nvim.sh" >/tmp/nvim-install.log 2>&1 \
        || { bad "Neovim installs" "$(tail -5 /tmp/nvim-install.log)"; exit 1; }
fi
if ! nvim --version >/dev/null 2>&1; then
    bad "Neovim runs on this system" "$(nvim --version 2>&1 | head -3)"
    exit 1
fi
ok "Neovim runs: $(nvim --version | head -1)"

mkdir -p ~/.config
ln -sfn "$REPO/nvim-lite" ~/.config/nvim

# --- S1: the dependencies the config actually needs -------------------------
#
# Two different requirements hide behind one name. nvim-treesitter's `master`
# branch (what Neovim 0.10 gets) builds pre-generated C sources and needs only
# a compiler. Its `main` branch (Neovim 0.11+) needs the tree-sitter CLI, and
# the one mason fetches is built against GLIBC 2.39 — so on Debian 12 (2.36)
# and Ubuntu 22.04 (2.35) it cannot start and nothing gets built at all.
printf '\nS1  the build dependencies are present\n'
bash "$REPO/installer/04-install-nvim-lite.sh" --deps >/tmp/deps.log 2>&1 \
    || printf '       (deps run reported a problem, see /tmp/deps.log)\n'
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 \
    && ok "a C compiler is present" \
    || bad "a C compiler is present"
# Whether a CLI is REQUIRED depends on which branch this Neovim gets, so the
# assertion has to as well. Demanding one everywhere failed Debian 10 for
# having correctly decided it did not need one — no tree-sitter release ever
# published runs on GLIBC 2.28, and on Neovim 0.9 nothing asks for one.
NVIM_MINOR=$(nvim --version | head -1 | sed -E 's/^NVIM v[0-9]+\.([0-9]+)\..*/\1/')
if [ "${NVIM_MINOR:-0}" -ge 11 ]; then
    if command -v tree-sitter >/dev/null 2>&1 && tree-sitter --version >/dev/null 2>&1; then
        ok "a tree-sitter CLI that RUNS here: $(tree-sitter --version 2>&1 | head -1)"
    else
        bad "a tree-sitter CLI that runs here (required on Neovim 0.11+)" \
            "$(command -v tree-sitter >/dev/null 2>&1 && tree-sitter --version 2>&1 | head -1 || echo 'not installed')"
    fi
else
    ok "Neovim 0.${NVIM_MINOR} uses the master branch — no tree-sitter CLI needed"
    if command -v tree-sitter >/dev/null 2>&1 && ! tree-sitter --version >/dev/null 2>&1; then
        bad "no unusable CLI was left behind" "$(tree-sitter --version 2>&1 | head -1)"
    else
        ok "no unusable CLI was left on PATH"
    fi
fi

# --- S2: plugins install, and the yaml parser with them ---------------------
#
# Looked for in BOTH places on purpose: the master branch keeps parsers inside
# the plugin directory, the main branch writes them to the site directory. A
# check against only one of them passes or fails depending on the distro rather
# than on whether anything worked.
printf '\nS2  the installer builds the declared parsers\n'
# The suite calls the INSTALLER, instead of installing parsers itself.
#
# It used to do the work here: read the language list out of the config, then
# require('nvim-treesitter').install(missing):wait(). That passed on all eight
# distros while the installer shipped
#     nvim --headless "+lua pcall(function() vim.cmd('TSUpdateSync') end)"
# under a comment claiming Lazy sync had already installed the parsers. Both
# halves were false on nvim-treesitter's `main` branch — TSUpdateSync does not
# exist there, and main installs lazily when a matching file is opened — and
# the pcall swallowed it. A real `--reinstall` on Debian 13 left 16 of 24, with
# yaml, bash, python and markdown among the missing.
#
# The suite could never have caught that, because it was testing its own copy
# of the logic and doing the installer's job before measuring. So the duplicate
# is gone and this drives the real thing: if step_sync regresses, S2 goes red.
timeout 900 bash "$REPO/installer/04-install-nvim-lite.sh" -s >/tmp/tsinstall.log 2>&1
printf '       %s\n' "$(grep -aoE '(all [0-9]+ treesitter parsers built|[0-9]+ of [0-9]+ parsers built — missing: .*)' /tmp/tsinstall.log | head -1 | sed 's/\x1b\[[0-9;]*m//g')"
printf '       installed: %s parsers\n' "$(find ~/.local/share/nvim -name '*.so' -path '*parser*' 2>/dev/null | wc -l)"

YAML_SO=$(find ~/.local/share/nvim -name 'yaml.so' -path '*parser*' 2>/dev/null | head -1)
if [ -n "$YAML_SO" ]; then
    ok "yaml.so was built ($(stat -c '%s' "$YAML_SO") bytes)"
    printf '       %s\n' "$YAML_SO"
else
    bad "yaml.so was built" "found: $(find ~/.local/share/nvim -name '*.so' -path '*parser*' 2>/dev/null | wc -l) parsers total"
fi

# --- S3: the buffer is actually highlighted by treesitter -------------------
#
# The load-bearing assertion. A parser sitting on disk proves nothing: what
# matters is whether opening a compose file gets a live treesitter highlighter,
# which is exactly what regex syntax fakes convincingly enough to hide the bug.
printf '\nS3  a compose file gets a live treesitter highlighter\n'
# nvim-treesitter is lazy-loaded, so it is loaded first — an interactive
# session gets there through its own events, and a headless one that skips it
# would be measuring lazy-loading, not the config's decision. Then the
# highlighter is waited for rather than sampled once.
#
# The parser check reads the RETURNED VALUE, not just pcall's status: since
# Neovim 0.11 get_parser returns nil instead of throwing when the parser is
# missing, so `pcall(...)` alone is true either way. It reported a yaml parser
# on a machine that had none.
OUT=$(timeout 300 nvim --headless \
  -c 'lua require("lazy").load({ plugins = { "nvim-treesitter" } })' \
  "$FIX" -c 'lua
  local buf = vim.api.nvim_get_current_buf()
  vim.wait(5000, function()
    return vim.treesitter.highlighter.active[buf] ~= nil
  end, 100)
  print("filetype=" .. vim.bo[buf].filetype)
  print("treesitter_highlighter=" .. tostring(vim.treesitter.highlighter.active[buf] ~= nil))
  local okp, parser = pcall(vim.treesitter.get_parser, buf, "yaml")
  print("yaml_parser=" .. tostring(okp and parser ~= nil))
' -c 'qa' 2>&1)
case "$OUT" in *"filetype=yaml"*) ok "filetype is yaml" ;; *) bad "filetype is yaml" "$OUT" ;; esac
case "$OUT" in *"yaml_parser=true"*) ok "a yaml parser loads for the buffer" ;; *) bad "a yaml parser loads" "$OUT" ;; esac
case "$OUT" in *"treesitter_highlighter=true"*) ok "treesitter is highlighting it" ;; *) bad "treesitter is highlighting it" "$OUT" ;; esac

# --- S4: no compiler still starts cleanly -----------------------------------
#
# The reason the gate exists at all, and the half worth keeping: these dotfiles
# land on hosts with no toolchain, where a config that errors on every startup
# is worse than one with plainer colours.
printf '\nS4  with no compiler, it degrades instead of erroring\n'
BARE=/tmp/barebin
mkdir -p "$BARE"
for b in nvim git curl tar sh bash ls; do
    src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$BARE/$b"
done
OUT=$(timeout 300 env -i HOME="$HOME" TERM=dumb PATH="$BARE" "$BARE/nvim" --headless -c 'lua
  print("cc=" .. tostring(vim.fn.executable("cc")) .. " gcc=" .. tostring(vim.fn.executable("gcc")))
  print("started_ok")
' -c 'qa' 2>&1)
case "$OUT" in *"cc=0 gcc=0"*) ok "the compiler really is hidden" ;; *) bad "the compiler is hidden" "$OUT" ;; esac
case "$OUT" in *"started_ok"*) ok "starts without erroring" ;; *) bad "starts without erroring" "$OUT" ;; esac
case "$OUT" in *"E5108"*|*"stack traceback"*) bad "no lua error on startup" "$OUT" ;; *) ok "no lua error on startup" ;; esac

# --- S5: the trim holds ------------------------------------------------------
#
# Turning a LazyVim default off is one line, and one line is exactly what goes
# missing in a merge. These assert on what is on disk after a real sync, not on
# what the config says it wants.
printf '\nS5  the plugins this config drops stay dropped\n'
LAZY=~/.local/share/nvim/lazy

# The list comes from lazy itself, not from one kept by hand here.
#
# A hand-written list was the first version and it went stale three times in a
# row — once when snacks moved from kept to dropped, once when it moved back,
# once when Debian 10 turned out to run LazyVim v14 with entirely different
# plugin names. Every time the assertion chased the config instead of pinning
# it, and every time the failure was the test's, not the code's.
#
# Asking lazy which specs it resolved as disabled makes the check follow
# disabled.lua automatically, on whichever LazyVim generation this Neovim got.
rm -f /tmp/disabled.txt
timeout 120 nvim --headless -c 'lua
  local ok, cfg = pcall(require, "lazy.core.config")
  local fh = io.open("/tmp/disabled.txt", "w")
  if ok and cfg.spec and cfg.spec.disabled then
    for name, _ in pairs(cfg.spec.disabled) do fh:write(name .. "\n") end
  end
  fh:close()
' -c 'qa' >/dev/null 2>&1

DECLARED=$(cat /tmp/disabled.txt 2>/dev/null | wc -l)
if [ "$DECLARED" -eq 0 ]; then
    bad "lazy reports what the config disables" "got an empty list"
else
    present=""
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        [ -d "$LAZY/$name" ] && present="$present $name"
    done < /tmp/disabled.txt
    if [ -z "$present" ]; then
        ok "all $DECLARED plugins this config disables are absent from disk"
    else
        bad "disabled plugins are absent from disk" "still installed:$present"
    fi
fi

# The half that matters more: dropping things must not take LazyVim with it.
# These are named on purpose — they are the identity of the editor, and a list
# derived from the config could not tell that losing them was a problem. That
# is also why this half is allowed to go stale and the other is not: when a
# plugin moves from kept to dropped, someone has to say so here.
#
# neo-tree was on this list and is not any more: oil is the explorer in use and
# <leader>e points at it. LazyVim imports neo-tree itself, so it took an
# explicit `enabled = false` to actually remove it — deleting the local spec
# only dropped the override, and left it installed while a comment claimed
# otherwise. This assertion is what caught that the two had diverged.
#
# snacks and LazyVim are on it for the opposite reason: losing either is the
# expensive failure. Removing snacks was tried and abandoned — LazyVim v14
# reaches for the `Snacks` global 127 times — so it stays, deliberately, and a
# future trim that takes it out should turn this red.
KEPT="LazyVim snacks.nvim fzf-lua nvim-treesitter which-key.nvim lualine.nvim gitsigns.nvim flash.nvim mini.ai mini.surround todo-comments.nvim oil.nvim"
missing=""
for p in $KEPT; do
    [ -d "$LAZY/$p" ] || missing="$missing $p"
done
if [ -z "$missing" ]; then
    ok "the LazyVim core it keeps is all there"
else
    bad "the LazyVim core is intact" "missing:$missing"
fi

SIZE=$(du -sm ~/.local/share/nvim 2>/dev/null | cut -f1)
COUNT=$(ls "$LAZY" 2>/dev/null | wc -l)
printf '       %s MB, %s plugins\n' "$SIZE" "$COUNT"

# --- S6: a trimmed config still starts clean ---------------------------------
#
# Disabling a plugin another one depends on shows up as a stack trace on every
# startup, not as a missing feature. Removing the whole LSP stack is exactly
# the change that can do that.
printf '\nS6  it still starts without errors\n'
OUT=$(timeout 120 nvim --headless -c 'lua print("started_ok")' -c 'qa' 2>&1)
case "$OUT" in *"started_ok"*) ok "starts" ;; *) bad "starts" "$OUT" ;; esac
case "$OUT" in
    *"E5108"*|*"stack traceback"*|*"Error executing"*) bad "no lua error on startup" "$(printf '%s' "$OUT" | head -5)" ;;
    *) ok "no lua error on startup" ;;
esac

# --- S7: every file type a server actually opens -----------------------------
#
# One fixture per kind, each carrying the constructs where regex syntax gives
# up: anchors and block scalars in yaml, heredocs and parameter expansion in
# bash, multi-stage and mounts in the Dockerfile, upstream blocks and regex
# locations in nginx.conf.
#
# `bash` is on this list for a reason. It was in neither server_parsers nor the
# parsers bundled with the binary, so on a config whose whole job is
# administering servers, shell scripts — the most common file of all — had no
# parser at all.
printf '\nS7  every file type is highlighted\n'
FIXDIR="$REPO/nvim-lite/tests/fixtures"
CHECKED=0
UNPARSED=""
TS_COUNT=0
SYN_COUNT=0

# One throwaway run first, so the loop does not measure a cold start.
timeout 120 nvim --headless \
    -c 'lua require("lazy").load({ plugins = { "nvim-treesitter" } })' \
    -c 'qa' >/dev/null 2>&1

# Three outcomes, not two.
#
# Some of these file types have no treesitter parser and never will: there is
# no grammar for systemd units, crontabs, /etc/hosts or fstab. Neovim
# highlights them with its own syntax files, and that is the correct result —
# demanding treesitter everywhere would fail them for existing.
#
# What is NOT acceptable is a file with no highlighting at all, which is what
# an undetected filetype looks like. That is how this suite found that
# nvim-lite recognised neither systemd units nor a copy of /etc/passwd or
# /etc/hosts outside their canonical paths.
for f in "$FIXDIR"/* "$FIXDIR"/.[!.]*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    rm -f /tmp/ts-res
    timeout 120 nvim --headless \
        -c 'lua require("lazy").load({ plugins = { "nvim-treesitter" } })' \
        "$f" -c 'lua
        local b = vim.api.nvim_get_current_buf()
        -- Only wait when a parser could possibly attach.
        --
        -- The wait used to be unconditional, and ten of these fixtures have no
        -- treesitter grammar at all — systemd, crontab, fstab, hosts and the
        -- rest. Each of them sat out the full ten seconds waiting for a
        -- highlighter that was never coming: 100 s of the 104 s this scenario
        -- cost, per distro, waiting on an impossibility.
        -- Ask for the FILE, not the API.
        --
        -- The first version of this guard used
        --     pcall(vim.treesitter.language.add, lang)
        -- which returns true whether or not a parser exists — it registers the
        -- mapping without loading anything. So it filtered nothing, and
        -- systemd, crontab and hosts still each sat out the full ten seconds.
        -- Measured before and after: 171 s and 172 s.
        local lang = vim.treesitter.language.get_lang(vim.bo[b].filetype)
        local have = lang and #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false) > 0
        if have then
          vim.wait(10000, function() return vim.treesitter.highlighter.active[b] ~= nil end, 100)
        end
        local fh = io.open("/tmp/ts-res", "w")
        fh:write((vim.bo[b].filetype == "" and "-" or vim.bo[b].filetype) .. " " ..
                 tostring(vim.treesitter.highlighter.active[b] ~= nil) .. " " ..
                 (vim.bo[b].syntax == "" and "-" or vim.bo[b].syntax) .. "\n")
        fh:close()
    ' -c 'qa' >/dev/null 2>&1
    res=$(cat /tmp/ts-res 2>/dev/null)
    ft=$(printf '%s' "$res" | awk '{print $1}')
    hl=$(printf '%s' "$res" | awk '{print $2}')
    syn=$(printf '%s' "$res" | awk '{print $3}')
    CHECKED=$((CHECKED + 1))
    if [ "$hl" = "true" ]; then
        printf '       %-24s %-16s treesitter\n' "$name" "$ft"
        TS_COUNT=$((TS_COUNT + 1))
    elif [ -n "$syn" ] && [ "$syn" != "-" ]; then
        printf '       %-24s %-16s vim syntax\n' "$name" "$ft"
        SYN_COUNT=$((SYN_COUNT + 1))
    else
        printf '       %-24s %-16s \033[31mNOTHING\033[0m\n' "$name" "${ft:--}"
        UNPARSED="$UNPARSED $name"
    fi
done
printf '       ---- %s treesitter, %s vim syntax, %s total\n' "$TS_COUNT" "$SYN_COUNT" "$CHECKED"
if [ -z "$UNPARSED" ]; then
    ok "all $CHECKED file types are highlighted"
else
    bad "all file types are highlighted" "no highlighting at all:$UNPARSED"
fi

# --- S8: a real terminal, not headless ---------------------------------------
#
# The scenario this suite was missing, and the one that mattered.
#
# `nvim --headless` draws nothing. An error that only happens while rendering —
# a broken 'statuscolumn', a plugin window that cannot open — never fires, so
# S6 reported "no lua error on startup" in green on a config that filled the
# screen with tracebacks the moment a human opened it. Eight distros were
# passing on a claim the suite could not actually test.
#
# util-linux's `script` gives a pty, which is the difference between running
# Neovim and running its user interface.
printf '\nS8  a real terminal session comes up clean\n'
if ! command -v script >/dev/null 2>&1; then
    bad "script(1) is available for a pty test" "install util-linux"
else
    PTYLOG=/tmp/pty.log
    rm -f "$PTYLOG"
    # Opened WITHOUT -c, and quit by typing, because that is the only form that
    # reproduces what a person sees. Driving it with `-c 'sleep' -c 'qa'`
    # swallowed the Press ENTER prompt on a session that was showing one:
    # LazyVim's news popup crashed, the screen said "Press ENTER to continue",
    # and the scripted form reported a clean run.
    # A session that MOVES, not one that opens and quits.
    #
    # Opening a single file and leaving missed two real failures: mini.ai's
    # config dies on BufReadPre, and lualine's only surfaced on :Lazy, which is
    # where lazy collects the config errors it swallowed. Both were found by
    # hand, navigating — the suite said the screen was clean.
    #
    # So: four files of different types, `-` into oil, and :Lazy at the end.
    {
        printf '\033jjjG\033'
        printf ':e %s/nginx.conf\r\033jjj' "$FIXDIR_PTY"
        printf ':e %s/cleanup.py\r\033G-\033' "$FIXDIR_PTY"
        printf ':e %s/pom.xml\r' "$FIXDIR_PTY"
        printf ':Lazy\r\033:q\r'
        # q: on purpose, and closed on purpose.
        #
        # The previous sequence closed :Lazy with a bare `q` and then typed the
        # next `:`, which together spell q: — so the command-line window opened
        # by accident and the failures it produced were half the test's doing.
        # It is a real thing to do, though, and it found a real bug: our own
        # checktime autocmd guarded on mode() == "c", which is the command LINE,
        # while q: is a normal-mode buffer where mode() returns "n". So it stays
        # — deliberately, and closed with <C-c> rather than another ambiguous q.
        printf 'q:\003'
        printf ':qa!\r'
    } | timeout 60 script -qec "nvim '$FIX'" /dev/null > "$PTYLOG" 2>&1
    # Strip the escape sequences before looking: the markers are plain text but
    # the stream around them is not.
    CLEAN=$(sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\x1b\][^\x07]*\x07//g' "$PTYLOG" 2>/dev/null)
    # The markers are deliberately broad. The first list was written from the
    # shape of the bug in front of me — E5108, "invalid key" — and then missed
    # the next one entirely, whose text was
    #     Error executing vim.schedule lua callback: ... attempt to index
    #     global 'Snacks' (a nil value)
    # The word "Snacks" was right there in the captured output and not one
    # marker matched it. A screen with any error on it is a failure; the
    # specific wording is not something to guess in advance.
    found=""
    for marker in "E5108" "E5113" "Error executing" "stack traceback" \
                  "attempt to index" "attempt to call" "invalid key" \
                  "not found:" "Press ENTER"; do
        case "$CLEAN" in *"$marker"*) found="$found [$marker]" ;; esac
    done
    if [ -z "$found" ]; then
        ok "no errors on screen in a real terminal"
    else
        bad "no errors on screen in a real terminal" "saw:$found"
        printf '%s' "$CLEAN" | grep -aoE 'E5108[^|]{0,80}|module .[a-z.]+. not found' | head -3 | sed 's/^/         /'
    fi
fi

# --- S9: pressing `-` actually opens oil -------------------------------------
#
# The keymap being registered proves nothing, and that mistake was made here:
# `maparg("-", "n")` returned `<Cmd>Oil<CR>` on a machine where oil had never
# initialised. This spec defines the mapping, so it exists whether or not the
# plugin behind it loaded — and oil's setup() on master begins with
#     if vim.fn.has("nvim-0.10") == 0 then ... return end
# so on Neovim 0.9 it printed an error (naming the wrong plugin, "aerial",
# shared boilerplate from the same author) and returned without registering
# :Oil at all. Pinned to oil's own nvim-0.9 branch there.
#
# So the check presses the key and asks what the buffer became.
printf '\nS9  pressing - opens oil\n'
printf '\033-' > /tmp/keys
printf ':lua io.open("/tmp/oilres","w"):write(vim.bo.filetype):close()\r' >> /tmp/keys
printf ':qa!\r' >> /tmp/keys
rm -f /tmp/oilres
timeout 45 script -qec "nvim '$FIX'" /dev/null < /tmp/keys >/dev/null 2>&1
OILFT=$(cat /tmp/oilres 2>/dev/null)
if [ "$OILFT" = "oil" ]; then
    ok "the buffer becomes an oil buffer"
else
    bad "the buffer becomes an oil buffer" "filetype is '${OILFT:-nothing}'"
fi
printf '       oil branch: %s\n' "$(git -C ~/.local/share/nvim/lazy/oil.nvim rev-parse --abbrev-ref HEAD 2>/dev/null)"

# --- S10: the config says what it is -----------------------------------------
#
# This is a LazyVim distribution but it is NOT stock LazyVim, and on a server
# you should be able to tell which one you just opened, and which revision.
#
# The interesting half is Neovim 0.9. snacks.dashboard is switched off there
# (it cannot open a window without flooding the screen — see plugins/ui.lua),
# so the branding would exist on seven distros and silently not on Debian 10,
# which is the machine where you are least sure what you are looking at.
# config/branding.lua draws the same banner into the start buffer instead.
#
# So the check is deliberately blind to WHICH path drew it: open nvim with no
# arguments in a pty, and require the name and the version to be on the screen.
# One assertion, both branches, and it fails on whichever one breaks.
printf '\nS10 the banner names the config and its version\n'
WANT_VER=$(cat "$REPO/nvim-lite/VERSION" 2>/dev/null | tr -d '[:space:]')

GOT_VER=$(nvim --headless -c 'LiteVersion' -c 'qa' 2>&1 | tr -d '\r')
case "$GOT_VER" in
    *"nvim-lite v$WANT_VER"*) ok ":LiteVersion reports v$WANT_VER" ;;
    *) bad ":LiteVersion reports v$WANT_VER" "said: ${GOT_VER:-nothing}" ;;
esac

if ! command -v script >/dev/null 2>&1; then
    bad "script(1) is available for the banner test" "install util-linux"
else
    BANLOG=/tmp/banner.log
    rm -f "$BANLOG"
    # No file argument on purpose: that is the only way either start screen is
    # drawn at all.
    printf ':qa!\r' | timeout 45 script -qec "nvim" /dev/null > "$BANLOG" 2>&1
    BAN=$(sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\x1b\][^\x07]*\x07//g' "$BANLOG" 2>/dev/null)

    case "$BAN" in
        *"n v i m - l i t e"*) ok "the start screen names nvim-lite" ;;
        *) bad "the start screen names nvim-lite" "not on screen" ;;
    esac

    case "$BAN" in
        *"v$WANT_VER"*) ok "the start screen shows v$WANT_VER" ;;
        *) bad "the start screen shows v$WANT_VER" "not on screen" ;;
    esac

    # The 0.9 fallback writes into a buffer rather than calling vim.notify, and
    # this is the assertion that keeps it that way. A banner this tall sent
    # through the message area triggers "Press ENTER or type command to
    # continue" before every single start — the same trap that config/lazy.lua
    # already carries a comment about, one floor down.
    case "$BAN" in
        *"Press ENTER"*) bad "the banner does not force a keypress" "screen said Press ENTER" ;;
        *) ok "the banner does not force a keypress" ;;
    esac
fi

# --- S12: picking a project opens the project --------------------------------
#
# snacks' default action for its projects section is `chdir` followed by
# M.pick(), which drops you into a fuzzy finder over the whole repo — 268
# entries on this one — before you have said what you are looking for. Picking
# a project is already an answer; being asked a second question is not what it
# meant. It also disagreed with the Neovim 0.9 path, which changes directory
# and shows the directory.
#
# Key `1` is the first project on both generations: snacks assigns it via
# autokey, and the 0.9 screen numbers its own entries the same way.
printf '\nS12 picking a project changes directory and opens it\n'
rm -f /tmp/after.txt /tmp/keys
printf '1' > /tmp/keys
printf ':lua vim.defer_fn(function() local f=io.open("/tmp/after.txt","w") f:write(vim.fn.getcwd().."|"..vim.bo.filetype) f:close() vim.cmd("qa!") end, 900)\r' >> /tmp/keys
timeout 60 script -qec "nvim" /dev/null < /tmp/keys >/dev/null 2>&1
AFTER=$(cat /tmp/after.txt 2>/dev/null)
CWD=${AFTER%%|*}
FT=${AFTER##*|}
if [ "$CWD" = "$REPO" ]; then
    ok "the working directory follows the project"
else
    bad "the working directory follows the project" "cwd is '${CWD:-nothing}', expected $REPO"
fi
case "$FT" in
    oil) ok "it lands in the project, not in a picker" ;;
    *)   bad "it lands in the project, not in a picker" "filetype is '${FT:-nothing}'" ;;
esac

# --- S11: there is a way back ------------------------------------------------
#
# The start buffer is `bufhidden = wipe`, so opening a file destroys it. That
# is deliberate — a stale dashboard in the buffer list is worse than none — but
# it left no way back, and nothing said so: the screen simply never returned
# and you would not think to look for a command that had never existed.
#
# Driven through a pty because on 0.10+ snacks does not open its dashboard
# headless at all, so a headless check would pass by drawing nothing and
# finding nothing missing.
printf '\nS11 you can leave the start screen and come back\n'
cat > /tmp/rt.lua <<'LUA'
local function home()
  local ft = vim.bo.filetype
  return ft == "nvimlite_start" or ft == "snacks_dashboard"
end
local log = {}
vim.defer_fn(function()
  -- vim.wait on the condition, not a fixed delay. A 900 ms defer passed on six
  -- distros and failed on the two running Neovim 0.10.3, where snacks takes
  -- longer to open its window: the check was racing the thing it measured.
  local got = vim.wait(8000, home, 100)
  log[#log + 1] = "start=" .. tostring(got) .. "[" .. vim.bo.filetype .. "]"
  vim.cmd.edit(vim.fn.stdpath("config") .. "/VERSION")
  log[#log + 1] = "left=" .. tostring(home())
  pcall(require("config.branding").open)
  log[#log + 1] = "back=" .. tostring(vim.wait(8000, home, 100))
  local fh = io.open("/tmp/rt.txt", "w")
  fh:write(table.concat(log, " "))
  fh:close()
  vim.cmd("qa!")
end, 300)
LUA
rm -f /tmp/rt.txt
timeout 60 script -qec "nvim -c 'luafile /tmp/rt.lua'" /dev/null >/dev/null 2>&1
RT=$(cat /tmp/rt.txt 2>/dev/null)
case "$RT" in
    *"start=true"*) ok "the start screen comes up" ;;
    *) bad "the start screen comes up" "got: ${RT:-nothing}" ;;
esac
case "$RT" in
    *"left=false"*) ok "opening a file leaves it" ;;
    *) bad "opening a file leaves it" "got: ${RT:-nothing}" ;;
esac
case "$RT" in
    *"back=true"*) ok "you can come back to it" ;;
    *) bad "you can come back to it" "got: ${RT:-nothing}" ;;
esac

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$ID$VERSION_ID")" "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
