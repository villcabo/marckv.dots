-- Spell-checking disabled (not useful on servers)
vim.opt.spell = false

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath })
end

vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

-- Clipboard
vim.opt.clipboard = "unnamedplus"
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "win32yank",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = false,
  }
end

-- Detect Neovim version — LazyVim >= 15.0 requires Neovim 0.11.2+
-- On older Neovim (e.g. Debian 11 / Ubuntu 20 stuck on v0.10.x due to GLIBC),
-- pin LazyVim to the last v14.x tag which supports Neovim 0.10.x.
local nvim_ver = vim.version()
local lazyvim_spec = { "LazyVim/LazyVim", import = "lazyvim.plugins" }
if nvim_ver.major == 0 and nvim_ver.minor < 11 then
  -- Use explicit tag and pin=true to prevent lazy.nvim from auto-updating.
  -- v14.15.1 is the last v14.x release compatible with Neovim 0.10.x.
  lazyvim_spec.tag = "v14.15.1"
  lazyvim_spec.pin = true
  vim.notify(
    "nvim-lite: detected Neovim " .. nvim_ver.major .. "." .. nvim_ver.minor ..
    " — pinning LazyVim to v14.15.1 for compatibility",
    vim.log.levels.WARN
  )
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    lazyvim_spec,
    { import = "lazyvim.plugins.extras.editor.fzf" },
    { import = "lazyvim.plugins.extras.coding.mini-surround" },
    { import = "plugins" },
  },
  defaults = {
    lazy = true,
    version = false,
  },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "matchit",
        "tohtml",
        "tutor",
      },
    },
  },
})
