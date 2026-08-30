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
  -- Deliberately silent.
  --
  -- This used to call vim.notify. Where snacks is absent — which is exactly
  -- the case this branch handles — notify falls back to Neovim's message area,
  -- and a line this long triggers "Press ENTER or type command to continue" on
  -- EVERY start. An informational notice nobody acts on turned into a keypress
  -- before every file. `:messages` is where a startup note belongs.
  vim.g.nvim_lite_lazyvim_pin = "v14.15.1"
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    lazyvim_spec,
    { import = "lazyvim.plugins.extras.editor.fzf" },
    { import = "lazyvim.plugins.extras.coding.mini-surround" },
    { import = "plugins" },
  },
  -- The lockfile goes to the state directory, not next to the config.
  --
  -- lazy.nvim writes lazy-lock.json into the config directory by default, and
  -- this config is installed as a SYMLINK into the repository. That means
  -- every Neovim start rewrites a tracked file: `git status` comes back dirty
  -- on every server, and a `git pull` can end in a conflict over a lockfile
  -- nobody edited.
  --
  -- It also fails outright where the repo is not writable — which is how this
  -- surfaced, as an assert inside lazy/manage/lock.lua on a read-only mount.
  --
  -- Per-host is the right place for it anyway: these machines run four
  -- different Neovim versions across two LazyVim generations, and one shared
  -- lockfile could not describe all of them.
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  defaults = {
    lazy = true,
    version = false,
  },
  install = { colorscheme = { "gentleman-kanagawa-blur", "habamax" } },
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
