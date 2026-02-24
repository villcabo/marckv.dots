-- nvim-lite: Lightweight Neovim config for servers
-- Usage: NVIM_APPNAME=nvim-lite nvim

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0
