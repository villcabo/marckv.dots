local p = require("gentleman_kanagawa_blur.palette")
return {
	FlashLabel = { fg = p.variable_special, bg = p.bg_dark, bold = true },
	FlashBackdrop = { fg = p.comment_doc },
	FlashMatch = { fg = p.enum, bg = p.bg_dark },
	FlashCurrent = { fg = p.cyan, bg = p.bg_dark },
	FlashPrompt = { bg = p.gray1 },
}
