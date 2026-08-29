-- Colorscheme for nvim-lite
--
-- ONE theme, not six. This shipped with catppuccin, tokyonight, kanagawa,
-- gruvbox and rose-pine installed alongside the one actually in use — 16 MB of
-- git checkouts on every server so that `<leader>uC` could offer alternatives
-- nobody switches to over SSH. The full set stays in `nvim/`, which runs on a
-- workstation where that is worth having.
--
-- gentleman-kanagawa-blur is self-contained: it carries its own palette and
-- highlights and does NOT require kanagawa.nvim, which is why removing that
-- one does not take the theme with it.

return {
  {
    "Gentleman-Programming/gentleman-kanagawa-blur",
    lazy = false,
    priority = 1000,
    config = function()
      require("gentleman_kanagawa_blur").setup({
        highlight_overrides = {
          Visual = { bg = "#3B4261", bold = true },
          VisualNOS = { bg = "#3B4261" },
        },
      })
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gentleman-kanagawa-blur",
    },
  },

  -- LazyVim pulls tokyonight and catppuccin in as its own defaults, so they
  -- come back unless they are turned off explicitly.
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },
}
