-- nvim-lite's own identity: a name, a version, and a banner that survives
-- Neovim 0.9.
--
-- This config is a LazyVim distribution, but it is not stock LazyVim: it ships
-- 23 plugins instead of 37, a compat shim, its own filetype detection and a
-- curated parser list. When you open it on a server you should be able to tell
-- WHICH of those you are looking at, and which revision of it.
--
-- The version lives in a plain-text VERSION file at the root of this config,
-- not in this Lua module, because the installer needs to read it too and
-- `$(<VERSION)` beats parsing Lua from shell.

local M = {}

local cached_version

--- Read the version string from the VERSION file next to this config.
--- Returns "unknown" if the file is missing (e.g. a partial copy install).
function M.version()
  if cached_version then
    return cached_version
  end

  local path = vim.fn.stdpath("config") .. "/VERSION"
  local ok, lines = pcall(vim.fn.readfile, path, "", 1)
  if ok and type(lines) == "table" and lines[1] then
    cached_version = vim.trim(lines[1])
  end
  if cached_version == nil or cached_version == "" then
    cached_version = "unknown"
  end

  return cached_version
end

--- "0.11.4" — vim.version() returns a table, and its tostring() is not stable
--- across the Neovim versions this config supports.
function M.nvim_version()
  local v = vim.version()
  return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

-- The tree is the same one this config has always used, redrawn at 14 columns
-- instead of 34.
--
-- Height is the whole point. A server is an SSH session on a 24-line terminal,
-- and the full-size banner is 17 lines: with the keymap list under it the
-- dashboard did not fit, so the top of the logo scrolled off before you could
-- read it. Eight lines leaves room for the banner AND the keys.
local TREE = {
  "      ░░      ",
  "    ░░░░░░    ",
  "  ░░░░▒▒░░░░  ",
  " ░░░░▒▒▒▒░░░░ ",
  "░░░▒▒▒░░▒▒▒░░░",
  "▒▒▒░░▒▒▒▒░░▒▒▒",
  "██████████████",
  "▓▓▓▓▓▓▓▓▓▓▓▓▓▓",
}

-- Block Elements (U+2588..U+2593) and Box Drawing (U+2500), NOT Nerd Font.
-- They render on a bare Debian console with no patched font installed, which
-- is where this config actually runs. Nerd Font glyphs are used elsewhere in
-- this config, but never in the banner: a server you SSH into for the first
-- time has no font you chose.

--- The banner, as a list of lines: tree on the left, identity on the right.
--- @param extra string|nil  a fourth text line (used by the 0.9 fallback)
function M.lines(extra)
  local text = {
    "n v i m - l i t e",
    "─────────────────────────",
    "BV ARCH-CODE  ·  v" .. M.version(),
    "nvim " .. M.nvim_version(),
  }
  if extra then
    text[#text] = text[#text] .. "  ·  " .. extra
  end

  local out = {}
  for i, tree_line in ipairs(TREE) do
    -- The text block sits vertically centred against the tree: 8 tree lines,
    -- 4 text lines, so the text starts on line 3.
    local t = text[i - 2]
    out[i] = t and (tree_line .. "    " .. t) or tree_line
  end

  return out
end

--- The banner as a single string, for snacks.dashboard's `header`.
function M.header()
  return table.concat(M.lines(), "\n")
end

--- Draw the banner into the empty start buffer.
---
--- This exists for Neovim 0.9 only. snacks.dashboard cannot open a window
--- there — it calls nvim_get_hl with the `create` option that arrived in 0.10
--- — so on Debian 10 the branding would simply not exist, on the one machine
--- where knowing what you just opened matters most.
---
--- Writing into the start buffer costs no plugin and no dependency. What it
--- must NOT do is use vim.notify: with snacks' notifier off, notify falls back
--- to the message area, and a banner this tall triggers "Press ENTER or type
--- command to continue" before every single start. That mistake is already
--- documented in config/lazy.lua; this is the same trap one floor down.
function M.draw_fallback()
  -- Only when Neovim was started with nothing to show: no file arguments, no
  -- stdin pipe, and the current buffer untouched and unnamed.
  if vim.fn.argc(-1) > 0 then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) ~= "" then
    return
  end
  if vim.api.nvim_buf_line_count(buf) > 1 or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= "" then
    return
  end

  local stats = ""
  local ok, lazy = pcall(require, "lazy")
  if ok then
    stats = lazy.stats().count .. " plugins"
  end

  local lines = M.lines(stats ~= "" and stats or nil)
  vim.list_extend(lines, {
    "",
    "    -  files      i  new      :q  quit",
  })

  -- Trailing whitespace has to go before anything is measured or drawn.
  -- The tree lines are padded to a fixed 14 columns so the text column lines
  -- up, and LazyVim leaves 'list' on with Neovim's default listchars, whose
  -- `trail:-` turned every one of those pad spaces into a dash:
  --     ░░------                      ░░░░░░----
  -- snacks never shows this because it renders into its own buffer with list
  -- off; this fallback writes into an ordinary one and inherits the setting.
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("%s+$", "")
  end

  -- Centre horizontally against the window, so it does not hug the left edge
  -- on a wide terminal.
  local width = vim.api.nvim_win_get_width(0)
  local longest = 0
  for _, line in ipairs(lines) do
    longest = math.max(longest, vim.fn.strdisplaywidth(line))
  end
  local pad = string.rep(" ", math.max(0, math.floor((width - longest) / 2)))
  for i, line in ipairs(lines) do
    lines[i] = pad .. line
  end

  -- And vertically.
  local height = vim.api.nvim_win_get_height(0)
  local top = math.max(0, math.floor((height - #lines) / 2) - 1)
  for _ = 1, top do
    table.insert(lines, 1, "")
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "nvimlite_start"

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = false
  vim.wo.statuscolumn = ""
  vim.wo.list = false

  -- `i` has to be remapped: the buffer is nomodifiable, so plain `i` would
  -- just beep at you.
  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end
  map("i", "<cmd>enew | startinsert<cr>")
  map("-", "<cmd>Oil<cr>")
end

--- Register `:LiteVersion` and, on Neovim 0.9 only, the start-screen fallback.
function M.setup()
  vim.api.nvim_create_user_command("LiteVersion", function()
    print(("nvim-lite v%s  ·  nvim %s"):format(M.version(), M.nvim_version()))
  end, { desc = "Show the nvim-lite and Neovim versions" })

  -- On 0.10+ snacks.dashboard draws the banner (see plugins/ui.lua) and this
  -- would fight it for the same buffer.
  if vim.fn.has("nvim-0.10") == 1 then
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("nvim_lite_branding", { clear = true }),
    once = true,
    callback = function()
      pcall(M.draw_fallback)
    end,
  })
end

return M
