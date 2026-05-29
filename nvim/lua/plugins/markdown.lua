return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = opts.linters["markdownlint-cli2"] or {}
      -- Disable MD013 (line-length) and MD033 (inline HTML) globally
      opts.linters["markdownlint-cli2"].args = {
        "--config",
        vim.fn.stdpath("config") .. "/.markdownlint-cli2.jsonc",
        "--",
      }
    end,
  },
  {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    heading = {
      enabled = true,
      sign = true,
      style = "full",
      icons = { "① ", "② ", "③ ", "④ ", "⑤ ", "⑥ " },
      left_pad = 1,
    },
    bullet = {
      enabled = true,
      icons = { "●", "○", "◆", "◇" },
      right_pad = 1,
      highlight = "render-markdownBullet",
    },
    checkbox = {
      enabled = true,
      unchecked = {
        icon = "󰄱     ",
        highlight = "RenderMarkdownUnchecked",
      },
      checked = {
        icon = "󰱒     ",
        highlight = "RenderMarkdownChecked",
      },
      custom = {
        todo = { raw = "[-]", rendered = "󰥔     ", highlight = "RenderMarkdownTodo" },
      },
    },
  },
  },
}
