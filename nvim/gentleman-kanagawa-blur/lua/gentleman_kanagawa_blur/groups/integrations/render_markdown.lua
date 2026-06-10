local p = require("gentleman_kanagawa_blur.palette")
local u = require("gentleman_kanagawa_blur.utils.color_utils")
local is_light = vim.o.background == "light"
local DARKEN_AMOUNT = 0.20

-- Use lighten for light backgrounds, darken for dark
local function heading_bg(color)
    if is_light then
        return u.lighten(color, DARKEN_AMOUNT, p.bg_dark)
    end
    return u.darken(color, DARKEN_AMOUNT, p.bg_dark)
end

return {
    RenderMarkdownCode = { bg = p.gray1 },
    RenderMarkdownCodeInline = { fg = p.string, bold = true },
    RenderMarkdownBullet = { fg = p.cyan },
    RenderMarkdownH1Bg = { bg = heading_bg(p.title), fg = p.title },
    RenderMarkdownH2Bg = { bg = heading_bg(p.primary), fg = p.primary },
    RenderMarkdownH3Bg = { bg = heading_bg(p.enum), fg = p.enum },
    RenderMarkdownH4Bg = { bg = heading_bg(p.tag), fg = p.tag },
    RenderMarkdownH5Bg = { bg = heading_bg(p.type), fg = p.type },
    RenderMarkdownH6Bg = { bg = heading_bg(p.variant), fg = p.variant },
    RenderMarkdownH1 = { bg = heading_bg(p.title), fg = p.title },
    RenderMarkdownH2 = { bg = heading_bg(p.primary), fg = p.primary },
    RenderMarkdownH3 = { bg = heading_bg(p.enum), fg = p.enum },
    RenderMarkdownH4 = { bg = heading_bg(p.tag), fg = p.tag },
    RenderMarkdownH5 = { bg = heading_bg(p.type), fg = p.type },
    RenderMarkdownH6 = { bg = heading_bg(p.variant), fg = p.variant },
    RenderMarkdownTableHead = { fg = p.comment },
    RenderMarkdownTableRow = { fg = p.comment_doc },
}
