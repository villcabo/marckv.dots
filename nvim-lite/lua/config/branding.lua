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

-- Three sizes, picked from the terminal width at draw time.
--
-- One fixed size cannot work: the same 25-column bolt that fills a 80-column
-- SSH session is a stamp in the corner of a 140-column one. Each row is a list
-- of {text, ramp-level} segments; the ramp is stretched across however many
-- rows the chosen size has, so a taller bolt gets a smoother gradient rather
-- than the same eight bands scaled up.
--
-- The bolt strikes and lands: sparks opening outward and a ground line that
-- fades at both ends. That last part is what makes it a moment instead of a
-- shape, and the ground line doubles as a base so the block sits on something
-- instead of floating.

-- All three keep the SAME slope: two columns of travel per row. Only the limb
-- gets thicker and the bolt taller.
--
-- The first attempt at a large bolt scaled the horizontal step as well — four
-- columns per row instead of two — and the diagonals came out nearly flat. A
-- bolt that is not steep stops reading as a bolt: it turns into a Z with a
-- bar through it, and the crossbar, scaled to match, looked like it had been
-- driven through the middle of the shape. Thicker limbs give the size back
-- without touching the angle.

local BOLT_S = {
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

local BOLT_M = {
  { { "            ▄███████▛", 1 } },
  { { "          ▄███████▛", 1 } },
  { { "        ▄███████▛", 2 } },
  { { "      ▄███████▛", 2 } },
  { { "    ▄███████▛", 3 } },
  { { "  ▄███████████████▙", 4 } },
  { { "  ▀▀▀▀▀▀▀▀", 5 }, { "▄███████▛", 5 } },
  { { "        ▄███████▛", 6 } },
  { { "      ▄███████▛", 6 } },
  { { "    ▄███████▛", 7 } },
  { { "  ▄███████▛", 7 } },
  { { "  ▀▀▀▀", 8 } },
  { { "   ╲", 8 }, { "     ╲", 7 }, { "     │", 6 }, { "     ╱", 7 }, { "     ╱", 8 } },
  { { "▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂", 8 } },
}

local BOLT_L = {
  { { "                ▄█████████████▛", 1 } },
  { { "              ▄█████████████▛", 1 } },
  { { "            ▄█████████████▛", 2 } },
  { { "          ▄█████████████▛", 2 } },
  { { "        ▄█████████████▛", 3 } },
  { { "      ▄█████████████▛", 3 } },
  { { "    ▄█████████████▛", 4 } },
  { { "  ▄███████████████████████▙", 4 } },
  { { "  ▀▀▀▀▀▀▀▀▀▀▀▀", 5 }, { "▄█████████████▛", 5 } },
  { { "            ▄█████████████▛", 6 } },
  { { "          ▄█████████████▛", 6 } },
  { { "        ▄█████████████▛", 7 } },
  { { "      ▄█████████████▛", 7 } },
  { { "    ▄█████████████▛", 8 } },
  { { "  ▄█████████████▛", 8 } },
  { { "  ▀▀▀▀▀▀▀", 8 } },
  { { "   ╲", 8 }, { "       ╲", 7 }, { "       │", 6 }, { "       ╱", 7 }, { "       ╱", 8 } },
  { { "▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂", 8 } },
}

--- Pick a bolt and a layout for the terminal it is about to be drawn in.
---
--- Returns the bolt table and true when the lists should sit BESIDE it.
---
--- The two-column layout is the whole reason the big bolt is usable. A real
--- terminal window is wide and short — measured on the machine this was built
--- for, roughly 140 columns by 32 rows — and the 17-row bolt stacked on top of
--- three sections needs about 34 rows, so it never fits. Turned sideways it
--- needs 103 columns and 17 rows, and 103 of 140 is width nobody was using.
function M.layout(cols, rows)
  cols = cols or vim.o.columns
  rows = rows or vim.o.lines

  -- Beside: the bolt's own height is the whole budget, and the lists have to
  -- fit inside it rather than under it.
  if cols >= 104 and rows >= 20 then
    return BOLT_L, true
  end
  if cols >= 88 and rows >= 18 then
    return BOLT_M, true
  end

  -- Stacked: every row the bolt takes is a row the lists do not get, so the
  -- bolt only grows when there is height to spare.
  if rows >= 40 then
    return BOLT_M, false
  end
  return BOLT_S, false
end

--- Backwards-compatible shim: snacks only ever needs the bolt.
function M.bolt(cols, rows)
  local bolt = M.layout(cols, rows)
  return bolt
end

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
  vim.api.nvim_set_hl(0, "NvimLiteTitle", { fg = "#7aa89f", bold = true })
end

--- The bolt as plain lines, no colour. Used for width maths and for snacks,
--- which paints the header itself.
function M.bolt_lines(bolt)
  local out = {}
  for i, row in ipairs(bolt or M.bolt()) do
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
  local bolt = M.bolt()

  -- Every line is padded to the same width first.
  --
  -- snacks centres each LINE on its own, not the block, so lines of different
  -- lengths get different left offsets — and a bolt is a shape whose silhouette
  -- depends entirely on absolute alignment. The closing `▀▀▀▀▀▀▀` came out four
  -- columns right of the limb it closes, which reads as a printing error.
  -- Padding to a common width makes every line the same length, so centring
  -- moves all of them by the same amount and the shape survives.
  local width = 0
  for _, row in ipairs(bolt) do
    local w = 0
    for _, seg in ipairs(row) do
      w = w + vim.fn.strdisplaywidth(seg[1])
    end
    width = math.max(width, w)
  end

  local out = {}
  for _, row in ipairs(bolt) do
    local w = 0
    for _, seg in ipairs(row) do
      out[#out + 1] = { seg[1], hl = HL_PREFIX .. seg[2] }
      w = w + vim.fn.strdisplaywidth(seg[1])
    end
    if w < width then
      out[#out + 1] = { string.rep(" ", width - w) }
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

--- Recent project roots, derived from the file history.
---
--- snacks has a `projects` section; on Neovim 0.9 snacks is closed, so this
--- walks up from each recent file to the nearest .git and collects the unique
--- roots. Directories are cached because oldfiles holds many files from the
--- same project and the upward walk is the only part with any cost.
local function projects(limit)
  local seen_dir, seen_root, out = {}, {}, {}
  for _, path in ipairs(vim.v.oldfiles or {}) do
    if vim.fn.filereadable(path) == 1 then
      local dir = vim.fn.fnamemodify(path, ":h")
      local root = seen_dir[dir]
      if root == nil then
        local found = vim.fs.find(".git", { path = dir, upward = true, limit = 1 })
        root = found[1] and vim.fs.dirname(found[1]) or false
        seen_dir[dir] = root
      end
      if root and not seen_root[root] then
        seen_root[root] = true
        out[#out + 1] = { vim.fn.fnamemodify(root, ":~"), root }
        if #out >= limit then
          break
        end
      end
    end
  end
  return out
end

M.projects = projects


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
--- Draw into the current buffer, no questions asked. `draw_fallback` adds the
--- start-up guards; `M.open()` reopens the screen later, when none apply.
function M.draw()
  local buf = vim.api.nvim_get_current_buf()
  M.setup_highlights()

  local win_w = vim.api.nvim_win_get_width(0)
  local win_h = vim.api.nvim_win_get_height(0)
  local bolt, beside = M.layout(win_w, win_h)

  local plugins = ""
  local ok, lazy = pcall(require, "lazy")
  if ok then
    plugins = "  ·  " .. lazy.stats().count .. " plugins"
  end

  -- The right-hand column, built first: it decides how tall the whole thing is
  -- when the layout is side by side.
  local right, nav = {}, {}
  local function put(segs)
    right[#right + 1] = segs or {}
    return #right
  end

  put({ { "n v i m - l i t e", "NvimLiteName" } })
  put({ { "v" .. M.version() .. "  ·  nvim " .. M.nvim_version() .. plugins, "NvimLiteMuted" } })

  -- Sections in the order asked for: projects, then files, then keys — the
  -- shape the full nvim config uses, reordered so the coarsest choice comes
  -- first. A project is a place to go, a file is a thing to open, a keymap is
  -- what you reach for when neither list has it.
  local n = 0
  local function section(icon, title, entries)
    if #entries == 0 then
      return
    end
    put()
    put({ { icon .. "  " .. title, "NvimLiteTitle" } })
    for _, entry in ipairs(entries) do
      n = n + 1
      local key = n <= 9 and tostring(n) or " "
      local row = put({
        { "  " .. key .. "  ", "NvimLiteKey" },
        { entry[1], "NvimLitePath" },
      })
      nav[#nav + 1] = { row, entry[2], key }
    end
  end

  -- How many entries fit is a function of the space, not a constant. Beside
  -- the bolt the budget is the bolt's own height; stacked it is what is left
  -- under it.
  -- Beside the bolt the lists may run past its height when the window has the
  -- room — otherwise a 50-row terminal shows the same six entries a 20-row one
  -- does, and wastes thirty rows doing it. Stacked, the budget is whatever is
  -- left under the bolt.
  local budget = (beside and math.max(#bolt, math.min(win_h - 6, 24)) or (win_h - #bolt - 4)) - 9
  local n_recent = math.max(2, math.min(6, budget - 3))
  local n_proj = math.max(1, math.min(4, budget - n_recent))

  section("\u{f024b}", "Projects", projects(n_proj))
  section("\u{f0c5}", "Recent Files", recent_files(n_recent))

  put()
  put({
    { "\u{f030c}  ", "NvimLiteTitle" },
    { "j k", "NvimLiteKey" },
    { " mover  ", "NvimLiteMuted" },
    { "⏎", "NvimLiteKey" },
    { " abrir  ", "NvimLiteMuted" },
    { "/", "NvimLiteKey" },
    { " buscar  ", "NvimLiteMuted" },
    { "-", "NvimLiteKey" },
    { " archivos  ", "NvimLiteMuted" },
    { "e", "NvimLiteKey" },
    { " nuevo  ", "NvimLiteMuted" },
    { "<leader>h", "NvimLiteKey" },
    { " volver acá  ", "NvimLiteMuted" },
    { ":q", "NvimLiteKey" },
    { " salir", "NvimLiteMuted" },
  })

  -- Compose: bolt on the left and the column beside it, or one under the other.
  local rows = {}
  local left_shift = 0
  if beside then
    local bolt_w = 0
    for _, row in ipairs(bolt) do
      local w = 0
      for _, seg in ipairs(row) do
        w = w + vim.fn.strdisplaywidth(seg[1])
      end
      bolt_w = math.max(bolt_w, w)
    end

    -- Vertically centre the shorter of the two against the taller.
    local pad_left = math.max(0, math.floor((#right - #bolt) / 2))
    local pad_right = math.max(0, math.floor((#bolt - #right) / 2))
    local total = math.max(#bolt + pad_left, #right + pad_right)

    for i = 1, total do
      local segs = {}
      local b = bolt[i - pad_left]
      local w = 0
      if b then
        for _, seg in ipairs(b) do
          segs[#segs + 1] = { seg[1], HL_PREFIX .. seg[2] }
          w = w + vim.fn.strdisplaywidth(seg[1])
        end
      end
      local r = right[i - pad_right]
      if r and #r > 0 then
        segs[#segs + 1] = { string.rep(" ", bolt_w - w + 6), "NvimLiteMuted" }
        for _, seg in ipairs(r) do
          segs[#segs + 1] = seg
        end
      end
      rows[#rows + 1] = segs
    end
    -- nav rows were numbered against `right`; move them onto the composed grid.
    for _, item in ipairs(nav) do
      item[1] = item[1] + pad_right
    end
    left_shift = bolt_w + 6
  else
    for _, row in ipairs(bolt) do
      local segs = {}
      for _, seg in ipairs(row) do
        segs[#segs + 1] = { seg[1], HL_PREFIX .. seg[2] }
      end
      rows[#rows + 1] = segs
    end
    rows[#rows + 1] = {}
    local offset = #rows
    for _, r in ipairs(right) do
      rows[#rows + 1] = r
    end
    for _, item in ipairs(nav) do
      item[1] = item[1] + offset
    end
  end

  -- Centre horizontally on the widest row. Trailing whitespace goes first:
  -- LazyVim leaves 'list' on with Neovim's default listchars, whose `trail:-`
  -- turns every pad space into a dash — snacks never shows this because it
  -- renders into its own buffer with list off, and this writes into an
  -- ordinary one.
  local text, longest = {}, 0
  for i, segs in ipairs(rows) do
    local parts = {}
    for _, seg in ipairs(segs) do
      parts[#parts + 1] = seg[1]
    end
    text[i] = (table.concat(parts):gsub("%s+$", ""))
    longest = math.max(longest, vim.fn.strdisplaywidth(text[i]))
  end

  local pad = string.rep(" ", math.max(0, math.floor((win_w - longest) / 2)))
  local top = math.max(0, math.floor((win_h - #text) / 2) - 1)

  local out = {}
  for _ = 1, top do
    out[#out + 1] = ""
  end
  for _, line in ipairs(text) do
    out[#out + 1] = line == "" and "" or (pad .. line)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)

  -- Highlights go on by BYTE offset. The bolt is built from multi-byte block
  -- characters, so counting in characters puts every colour in the wrong place
  -- from the second segment onwards.
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
  vim.wo.statuscolumn = ""
  vim.wo.list = false

  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end

  -- `e` rather than `i`: the buffer is nomodifiable, so a plain `i` only beeps.
  map("e", "<cmd>enew | startinsert<cr>")
  map("-", "<cmd>Oil<cr>")

  -- Search the history rather than list it.
  --
  -- fzf-lua is already installed and already ships an oldfiles provider, so
  -- this costs nothing: no new plugin, and no process until the key is
  -- pressed. Six entries fit on screen; oldfiles usually holds thirty or more,
  -- and the rest were unreachable before this.
  map("/", function()
    if not pcall(vim.cmd, "FzfLua oldfiles") then
      vim.cmd("browse oldfiles")
    end
  end)

  if #nav > 0 then
    local at = 1
    local function focus(i)
      at = math.max(1, math.min(#nav, i))
      pcall(vim.api.nvim_win_set_cursor, 0, { top + nav[at][1], left_shift + 2 })
    end
    local function open(i)
      local target = nav[i or at]
      if not target then
        return
      end
      -- Entering a project means going there, not just looking at it: without
      -- the cd, `/` and the file pickers keep searching wherever you happened
      -- to start nvim from, which is never what you meant by picking it.
      if vim.fn.isdirectory(target[2]) == 1 then
        vim.cmd.cd(vim.fn.fnameescape(target[2]))
      end
      vim.cmd.edit(vim.fn.fnameescape(target[2]))
    end

    map("j", function() focus(at + 1) end)
    map("k", function() focus(at - 1) end)
    map("<Down>", function() focus(at + 1) end)
    map("<Up>", function() focus(at - 1) end)
    map("<CR>", function() open() end)
    for i, entry in ipairs(nav) do
      if entry[3] ~= " " then
        map(entry[3], function() open(i) end)
      end
    end

    -- cursorline follows the cursor for free and needs no autocmd to stay in
    -- sync with it.
    vim.wo.cursorline = true
    vim.wo.cursorlineopt = "line"
    focus(1)
  else
    vim.wo.cursorline = false
  end
end

--- The start-up path: only draw when Neovim came up with nothing to show.
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
  M.draw()
end

--- Reopen the start screen at any time.
---
--- The start buffer is `bufhidden = wipe`, so opening a file destroys it — by
--- design, since a stale dashboard sitting in the buffer list is worse than no
--- dashboard. That left no way back, which is what this is for: a fresh buffer
--- and a fresh draw, with the project list rebuilt from wherever you are now.
function M.open()
  if vim.fn.has("nvim-0.10") == 1 then
    local ok = pcall(function()
      require("snacks").dashboard()
    end)
    if ok then
      return
    end
  end
  vim.cmd("enew")
  M.draw()
end

--- Register `:LiteVersion` and, on Neovim 0.9 only, the start screen.
function M.setup()
  vim.api.nvim_create_user_command("LiteHome", M.open, { desc = "Back to the nvim-lite start screen" })
  vim.keymap.set("n", "<leader>h", M.open, { desc = "Start screen", silent = true })

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
