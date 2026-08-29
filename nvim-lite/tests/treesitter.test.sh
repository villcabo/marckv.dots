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
printf '\nS2  a headless start installs the yaml parser\n'
timeout 900 nvim --headless "+Lazy! sync" +qa >/tmp/lazy.log 2>&1
timeout 900 nvim --headless \
    -c 'lua require("lazy").load({ plugins = { "nvim-treesitter" } })' \
    -c 'sleep 60' -c 'qa' >/tmp/tsload.log 2>&1

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

printf '\n---- %s: %d ok, %d failed ----\n' "$(. /etc/os-release; echo "$ID$VERSION_ID")" "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
