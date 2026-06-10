local M = {}

function M.colorscheme()
    vim.cmd("hi clear")
    if vim.fn.exists("syntax_on") then
        vim.cmd("syntax reset")
    end
    vim.o.termguicolors = true
    vim.g.colors_name = "gentleman-kanagawa-blur"

    -- Clear ALL cached modules so they re-evaluate based on current background
    for key, _ in pairs(package.loaded) do
        if key:match("^gentleman_kanagawa_blur") then
            package.loaded[key] = nil
        end
    end

    require("gentleman_kanagawa_blur.highlights").setup()
end

M.setup = require("gentleman_kanagawa_blur.config").setup

return M
