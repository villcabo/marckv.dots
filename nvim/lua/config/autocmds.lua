-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Re-apply colorscheme when background option changes (dark ↔ light)
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    local colorscheme = vim.g.colors_name or "gentleman-kanagawa-blur"
    vim.cmd.colorscheme(colorscheme)
  end,
})

-- Spell-check solo en filetypes de texto (no en código/yaml/etc.),
-- para no marcar en amarillo términos técnicos ni palabras en español.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit", "text", "txt", "tex", "plaintex" },
  callback = function()
    vim.opt_local.spell = true
  end,
})
-- Reload files changed outside the editor, without being asked to.
--
-- 'autoread' is already on by default, but Neovim does not watch the file: it
-- only notices a change at certain moments, which is why reaching for :e
-- becomes a habit. The manual says as much under :help timestamp — "if you
-- don't get warned often enough you can use :checktime".
--
-- checktime rather than :e on purpose: it reloads only when the buffer has no
-- unsaved changes. :e refuses in that case and :e! would throw the edits away.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose", "TermLeave" }, {
  callback = function()
    -- Skip while a command line is open: there checktime is postponed anyway
    -- and only litters the message area.
    if vim.fn.mode() ~= "c" then
      vim.cmd.checktime()
    end
  end,
})
