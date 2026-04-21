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
-- authorized_keys: highlights (no built-in syntax on minimal setups)
-- ---------------------------------------------------------------------------
autocmd("FileType", {
  group = augroup,
  pattern = "authorized_keys",
  callback = function()
    -- Comments (# at start of line)
    vim.fn.matchadd("Comment", [=[^\s*#.*$]=])
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
