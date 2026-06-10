local p = require("gentleman_kanagawa_blur.palette")
return {
	BlinkCmpMenu = { fg = p.fg, bg = p.bg_dark },
	BlinkCmpMenuBorder = { fg = p.comment_doc, bg = p.bg_dark },
	BlinkCmpMenuSelection = { bg = p.selection, fg = p.fg, bold = true },
	BlinkCmpDoc = { fg = p.fg, bg = p.bg_dark },
	BlinkCmpDocBorder = { fg = p.comment_doc, bg = p.bg_dark },
	BlinkCmpDocSeparator = { fg = p.comment, bg = p.bg_dark },
}
