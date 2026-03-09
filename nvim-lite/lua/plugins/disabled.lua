-- Disable heavy LazyVim default plugins and features not needed on servers
return {
  -- UI pesado
  { "akinsho/bufferline.nvim", enabled = false },
  { "folke/noice.nvim", enabled = false },
  { "rcarriga/nvim-notify", enabled = false },

  -- Dashboard (not needed on servers)
  { "nvimdev/dashboard-nvim", enabled = false },

  -- Completion engine (heavy)
  { "saghen/blink.cmp", enabled = false },

  -- Visual heavy
  { "b0o/incline.nvim", enabled = false },
  { "sphamba/smear-cursor.nvim", enabled = false },
  { "willothy/veil.nvim", enabled = false },
}
