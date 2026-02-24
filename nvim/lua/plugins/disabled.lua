-- This file contains the configuration for disabling specific Neovim plugins.

return {
  {
    -- Plugin: bufferline.nvim
    -- URL: https://github.com/akinsho/bufferline.nvim
    -- Description: A snazzy buffer line (with tabpage integration) for Neovim.
    "akinsho/bufferline.nvim",
    enabled = false,
  },
  {
    -- URL: https://github.com/yetone/avante.nvim
    "yetone/avante.nvim",
    enabled = false,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = false,
  },
  {
    "NickvanDyke/opencode.nvim",
    enabled = false,
  },
  {
    "olimorris/codecompanion.nvim",
    enabled = false,
  },
  {
    "tris203/precognition.nvim",
    enabled = false,
  },
  {
    "sphamba/smear-cursor.nvim",
    enabled = false,
  },
  {
    -- AI de pago (Claude) — reemplazado por Copilot free tier
    "coder/claudecode.nvim",
    enabled = false,
  },
  {
    -- Solo wrappea el gemini CLI, no provee autocomplete inline
    "jonroosevelt/gemini-cli.nvim",
    enabled = false,
  },
  {
    -- Plugin de notas Obsidian — usar la app standalone
    "obsidian-nvim/obsidian.nvim",
    enabled = false,
  },
  {
    -- Útil solo para demos/grabaciones de pantalla
    "NStefan002/screenkey.nvim",
    enabled = false,
  },
  {
    -- Juego de práctica de Vim, no para uso diario
    "ThePrimeagen/vim-be-good",
    enabled = false,
  },
}
