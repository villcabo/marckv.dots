-- nvim-lite's identity: the bolt, a version, and a start screen that works on
-- Neovim 0.9.
--
-- The version lives in a plain-text VERSION file at the root of this config,
-- not in this module, because the installer reads it too and `$(<VERSION)`
-- beats parsing Lua from a shell script.

local M = {}

local cached_version

--- Read the version from the VERSION file next to this config.
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

--- "0.11.4" — vim.version() returns a table whose tostring() is not stable
--- across the Neovim versions this config supports.
function M.nvim_version()
  local v = vim.version()
  return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

-- Eight steps from white-hot to spent ember.
--
-- The colour is not decoration here, it is the whole logo. A terminal has no
-- curves and no resolution, so a gradient is the only way to give a flat block
-- shape any volume — the first version of this bolt was a single colour and
-- read as a zigzag rather than as energy. Eight steps and not three, because
-- with fewer the banding shows.
local RAMP = {
  "#fffbe8", -- 1  white hot
  "#ffeeb0", -- 2
  "#ffd166", -- 3
  "#ffa066", -- 4
  "#f2703f", -- 5
  "#d4453c", -- 6
  "#8f2b2b", -- 7
  "#4d1f1f", -- 8  spent
}

-- Each row is a list of {text, ramp-level} segments.
--
-- The bolt strikes and lands: sparks opening outward and a ground line that
-- fades at both ends. That last part is what makes it a moment instead of a
-- shape — and the ground line doubles as a visual base, so the block sits on
-- something instead of floating.
local BOLT = {
  { { "        ▄███▛", 1 } },
  { { "      ▄███▛", 1 } },
  { { "    ▄███▛", 2 } },
  { { "  ▄█████████▙", 3 } },
  { { "  ▀▀▀▀▀", 4 }, { "▄███▛", 4 } },
  { { "      ▄███▛", 5 } },
  { { "    ▄███▛", 6 } },
  { { "  ▄███▛", 6 } },
  { { " ▀▀▀", 7 } },
  { { "  ╲", 8 }, { "    ╲", 7 }, { "   │", 6 }, { "   ╱", 7 }, { "    ╱", 8 } },
  { { "▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂", 8 } },
}

local HL_PREFIX = "NvimLiteBolt"

--- Define NvimLiteBolt1..8 plus the two text groups.
---
--- Re-applied on ColorScheme: loading a colorscheme clears every highlight
--- group, and the dashboard is drawn before LazyVim finishes setting one on
--- some machines. Without this the bolt came up grey exactly once, on the
--- first start after an install, which is the one start that matters.
function M.setup_highlights()
  for i, colour in ipairs(RAMP) do
    vim.api.nvim_set_hl(0, HL_PREFIX .. i, { fg = colour })
  end
  vim.api.nvim_set_hl(0, "NvimLiteName", { fg = "#e6c384", bold = true })
  vim.api.nvim_set_hl(0, "NvimLiteMuted", { fg = "#727169" })
  vim.api.nvim_set_hl(0, "NvimLiteKey", { fg = "#ffa066", bold = true })
  vim.api.nvim_set_hl(0, "NvimLitePath", { fg = "#dcd7ba" })
end

