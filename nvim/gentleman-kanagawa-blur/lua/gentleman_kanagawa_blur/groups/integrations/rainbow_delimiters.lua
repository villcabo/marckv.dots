local p = require("gentleman_kanagawa_blur.palette")
return {
	RainbowDelimiterRed = { fg = p.variant, bg = p.bg_dark },
	RainbowDelimiterYellow = { fg = p.string, bg = p.bg_dark },
	RainbowDelimiterBlue = { fg = p.blue, bg = p.bg_dark },
	RainbowDelimiterOrange = { fg = p.operator, bg = p.bg_dark },
	RainbowDelimiterGreen = { fg = p.enum, bg = p.bg_dark },
	RainbowDelimiterViolet = { fg = p.function_, bg = p.bg_dark },
	RainbowDelimiterCyan = { fg = p.cyan, bg = p.bg_dark },
}
