-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Filetype DETECTION lives in config/filetypes.lua.
-- This file only applies HIGHLIGHTS and behavior for specific filetypes.

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup("nvim-lite", { clear = true })

-- ---------------------------------------------------------------------------
-- log: highlights + read-only
-- ---------------------------------------------------------------------------
autocmd("FileType", {
  group = augroup,
  pattern = "log",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    -- Timestamps: 2024-01-15 14:30:00 or [14:30:00] or Jan 15 14:30:00
    vim.fn.matchadd("Comment", [=[\d\{4\}-\d\{2\}-\d\{2\}[T ]\d\{2\}:\d\{2\}:\d\{2\}]=])
    vim.fn.matchadd("Comment", [=[\[\d\{2\}:\d\{2\}:\d\{2\}\]]=])
    vim.fn.matchadd("Comment", [=[\v(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d+\s+\d{2}:\d{2}:\d{2}]=])
    -- Log levels
    vim.fn.matchadd("ErrorMsg", [=[\v\c\[(ERROR|FATAL|CRIT(ICAL)?)\]]=])
    vim.fn.matchadd("ErrorMsg", [=[\v\c\s(ERROR|FATAL|CRIT(ICAL)?)\s]=])
    vim.fn.matchadd("WarningMsg", [=[\v\c\[(WARN(ING)?)\]]=])
    vim.fn.matchadd("WarningMsg", [=[\v\c\s(WARN(ING)?)\s]=])
    vim.fn.matchadd("Function", [=[\v\c\[(INFO)\]]=])
    vim.fn.matchadd("Function", [=[\v\c\s(INFO)\s]=])
    vim.fn.matchadd("Special", [=[\v\c\[(DEBUG|TRACE)\]]=])
    vim.fn.matchadd("Special", [=[\v\c\s(DEBUG|TRACE)\s]=])
    -- IPs
    vim.fn.matchadd("Number", [=[\v\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?]=])
    -- File paths
    vim.fn.matchadd("Directory", [=[\v/([\w._-]+/)+[\w._-]+]=])

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

    -- Comment line — HIGH priority so it wins over the key-type matches below
    vim.fn.matchadd("Comment", [=[^\s*#.*$]=], 100)
    -- Key types (ssh-rsa, ssh-ed25519, ecdsa-sha2-*, sk-ecdsa-*, sk-ssh-ed25519, etc.)
    vim.fn.matchadd("Keyword", [=[\v^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-\S+|sk-(ecdsa-sha2-\S+|ssh-ed25519)(\S*)?)>]=])
    -- Base64 key blobs (long alphanumeric chunks)
    vim.fn.matchadd("String", [=[\v\s\zs[A-Za-z0-9+/=]{40,}\ze]=])
    -- Comment/label at end of line (usually user@host)
    vim.fn.matchadd("Identifier", [=[\v\s\zs\S+\@\S+\ze\s*$]=])
    -- Options (prefix before key type: command="...", no-pty, from="...", etc.)
    vim.fn.matchadd("Type", [=[\v^[^#]*\ze\s+(ssh-|ecdsa-|sk-)]=])
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
