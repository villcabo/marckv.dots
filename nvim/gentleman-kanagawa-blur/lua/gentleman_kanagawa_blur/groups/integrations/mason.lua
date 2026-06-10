local p = require("gentleman_kanagawa_blur.palette")

return {
	MasonHeader = { fg = p.fg, bg = p.bg_dark, bold = true },
	MasonHeaderSecondary = { fg = p.fg, bg = p.bg_dark, bold = true },

	MasonHighlight = { fg = p.green },
	MasonHighlightBlock = { bg = p.green, fg = p.bg_dark, bold = true },
	MasonHighlightBlockBold = { bg = p.blue, fg = p.bg_dark, bold = true },

	MasonHighlightSecondary = { fg = p.magenta },
	MasonHighlightBlockSecondary = { fg = p.red, bg = p.blue },
	MasonHighlightBlockBoldSecondary = { fg = p.bg_dark, bg = p.fg, bold = true },

	MasonLink = { fg = p.cyan },

	MasonMuted = { fg = p.subtext1 },
	MasonMutedBlock = { bg = p.bg_dark, fg = p.subtext3, bold = true },
	MasonMutedBlockBold = { bg = p.yellow, fg = p.bg_dark, bold = true },

	MasonError = { fg = p.red },
	MasonWarning = { fg = p.yellow },

	MasonHeading = { fg = p.magenta, bold = true },
}
