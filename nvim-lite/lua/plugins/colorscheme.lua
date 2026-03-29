-- Colorschemes for nvim-lite
-- Switch with: <leader>uC (snacks picker) or :colorscheme <name>
--
-- Available themes and variants:
--   catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
--   tokyonight-night, tokyonight-storm, tokyonight-day, tokyonight-moon
--   kanagawa-wave, kanagawa-dragon, kanagawa-lotus
--   gruvbox-dark, gruvbox-light (via background=dark/light)
--   rose-pine-main, rose-pine-moon, rose-pine-dawn

return {
  -- Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      term_colors = true,
    },
  },

  -- TokyoNight
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {
      style = "night",
      transparent = true,
      terminal_colors = true,
    },
  },

  -- Kanagawa
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    opts = {
      transparent = true,
      theme = "wave",
      terminal_colors = true,
      overrides = function(colors)
        return {
          NormalFloat = { bg = "none" },
          FloatBorder = { bg = "none" },
          WhichKeyFloat = { bg = "none" },
        }
      end,
    },
  },

  -- Gentleman Kanagawa Blur
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

  -- Gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    opts = {
      transparent_mode = true,
      terminal_colors = true,
      contrast = "hard",
    },
  },

  -- Rosé Pine
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      variant = "main",
      disable_background = true,
    },
  },

  -- Default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gentleman-kanagawa-blur",
    },
  },
}
