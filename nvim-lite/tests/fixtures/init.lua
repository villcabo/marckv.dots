-- A Neovim config fragment, which is what you edit when the server's editor
-- misbehaves — the one file you cannot afford to have unreadable.
local M = {}

---@param buf integer
---@return boolean
function M.is_big(buf)
  local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
  return ok and stats ~= nil and stats.size > 1024 * 1024
end

vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(args)
    if M.is_big(args.buf) then
      vim.bo[args.buf].swapfile = false
    end
  end,
})

return M
