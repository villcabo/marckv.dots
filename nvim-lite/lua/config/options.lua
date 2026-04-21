-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Disable auto-format on save (server files must be saved as-is)
vim.g.autoformat = false

-- Global statusline always at the bottom
vim.o.laststatus = 3
vim.o.cmdheight = 0

-- SSH clipboard bridge via OSC 52:
-- When editing remotely over SSH, copy lands in the LOCAL terminal's clipboard
-- (not the remote server's) so you can paste outside nvim on your own machine.
-- Requires Neovim >= 0.10 and an OSC 52-capable terminal (Kitty, WezTerm,
-- iTerm2, Alacritty with `enable_kitty_keyboard`, modern xterm, etc.)
if os.getenv("SSH_TTY") or os.getenv("SSH_CONNECTION") then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
  -- Make y/yy/d/p use the system clipboard by default (no need for "+y).
  vim.opt.clipboard = "unnamedplus"
end
