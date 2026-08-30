-- nvim-lite: Lightweight Neovim config for servers
-- Usage: NVIM_APPNAME=nvim-lite nvim

-- Neovim 0.9 shims, before anything else can call the missing functions
require("config.compat")

-- Register custom filetype detection BEFORE plugins resolve any filetype
require("config.filetypes")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Our own identity: `:LiteVersion`, and the start banner on Neovim 0.9 where
-- snacks.dashboard cannot open a window.
require("config.branding").setup()
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0
