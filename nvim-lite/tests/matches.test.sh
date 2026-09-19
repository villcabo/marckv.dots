#!/bin/bash
# Scenarios for the window matches in config/autocmds.lua.
#
#   ./matches.test.sh
#
# Runs on the HOST, unlike the treesitter suite next to it: nothing here needs
# plugins, parsers or a container. `nvim -u NONE` loads the autocmds file on
# its own, which is the whole point — these are assertions about the config,
# not about the machine it lands on.
#
# What is under test is that a set of matches is TAKEN BACK before the next one
# goes in. matchadd() attaches to the window rather than the buffer and nothing
# clears it, so the FileType autocmd used to stack a fresh set on every log
# opened in the same split. They all kept being evaluated on every redraw, and
# they outlived the buffer that justified them.
#
# The symptom that led here: an `nvim --embed` left open on a proxy host for 24
# days over a directory of .conf and .log files reached 2.5 GB RSS, all heap,
# with no language server attached — two thirds of that machine's memory.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AUTOCMDS_FILE="${TESTS_DIR}/../lua/config/autocmds.lua"
OPTIONS_FILE="${TESTS_DIR}/../lua/config/options.lua"
PASS=0
FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; FAIL=$((FAIL + 1)); }

command -v nvim >/dev/null 2>&1 || { bad "Neovim is on PATH"; exit 1; }
printf '\n=== window matches  (%s) ===\n' "$(nvim --version | head -1)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf '2024-01-15 10:00:00 [ERROR] connection refused from 10.0.0.1\n' > "$TMP/a.log"
cp "$TMP/a.log" "$TMP/b.log"
cp "$TMP/a.log" "$TMP/c.log"

# --- S1: three logs in one window do not stack three sets of matches --------
#
# Counting is the assertion, not eyeballing the highlight: the colours look
# identical either way, which is exactly why this went unnoticed for so long.
cat > "$TMP/count.lua" <<'LUA'
dofile(vim.env.AUTOCMDS_FILE)
local counts = {}
for _, f in ipairs({ vim.env.LOG_A, vim.env.LOG_B, vim.env.LOG_C }) do
  vim.cmd.edit(f)
  vim.bo.filetype = "log"
  counts[#counts + 1] = #vim.fn.getmatches()
end
io.stderr:write(table.concat(counts, " ") .. "\n")
vim.cmd("qa!")
LUA

COUNTS=$(LOG_A="$TMP/a.log" LOG_B="$TMP/b.log" LOG_C="$TMP/c.log" \
    nvim --headless -u NONE -l "$TMP/count.lua" 2>&1 | tr -d '\r')
read -r C1 C2 C3 <<< "$COUNTS"

if [ -z "${C1:-}" ]; then
    bad "the log filetype registers matches" "no counts came back: $COUNTS"
elif [ "$C1" -eq 0 ]; then
    bad "the log filetype registers matches" "got 0 on the first file"
elif [ "$C1" = "$C2" ] && [ "$C2" = "$C3" ]; then
    ok "three logs in one window stay at $C1 matches"
else
    bad "three logs in one window do not stack matches" "got $C1 -> $C2 -> $C3 (a leak: each visit adds a full set)"
fi

# --- S2: leaving the buffer takes the matches with it -----------------------
#
# A window that moved on to something else should not still be matching log
# timestamps. BufWinLeave is what retires them.
cat > "$TMP/leave.lua" <<'LUA'
dofile(vim.env.AUTOCMDS_FILE)
vim.cmd.edit(vim.env.LOG_A)
vim.bo.filetype = "log"
local during = #vim.fn.getmatches()
vim.cmd.edit(vim.env.PLAIN)
vim.bo.filetype = "lua"
io.stderr:write(during .. " " .. #vim.fn.getmatches() .. "\n")
vim.cmd("qa!")
LUA
printf 'local x = 1\n' > "$TMP/plain.lua"

LEFT=$(LOG_A="$TMP/a.log" PLAIN="$TMP/plain.lua" \
    nvim --headless -u NONE -l "$TMP/leave.lua" 2>&1 | tr -d '\r')
read -r DURING AFTER <<< "$LEFT"

if [ -z "${AFTER:-}" ]; then
    bad "matches are dropped on BufWinLeave" "no counts came back: $LEFT"
elif [ "$AFTER" -eq 0 ]; then
    ok "moving off the log drops all $DURING matches"
else
    bad "matches are dropped on BufWinLeave" "$AFTER still active after switching to a lua file"
fi

# --- S3: terminal scrollback is capped ---------------------------------------
#
# The default is 10000 lines held in memory for the life of the buffer. On a
# server a :terminal is usually pointed at something that never stops printing,
# and the buffer is the thing that grows.
SB=$(grep -oE '^vim\.o\.scrollback[[:space:]]*=[[:space:]]*[0-9]+' "$OPTIONS_FILE" | grep -oE '[0-9]+$')
if [ -z "${SB:-}" ]; then
    bad "options.lua caps the terminal scrollback" "no vim.o.scrollback found"
elif [ "$SB" -lt 10000 ]; then
    ok "terminal scrollback capped at $SB lines"
else
    bad "options.lua caps the terminal scrollback" "set to $SB, at or above the 10000 default"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf '\033[1;32mall %d scenarios passed\033[0m\n' "$PASS"
else
    printf '\033[1;31m%d of %d scenarios failed\033[0m\n' "$FAIL" "$((PASS + FAIL))"
fi
exit "$FAIL"
