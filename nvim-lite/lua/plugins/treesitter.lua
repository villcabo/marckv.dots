-- Treesitter config for nvim-lite (server-focused)
--
-- Strategy: if a C compiler is available, enable auto_install and
-- ensure common server parsers are installed. Otherwise, fall back
-- to Neovim's built-in bundled parsers only (no compilation needed).
--
-- Built-in parsers (shipped with the Neovim binary, always available):
--   bash, c, lua, markdown, markdown_inline, python, query, vim, vimdoc

local has_compiler = vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1

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

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if has_compiler then
        opts.ensure_installed = server_parsers
        opts.auto_install = true
      else
        opts.ensure_installed = {}
        opts.auto_install = false
      end
      return opts
    end,
  },
}
