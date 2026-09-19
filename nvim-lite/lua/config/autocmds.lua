-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Filetype DETECTION lives in config/filetypes.lua.
-- This file only applies HIGHLIGHTS and behavior for specific filetypes.

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup("nvim-lite", { clear = true })

-- ---------------------------------------------------------------------------
-- Window matches, added once and taken back.
--
-- matchadd() attaches to the WINDOW, not the buffer, and nothing ever clears
-- it: the FileType autocmds below fire again for every log opened in the same
-- split, so each visit stacks another full set of patterns on top of the last.
-- They all keep being evaluated on every redraw, and they outlive the buffer
-- that justified them — a window that moved on to a Lua file is still matching
-- log timestamps.
--
-- Measured on a proxy host: an `nvim --embed` left open for 24 days over a
-- directory of .conf and .log files reached 2.5 GB RSS, all of it heap.
--
-- So the ids are kept per window, under a key per rule set, and the previous
-- set is dropped before a new one goes in. `pcall` because a match id is gone
-- once its window closes, and matchdelete() throws on an id it cannot find.
-- ---------------------------------------------------------------------------
local MATCH_KEYS = { "log", "authorized_keys" }

local function clear_window_matches(key)
  local var = "nvim_lite_matches_" .. key
  for _, id in ipairs(vim.w[var] or {}) do
    pcall(vim.fn.matchdelete, id)
  end
  vim.w[var] = {}
end

