-- Neovim 0.9 compatibility shims
--
-- Debian 10 tops out at Neovim 0.9.5, and the plugin ecosystem has moved on.
-- The failures all looked like different bugs and were the same two missing
-- functions:
--
--   snacks         nvim_get_hl(0, { …, create = false })  → "invalid key: create"
--   mini.ai        vim.islist(x)                          → "attempt to call field 'islist'"
--   mini.surround  vim.islist(x)
--   lualine        Snacks.util.color → nvim_get_hl again
--
-- Patching each consumer was the first approach and it does not converge:
-- four plugins pinned or disabled, then lualine broke, and LazyVim has 138
-- call sites into snacks at v14.15.1 (86 at v14.0.0, 66 at v13.6.0 — going
-- back does not escape it, it only trades features for a smaller number).
--
-- So the shims go here instead, in front of everything. Two functions, both
-- added in Neovim 0.10, both trivially expressible in 0.9:
--
--   * vim.islist is vim.tbl_islist renamed
--   * nvim_get_hl's `create` option only asks it not to create a missing
--     highlight group; 0.9 never created one, so dropping the key gives the
--     same result
--
-- This is deliberately narrow. It restores two APIs; it does not try to make
-- 0.9 look like 0.10.
if vim.fn.has("nvim-0.10") == 1 then
  return
end

-- vim.islist: renamed from vim.tbl_islist in 0.10
if vim.islist == nil and vim.tbl_islist ~= nil then
  vim.islist = vim.tbl_islist
end

-- nvim_get_hl: `create` is rejected outright on 0.9
local original_get_hl = vim.api.nvim_get_hl
vim.api.nvim_get_hl = function(ns_id, opts)
  if type(opts) == "table" and opts.create ~= nil then
    local copy = {}
    for k, v in pairs(opts) do
      if k ~= "create" then
        copy[k] = v
      end
    end
    opts = copy
  end
  return original_get_hl(ns_id, opts)
end

-- What this does NOT fix
--
-- With the shims in place the version gates elsewhere were removed, to see
-- whether Debian 10 could simply have the whole editor. It cannot:
--
--     vim/treesitter/query.lua:259: query: invalid node type at position 5197
--     for language lua
--
-- nvim-treesitter ships queries written against current parsers, and the lua
-- parser bundled with the 0.9.5 binary is older than they expect. That is a
-- data/grammar mismatch, not a missing function, and nothing here can bridge
-- it. So snacks keeps its windows closed on 0.9 (see plugins/ui.lua) and the
-- gates stay.
--
-- What the shims did buy is worth stating: mini.ai and mini.surround had been
-- pinned to v0.12.0 to dodge vim.islist, and now run current. Restoring a
-- missing function beats freezing the plugins that call it.
