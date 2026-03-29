-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup("nvim-lite", { clear = true })

-- Filetype detection for server files
autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { "*.log", "*.log.*", "/var/log/*" },
  callback = function()
    vim.bo.filetype = "log"
  end,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { ".env", ".env.*", "*.env" },
  callback = function()
    vim.bo.filetype = "sh"
  end,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { "nginx.conf", "*/nginx/*.conf", "*/nginx/**/*.conf" },
  callback = function()
    vim.bo.filetype = "nginx"
  end,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { "docker-compose*.yml", "docker-compose*.yaml", "compose*.yml", "compose*.yaml" },
  callback = function()
    vim.bo.filetype = "yaml.docker-compose"
  end,
})

-- Log file highlights (applied when filetype is "log")
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
