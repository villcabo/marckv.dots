-- Treesitter config for nvim-lite (server-focused)
-- NOTE: requires a C compiler (gcc or clang) to compile parsers
--   Debian/Ubuntu: sudo apt install -y gcc
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      -- Minimal set of parsers useful on servers
      ensure_installed = {
        "bash",
        "lua",
        "python",
        "yaml",
        "json",
        "toml",
        "markdown",
        "markdown_inline",
        "dockerfile",
        "regex",
        "vim",
        "vimdoc",
      },
      -- Do not auto-install parsers on every FileType open
      -- (install only what is listed above)
      auto_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
}
