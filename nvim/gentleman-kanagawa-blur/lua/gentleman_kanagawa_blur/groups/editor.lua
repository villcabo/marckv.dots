local p = require("gentleman_kanagawa_blur.palette")
local is_light = vim.o.background == "light"

return {
	-- Fondo y texto principal
	Normal = { fg = p.fg, bg = p.bg_dark },
	NormalNC = { fg = p.fg, bg = p.bg_dark },
	NormalFloat = { fg = p.fg, bg = is_light and p.bg_dark or p.gray0 },

	-- Elementos de UI
	ColorColumn = { bg = is_light and p.bg_dark or p.gray1 },
	CursorLine = { bg = is_light and "#EFEAE1" or p.gray1 },
	Conceal = { fg = p.gray1 },
	SignColumn = { bg = "none", fg = p.fg_muted },
	FoldColumn = { bg = "none", fg = p.fg_muted },
	VertSplit = { fg = p.gray2 },
	WinSeparator = { fg = p.gray2 },
	EndOfBuffer = { fg = "none" },

	-- Cursor y selección (con subtle background)
	Cursor = { fg = p.black, bg = p.fg },
	lCursor = { fg = p.black, bg = p.fg },
	CursorIM = { fg = p.black, bg = p.fg },
	Visual = { bg = p.surface1, bold = true },
	VisualNOS = { bg = p.surface1 },

	-- Directorios y títulos
	Directory = { fg = p.purple },
	Title = { fg = p.green },

	-- Diffs y Git (con backgrounds más sutiles)
	DiffAdd = { bg = p.diff_add_bg, fg = p.bright_green },
	DiffChange = { bg = p.diff_change_bg, fg = p.yellow },
	DiffDelete = { bg = p.diff_delete_bg, fg = p.bright_orange },
	DiffText = { bg = p.diff_text_bg, fg = p.bright_yellow },

	-- Mensajes
	ErrorMsg = { fg = p.orange },
	WarningMsg = { fg = p.yellow },
	ModeMsg = { fg = p.gray3, bold = true },
	MoreMsg = { fg = p.bright_magenta },
	Question = { fg = p.purple },

	-- Número de línea
	LineNr = { fg = p.gray5 },
	CursorLineNr = { fg = p.accent }, -- Usamos accent para el número de línea activa

	-- Pmenu (menú de autocompletado) con subtle background
	Pmenu = { fg = p.fg, bg = is_light and p.surface0 or p.black },
	PmenuSel = { fg = is_light and p.fg or p.white, bg = p.surface1, bold = true },
	PmenuSbar = { bg = p.gray2 },
	PmenuThumb = { bg = p.gray3 },

	-- Búsqueda (con subtle background como Catppuccin)
	Search = { fg = p.accent, bg = p.surface1 },
	IncSearch = { fg = is_light and p.fg or p.black, bg = p.accent },
	CurSearch = { fg = is_light and p.fg or p.black, bg = p.accent },

	-- Otros
	Folded = { fg = p.gray4 },
	MatchParen = { fg = p.accent, bg = p.surface1, bold = true },
	NonText = { fg = p.fg_muted },
	FloatBorder = { fg = p.gray5, bg = "none" },
	QuickFixLine = { fg = p.red, bg = p.surface1, bold = true },
	SpecialKey = { fg = p.fg_muted },
	SpellBad = { fg = p.orange, bg = p.surface0 },
	SpellCap = { fg = p.accent, bg = p.surface0 },
	SpellLocal = { fg = p.accent, bg = p.surface0 },
	SpellRare = { fg = p.accent, bg = p.surface0 },

	-- Barra de estado y pestañas
	StatusLine = { fg = p.fg, bg = is_light and p.gray1 or p.bg_dark },
	StatusLineNC = { fg = p.fg_muted, bg = is_light and p.gray1 or p.bg_dark },
	StatusLineTerm = { fg = p.fg, bg = p.gray1 },
	StatusLineTermNC = { fg = p.fg_muted, bg = is_light and p.gray1 or p.bg_dark },
	TabLine = { fg = p.fg_muted },
	TabLineFill = { bg = is_light and p.surface0 or p.black },
	TabLineSel = { fg = p.fg },

	-- Terminal
	Terminal = { fg = p.fg, bg = is_light and p.surface0 or p.black },

	-- Winbar
	Winbar = { fg = p.fg, bg = p.gray1 },
	WinbarNC = { fg = p.fg_muted, bg = is_light and p.gray1 or p.bg_dark },

	-- Estilo Italic (si se usa explícitamente)
	Italic = { fg = p.blue, italic = true },
	WildMenu = { fg = is_light and p.fg or p.black, bg = p.purple },
}
