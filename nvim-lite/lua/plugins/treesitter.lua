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

-- Neovim 0.11+ gets nvim-treesitter's `main` branch, which cannot build a
-- single parser without the tree-sitter CLI. mason used to install one as a
-- fallback; mason is gone from this config, so the CLI now comes from
-- `04-install-nvim-lite.sh --deps` and nothing else.
--
-- Say so loudly. The failure mode without this warning is the one that hid the
-- original bug for months: no parser is built, Vim's legacy regex syntax takes
-- over, the file still looks coloured, and the only symptom is that
-- highlighting "feels poor".
local nv = vim.version()
if can_compile and not (nv.major == 0 and nv.minor < 11) and vim.fn.executable("tree-sitter") ~= 1 then
  -- ONE short line, on purpose.
  --
  -- The first version of this was four lines with blank lines between them,
  -- which forces "Press ENTER or type command to continue" on every start
  -- wherever snacks is not there to render notifications in a window. A
  -- warning that costs a keypress per file is worse than the problem it
  -- reports; this one has to fit on the status line and get out of the way.
  vim.schedule(function()
    vim.notify(
      "nvim-lite: no tree-sitter CLI — run installer/04-install-nvim-lite.sh --deps",
      vim.log.levels.WARN
    )
  end)
end

-- Parsers commonly needed on servers
--
-- All fifteen together weigh 1.1 MB — measured, not assumed — so the list is
-- built by asking what gets opened on a server, never by trimming for size.
--
-- `bash` was missing from it, and is not one of the parsers bundled with the
-- Neovim binary either (those are c, lua, markdown, markdown_inline, query,
-- vim, vimdoc). On a config whose entire purpose is administering servers,
-- shell scripts are the most common thing anyone opens, and they had no parser
-- at all.
-- Four were measured and dropped rather than guessed at:
--
--   sql       10.6 MB — sixty percent of every parser put together, for a
--                       language Vim already highlights with syntax/sql.vim.
--                       Reading a dump over SSH does not notice.
--   gitcommit  1.3 MB — commits happen in the shell on these hosts
--   vim        1.1 MB — the config here is Lua; nothing opens a .vim file
--   awk        0.7 MB — one fixture, and about that many a year in practice
--
-- All four still highlight through Vim's own syntax files, and S7 accepts that
-- as a correct outcome rather than a failure.
local server_parsers = {
  "bash",
  "python",
  -- Bundled with the binary, but nvim-treesitter's `master` branch only
  -- enables highlighting for parsers it manages itself: on Neovim 0.10 a
  -- README came out on regex syntax while every other fixture was parsed.
  "markdown",
  "markdown_inline",
  -- Bundled with the binary, same reason as markdown: the `master` branch only
  -- highlights parsers it manages, so a .lua or .vim file came out on regex.
  "lua",
  -- The rest of what actually gets opened on a server: Spring .properties,
  -- SQL dumps, Makefiles, /etc/passwd, exported CSV, awk one-liners.
  "properties",
  "make",
  "passwd",
  "csv",
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
      -- Off, so the curated list above is the whole list.
      --
      -- With auto_install on, opening any file pulls its parser in on the
      -- spot, and the four dropped from that list came straight back: a
      -- Debian 11 container finished a run holding sql, awk and gitcommit
      -- again. The curation was decorative — the real footprint was "whatever
      -- got opened", growing on its own.
      --
      -- The trade is real and worth stating: a file type not on the list gets
      -- Vim's syntax highlighting rather than treesitter. On a host whose job
      -- is yaml, conf, logs and shell that is the right side of the trade;
      -- flip it back to true if these machines start seeing other work.
      opts.auto_install = false
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
