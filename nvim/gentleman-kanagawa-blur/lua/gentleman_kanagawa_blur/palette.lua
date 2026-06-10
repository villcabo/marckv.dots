local config = require("gentleman_kanagawa_blur.config")
local get_palette = require("gentleman_kanagawa_blur.variant")

-- Auto-select light variant when background=light
if vim.o.background == "light" then
	return get_palette("lotus_blur")
end

return get_palette(config.variant)
