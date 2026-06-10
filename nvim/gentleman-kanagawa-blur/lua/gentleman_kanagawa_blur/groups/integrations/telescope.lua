local p = require("gentleman_kanagawa_blur.palette")

return {
	TelescopeBorder = { fg = p.gray3, bg = "none" },
	TelescopeNormal = { fg = p.fg, bg = "none" },
	TelescopePreviewTitle = { fg = p.fg, bg = "none" },
	TelescopeResultsTitle = { fg = p.fg, bg = "none" },
	TelescopePromptTitle = { fg = p.fg, bg = "none", italic = true },
	TelescopePromptBorder = { fg = p.gray3, bg = "none" },
	TelescopePromptNormal = { fg = p.fg, bg = "none" },
	TelescopePromptCounter = { fg = p.gray4, bg = p.gray1 },
	TelescopeMatching = { fg = p.yellow, bold = true },
}
