local p = require("gentleman_kanagawa_blur.palette")
return {
	GitSignsAdd = { fg = p.string },
	GitSignsChange = { fg = p.operator },
	GitSignsDelete = { fg = p.variable },
}
