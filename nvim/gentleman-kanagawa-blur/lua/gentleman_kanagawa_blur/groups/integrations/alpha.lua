local p = require("gentleman_kanagawa_blur.palette")
return {
	AlphaHeader = { fg = p.title, bg = p.bg_dark },
	AlphaFooter = { fg = p.comment_doc, bg = p.bg_dark, italic = true },
	AlphaShortcut = { fg = p.enum, italic = true },
}
