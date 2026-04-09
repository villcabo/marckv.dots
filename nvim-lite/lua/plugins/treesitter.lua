-- Treesitter config for nvim-lite (server-focused)
--
-- Strategy: if a C compiler is available, enable auto_install and
-- ensure common server parsers are installed. Otherwise, fall back
-- to Neovim's built-in bundled parsers only (no compilation needed).
--
-- Built-in parsers (shipped with the Neovim binary, always available):
--   bash, c, lua, markdown, markdown_inline, python, query, vim, vimdoc

local has_compiler = vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1

-- Check if the bundled tree-sitter CLI actually works on this system.
-- Neovim's latest builds bundle a tree-sitter binary compiled against GLIBC 2.39,
-- which fails on older systems like Debian 12 (GLIBC 2.36).
local function has_working_treesitter()
  if not has_compiler then
    return false
  end
  local ts_path = vim.fn.exepath("tree-sitter")
  if ts_path == "" then
    -- Try the bundled one inside Neovim's install path
    local nvim_path = vim.fn.exepath("nvim")
    if nvim_path ~= "" then
      ts_path = vim.fn.fnamemodify(nvim_path, ":h") .. "/tree-sitter"
    end
  end
  if ts_path == "" or vim.fn.executable(ts_path) ~= 1 then
    return false
  end
  local result = vim.fn.system(ts_path .. " --version 2>&1")
  return vim.v.shell_error == 0
end

local can_compile = has_working_treesitter()

-- Parsers commonly needed on servers
local server_parsers = {
  "yaml",
  "json",
  "jsonc",
  "toml",
  "dockerfile",
  "xml",
  "ini",
  "ssh_config",
  "diff",
  "git_config",
  "gitcommit",
  "gitignore",
  "regex",
  "nginx",
  "hcl",
  "terraform",
}

-- Detect Neovim version to pin nvim-treesitter on older systems.
-- nvim-treesitter deprecated the `master` branch in favor of `main`,
-- and the new version requires Neovim 0.10+. On Neovim 0.10.x
-- (Debian 11 / Ubuntu 20 due to GLIBC), we pin nvim-treesitter to
-- the last known-good commit on master that works with LazyVim v14.
local nvim_ver = vim.version()
local is_old_nvim = nvim_ver.major == 0 and nvim_ver.minor < 11

local ts_spec = {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    if can_compile then
      opts.ensure_installed = server_parsers
      opts.auto_install = true
    else
      opts.ensure_installed = {}
      opts.auto_install = false
    end
    return opts
  end,
}

if is_old_nvim then
  -- Force the legacy `master` branch which still exposes the classic
  -- `nvim-treesitter.configs` module that LazyVim v14 depends on.
  -- The new `main` branch is a rewrite that drops this module.
  ts_spec.branch = "master"
end

return {
  ts_spec,
  -- On old Neovim, also pin nvim-treesitter-textobjects to a compatible commit
  is_old_nvim and {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "master",
    pin = true,
  } or nil,
}
