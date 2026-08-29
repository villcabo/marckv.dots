-- Treesitter config for nvim-lite (server-focused)
--
-- Strategy: if this machine can build parsers, install the ones a server
-- actually opens. If it cannot, fall back to the parsers bundled with the
-- Neovim binary and leave it at that — these dotfiles land on hosts with no
-- toolchain, and a config that errors on every startup there is worse than one
-- with plainer colours.
--
-- Bundled parsers, MEASURED on the v0.10.3 tarball rather than assumed:
--   c, lua, markdown, markdown_inline, query, vim, vimdoc
-- Note what is NOT in that list: bash and python. An earlier version of this
-- comment claimed both, which mattered, because on a server-focused config
-- shell scripts are the most common thing you open.

-- Whether parsers can be BUILT here.
--
-- This used to ask for the `tree-sitter` CLI, and that was the wrong question.
-- nvim-treesitter downloads pre-generated C sources and compiles them with a C
-- compiler; the CLI is only needed for the grammars marked
-- `requires_generate_from_grammar`, which are latex, rust, scala, svelte,
-- swift, ocaml, mermaid, typst and the like — 27 of them, and not one is in
-- the list below.
--
-- The CLI ships with neither Neovim's release tarball nor any distro package
-- here, so that check returned false on every server: `ensure_installed` came
-- out empty and NOTHING was installed — not yaml, not json, not dockerfile.
-- It went unnoticed because Vim's legacy regex syntax takes over and the file
-- still looks coloured; it just stops understanding the structure.
--
-- Verified on Debian 11 with no CLI present and gcc available: yaml downloads,
-- compiles and installs.
local function can_build_parsers()
  return vim.fn.executable("cc") == 1
    or vim.fn.executable("gcc") == 1
    or vim.fn.executable("clang") == 1
end

local can_compile = can_build_parsers()

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