--- Replace this window's matches for `key` with `patterns`.
--- @param key string rule set name, namespacing the ids within the window
--- @param patterns table list of { highlight_group, pattern, priority? }
local function set_window_matches(key, patterns)
  clear_window_matches(key)
  local ids = {}
  for _, p in ipairs(patterns) do
    local ok, id = pcall(vim.fn.matchadd, p[1], p[2], p[3])
    if ok then
      ids[#ids + 1] = id
    end
  end
  vim.w["nvim_lite_matches_" .. key] = ids
end

-- A window that stops showing the buffer keeps the matches otherwise.
autocmd("BufWinLeave", {
  group = augroup,
  callback = function()
    for _, key in ipairs(MATCH_KEYS) do
      clear_window_matches(key)
    end
  end,
})

-- ---------------------------------------------------------------------------
-- log: highlights + read-only
-- ---------------------------------------------------------------------------
autocmd("FileType", {
  group = augroup,
  pattern = "log",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    set_window_matches("log", {
      -- Timestamps: 2024-01-15 14:30:00 or [14:30:00] or Jan 15 14:30:00
      { "Comment", [=[\d\{4\}-\d\{2\}-\d\{2\}[T ]\d\{2\}:\d\{2\}:\d\{2\}]=] },
      { "Comment", [=[\[\d\{2\}:\d\{2\}:\d\{2\}\]]=] },
      { "Comment", [=[\v(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d+\s+\d{2}:\d{2}:\d{2}]=] },
      -- Log levels
      { "ErrorMsg", [=[\v\c\[(ERROR|FATAL|CRIT(ICAL)?)\]]=] },
      { "ErrorMsg", [=[\v\c\s(ERROR|FATAL|CRIT(ICAL)?)\s]=] },
      { "WarningMsg", [=[\v\c\[(WARN(ING)?)\]]=] },
      { "WarningMsg", [=[\v\c\s(WARN(ING)?)\s]=] },
      { "Function", [=[\v\c\[(INFO)\]]=] },
      { "Function", [=[\v\c\s(INFO)\s]=] },
      { "Special", [=[\v\c\[(DEBUG|TRACE)\]]=] },
      { "Special", [=[\v\c\s(DEBUG|TRACE)\s]=] },
      -- IPs
      { "Number", [=[\v\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?]=] },
      -- File paths
      { "Directory", [=[\v/([\w._-]+/)+[\w._-]+]=] },
    })

    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
  end,
})

-- ---------------------------------------------------------------------------
-- Mark duplicate KEY=VALUE entries in env/properties/conf/ini files.
-- Lines sharing the same KEY get a sign in the gutter + virtual text marker.
-- nginx is excluded: it uses directive syntax (`limit_req zone=...`), not KEY=VALUE.
-- ---------------------------------------------------------------------------
local dup_ns = vim.api.nvim_create_namespace("nvim_lite_dup_keys")

local function highlight_duplicate_keys(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, dup_ns, 0, -1)

  -- nginx .conf files are directive-based, not KEY=VALUE — never mark them.
  if vim.bo[buf].filetype == "nginx" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local seen = {}     -- key -> first line index (0-based)
  local dup_lines = {} -- set of line indices to mark

  for i, line in ipairs(lines) do
    local lnum = i - 1
    -- Skip comments (#, ;) and section headers ([section])
    if not line:match("^%s*[#;]") and not line:match("^%s*%[") then
      -- Match KEY=VALUE — KEY allows letters, digits, _, ., -
      local key = line:match("^%s*([%w_%.%-]+)%s*=")
      if key then
        if seen[key] then
          dup_lines[seen[key]] = true
          dup_lines[lnum] = true
        else
          seen[key] = lnum
        end
      end
    end
  end

  for lnum in pairs(dup_lines) do
    vim.api.nvim_buf_set_extmark(buf, dup_ns, lnum, 0, {
      sign_text = "▌",
      sign_hl_group = "WarningMsg",
      virt_text = { { " ← clave duplicada", "WarningMsg" } },
      virt_text_pos = "eol",
    })
  end
end

autocmd({ "BufReadPost", "BufWritePost", "TextChanged", "InsertLeave" }, {
  group = augroup,
  pattern = { "*.env", "*.env.*", ".env", ".env.*", "*.properties", "*.conf", "*.ini", "*.cfg" },
  callback = function(args)
    highlight_duplicate_keys(args.buf)
  end,
})

-- Also trigger by filetype (covers cases where pattern doesn't match the path)
autocmd("FileType", {
  group = augroup,
  pattern = { "env", "properties", "conf", "dosini", "config" },
  callback = function(args)
    highlight_duplicate_keys(args.buf)
  end,
})

-- ---------------------------------------------------------------------------
-- authorized_keys: highlights (no built-in syntax on minimal setups)
-- ---------------------------------------------------------------------------
autocmd("FileType", {
  group = augroup,
  pattern = "authorized_keys",
  callback = function()
    -- Enable `gcc` / `gc` line commenting
    vim.bo.commentstring = "# %s"

    set_window_matches("authorized_keys", {
      -- Comment line — HIGH priority so it wins over the key-type matches below
      { "Comment", [=[^\s*#.*$]=], 100 },
      -- Key types (ssh-rsa, ssh-ed25519, ecdsa-sha2-*, sk-ecdsa-*, sk-ssh-ed25519, etc.)
      { "Keyword", [=[\v^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-\S+|sk-(ecdsa-sha2-\S+|ssh-ed25519)(\S*)?)>]=] },
      -- Base64 key blobs (long alphanumeric chunks)
      { "String", [=[\v\s\zs[A-Za-z0-9+/=]{40,}\ze]=] },
      -- Comment/label at end of line (usually user@host)
      { "Identifier", [=[\v\s\zs\S+\@\S+\ze\s*$]=] },
      -- Options (prefix before key type: command="...", no-pty, from="...", etc.)
      { "Type", [=[\v^[^#]*\ze\s+(ssh-|ecdsa-|sk-)]=] },
    })
  end,
})
-- Reload files changed outside the editor, without being asked to.
--
-- 'autoread' is already on by default, but Neovim does not watch the file: it
-- only notices a change at certain moments, which is why reaching for :e
-- becomes a habit. The manual says as much under :help timestamp — "if you
-- don't get warned often enough you can use :checktime".
--
-- checktime rather than :e on purpose: it reloads only when the buffer has no
-- unsaved changes. :e refuses in that case and :e! would throw the edits away.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose", "TermLeave" }, {
  callback = function()
    -- Two different things have to be skipped, and only one of them is a mode.
    --
    -- mode() == "c" is the command line itself, where checktime is postponed
    -- anyway and only litters the message area.
    --
    -- getcmdwintype() is the command-line WINDOW (q: and q/), and that one is
    -- an ordinary buffer in normal mode — mode() returns "n" there, so the
    -- first check sails right past it and checktime raises
    --     E11: Invalid in command-line window
    -- on every BufEnter. Opening q: was enough to hit it.
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
      vim.cmd.checktime()
    end
  end,
})
