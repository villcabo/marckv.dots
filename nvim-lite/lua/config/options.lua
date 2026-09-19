-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Disable auto-format on save (server files must be saved as-is)
vim.g.autoformat = false

-- Global statusline always at the bottom
vim.o.laststatus = 3
vim.o.cmdheight = 0

-- Terminal scrollback, well under the 10000 default.
--
-- This config runs on servers, where a :terminal is usually pointed at
-- something that never stops printing — `tail -f`, `docker logs -f`, a build.
-- Every line is held in memory for as long as the buffer lives, so on a box
-- that is left open for days the scrollback is the buffer that grows without
-- anyone noticing. 5000 lines still covers scrolling back through a command
-- that just ran, which is what it is actually used for.
vim.o.scrollback = 5000