--- The bolt as plain lines, no colour. Used for width maths and for snacks,
--- which paints the header itself.
function M.bolt_lines()
  local out = {}
  for i, row in ipairs(BOLT) do
    local parts = {}
    for _, seg in ipairs(row) do
      parts[#parts + 1] = seg[1]
    end
    out[i] = table.concat(parts)
  end
  return out
end

--- The bolt for snacks.dashboard, as coloured text fragments.
---
--- snacks paints a `header` string with a single highlight group, which would
--- throw away the gradient that IS the logo. A `text` section takes fragments
--- with their own groups, so the ramp survives on 0.10+ and matches what the
--- 0.9 fallback draws by hand. One source, two renderers.
function M.snacks_text()
  M.setup_highlights()
  local out = {}
  for _, row in ipairs(BOLT) do
    for _, seg in ipairs(row) do
      out[#out + 1] = { seg[1], hl = HL_PREFIX .. seg[2] }
    end
    out[#out + 1] = { "\n" }
  end
  out[#out + 1] = { "\n" }
  out[#out + 1] = { "n v i m - l i t e", hl = "NvimLiteName" }
  out[#out + 1] = { "   ·   v" .. M.version(), hl = "NvimLiteMuted" }
  out[#out + 1] = { "\n" }
  return out
end

--- The most recent files, as {shortened, full} pairs.
---
--- vim.v.oldfiles is populated from shada and needs no plugin, which is the
--- point: this has to work on Debian 10 where the dashboard plugin is off.
--- Entries are filtered because oldfiles keeps paths long after the file is
--- gone, and offering a dead path as choice 1 is worse than offering nothing.
local function recent_files(limit)
  local out = {}
  for _, path in ipairs(vim.v.oldfiles or {}) do
    if vim.fn.filereadable(path) == 1 then
      local short = vim.fn.fnamemodify(path, ":~")
      if #short > 44 then
        short = "…" .. short:sub(-43)
      end
      out[#out + 1] = { short, path }
      if #out >= limit then
        break
      end
    end
  end
  return out
end

M.recent_files = recent_files

--- Draw the start screen into the empty buffer.
---
--- This exists for Neovim 0.9. snacks.dashboard cannot open a window there —
--- it calls nvim_get_hl with the `create` option that arrived in 0.10 — so
--- without this the branding would exist on seven distros and silently not on
--- Debian 10, the machine where you are least sure what you just opened.
---
--- What it must NOT do is call vim.notify: with snacks' notifier off, notify
--- falls back to the message area, and a banner this tall triggers "Press
--- ENTER or type command to continue" before every single start. That trap is
--- already documented in config/lazy.lua; this is the same one a floor down.
function M.draw_fallback()
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

  M.setup_highlights()

  local plugins = ""
  local ok, lazy = pcall(require, "lazy")
  if ok then
    plugins = "  ·  " .. lazy.stats().count .. " plugins"
  end

  -- Build rows as {text, highlight} segment lists, so the bolt keeps its
  -- gradient and the text column keeps its own groups.
  local rows = {}
  local info = {
    { { "n v i m - l i t e", "NvimLiteName" } },
    { { "v" .. M.version() .. "  ·  nvim " .. M.nvim_version() .. plugins, "NvimLiteMuted" } },
  }

  local bolt = M.bolt_lines()
  local bolt_width = 0
  for _, line in ipairs(bolt) do
    bolt_width = math.max(bolt_width, vim.fn.strdisplaywidth(line))
  end

  for i, row in ipairs(BOLT) do
    local segs = {}
    for _, seg in ipairs(row) do
      segs[#segs + 1] = { seg[1], HL_PREFIX .. seg[2] }
    end
    -- The text column sits beside the bolt's upper half.
    local right = info[i - 1]
    if right then
      local pad = bolt_width - vim.fn.strdisplaywidth(bolt[i]) + 4
      segs[#segs + 1] = { string.rep(" ", pad), "NvimLiteMuted" }
      for _, seg in ipairs(right) do
        segs[#segs + 1] = seg
      end
    end
    rows[#rows + 1] = segs
  end

  local recent = recent_files(5)
  if #recent > 0 then
    rows[#rows + 1] = {}
    for i, entry in ipairs(recent) do
      rows[#rows + 1] = {
        { "  " .. i .. "  ", "NvimLiteKey" },
        { entry[1], "NvimLitePath" },
      }
    end
  end
  rows[#rows + 1] = {}
  rows[#rows + 1] = {
    { "  -", "NvimLiteKey" },
    { " archivos   ", "NvimLiteMuted" },
    { "e", "NvimLiteKey" },
    { " nuevo   ", "NvimLiteMuted" },
    { ":q", "NvimLiteKey" },
    { " salir", "NvimLiteMuted" },
  }

  -- Centre horizontally. Trailing whitespace goes first: LazyVim leaves 'list'
  -- on with Neovim's default listchars, whose `trail:-` turned every pad space
  -- into a dash — snacks never shows this because it renders into its own
  -- buffer with list off, and this one writes into an ordinary buffer.
  local text, longest = {}, 0
  for i, segs in ipairs(rows) do
    local parts = {}
    for _, seg in ipairs(segs) do
      parts[#parts + 1] = seg[1]
    end
    text[i] = (table.concat(parts):gsub("%s+$", ""))
    longest = math.max(longest, vim.fn.strdisplaywidth(text[i]))
  end

  local width = vim.api.nvim_win_get_width(0)
  local left = math.max(0, math.floor((width - longest) / 2))
  local pad = string.rep(" ", left)

  local height = vim.api.nvim_win_get_height(0)
  local top = math.max(0, math.floor((height - #text) / 2) - 1)

  local out = {}
  for _ = 1, top do
    out[#out + 1] = ""
  end
  for _, line in ipairs(text) do
    out[#out + 1] = line == "" and "" or (pad .. line)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)

  -- Highlights go on by byte offset, so the column has to be counted in bytes.
  -- The bolt is built from multi-byte block characters: using string length in
  -- characters puts every highlight in the wrong place from the second segment
  -- onwards.
  for i, segs in ipairs(rows) do
    local col = #pad
    for _, seg in ipairs(segs) do
      local len = #seg[1]
      if seg[2] and len > 0 then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, seg[2], top + i - 1, col, col + len)
      end
      col = col + len
    end
  end

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

  -- `e` rather than `i`: the buffer is nomodifiable, so a plain `i` would only
  -- beep. The digits open the file they point at.
  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end
  map("e", "<cmd>enew | startinsert<cr>")
  map("-", "<cmd>Oil<cr>")
  for i, entry in ipairs(recent) do
    map(tostring(i), function()
      vim.cmd.edit(vim.fn.fnameescape(entry[2]))
    end)
  end
end

--- Register `:LiteVersion` and, on Neovim 0.9 only, the start screen.
function M.setup()
  vim.api.nvim_create_user_command("LiteVersion", function()
    print(("nvim-lite v%s  ·  nvim %s"):format(M.version(), M.nvim_version()))
  end, { desc = "Show the nvim-lite and Neovim versions" })

  local group = vim.api.nvim_create_augroup("nvim_lite_branding", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = M.setup_highlights,
  })
  M.setup_highlights()

  -- On 0.10+ snacks.dashboard draws the banner (see plugins/ui.lua) and this
  -- would fight it for the same buffer.
  if vim.fn.has("nvim-0.10") == 1 then
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      pcall(M.draw_fallback)
    end,
  })
end

return M
