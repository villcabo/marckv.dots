-- Treesitter config for nvim-lite (server-focused)
--
-- Strategy: rely exclusively on Neovim's built-in bundled parsers.
-- No tree-sitter-cli, no cargo, no compilation needed on the server.
--
-- Built-in parsers (shipped with the Neovim binary, always available):
--   bash, c, lua, markdown, markdown_inline, python, query, vim, vimdoc
--
-- Using opts as a function so we can REPLACE LazyVim's default ensure_installed
-- list instead of merging with it (lazy.nvim merges opts tables by default).
--
-- To install extra parsers manually (requires tree-sitter-cli):
--   cargo install tree-sitter-cli   # then inside nvim:
--   :TSInstall yaml json dockerfile toml
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Replace (not merge) LazyVim's default ensure_installed list
      opts.ensure_installed = {}
      opts.auto_install = false
      return opts
    end,
  },
}
