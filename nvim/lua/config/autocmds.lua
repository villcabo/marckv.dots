-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Spell-check solo en filetypes de texto (no en código/yaml/etc.),
-- para no marcar en amarillo términos técnicos ni palabras en español.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit", "text", "txt", "tex", "plaintex" },
  callback = function()
    vim.opt_local.spell = true
  end,
})
