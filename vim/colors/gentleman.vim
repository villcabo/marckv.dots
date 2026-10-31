" gentleman — gentleman-kanagawa-blur, for plain Vim.
"
" Generated, not hand-picked: every colour below is what the Neovim theme
" resolves the same group to (nvim_get_hl with links followed), dumped from
" Neovim with the theme loaded. Two changes on purpose:
"   - StatusLine/StatusLineNC get a background. lualine draws its own bar in
"     nvim-lite; Vim's built-in statusline would otherwise be invisible.
"   - VertSplit takes WinSeparator's colours, the name Vim uses for it.
" Normal has no background, as in the theme: the terminal's shows through.
"
" GUI colours only: plugin/lite.vim selects this scheme when the terminal
" can show 24-bit colour, and falls back to habamax when it cannot.

set background=dark
hi clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'gentleman'

hi Normal guifg=#f3f6f9 guibg=NONE gui=NONE
hi NormalFloat guifg=#f3f6f9 guibg=NONE gui=NONE
hi Comment guifg=#8394a3 guibg=NONE gui=italic
hi Constant guifg=#cb7c94 guibg=NONE gui=NONE
hi String guifg=#dfbd76 guibg=NONE gui=NONE
hi Character guifg=#dfbd76 guibg=NONE gui=NONE
hi Number guifg=#a4daa7 guibg=NONE gui=NONE
hi Float guifg=#a4daa7 guibg=NONE gui=NONE
hi Identifier guifg=#f3f6f9 guibg=NONE gui=NONE
hi Function guifg=#b99bf2 guibg=NONE gui=NONE
hi Statement guifg=#8fa2d1 guibg=NONE gui=NONE
hi Conditional guifg=#c99ad6 guibg=NONE gui=NONE
hi Repeat guifg=#c99ad6 guibg=NONE gui=NONE
hi Label guifg=#8d9ef2 guibg=NONE gui=NONE
hi Operator guifg=#deba87 guibg=NONE gui=NONE
hi Keyword guifg=#c99ad6 guibg=NONE gui=NONE
hi Exception guifg=#c99ad6 guibg=NONE gui=NONE
hi PreProc guifg=#a3b5d6 guibg=NONE gui=NONE
hi Include guifg=#a3b5d6 guibg=NONE gui=NONE
hi Define guifg=#a3b5d6 guibg=NONE gui=NONE
hi Macro guifg=#a3b5d6 guibg=NONE gui=NONE
hi PreCondit guifg=#a3b5d6 guibg=NONE gui=NONE
hi Type guifg=#8fb8dd guibg=NONE gui=NONE
hi StorageClass guifg=#8fb8dd guibg=NONE gui=NONE
hi Structure guifg=#a6d9ca guibg=NONE gui=NONE
hi Typedef guifg=#8fb8dd guibg=NONE gui=NONE
hi Special guifg=#8d9ef2 guibg=NONE gui=NONE
hi Tag guifg=#8d9ef2 guibg=NONE gui=NONE
hi Delimiter guifg=#e0e2ea guibg=NONE gui=NONE
hi SpecialComment guifg=#8394a3 guibg=NONE gui=NONE
hi Debug guifg=#b5e4ff guibg=NONE gui=NONE
hi Underlined guifg=NONE guibg=NONE gui=underline
hi Error guifg=#c4746e guibg=NONE gui=NONE
hi Todo guifg=#ca8fb9 guibg=NONE gui=NONE
hi Added guifg=#b3f6c0 guibg=NONE gui=NONE
hi Changed guifg=#8cf8f7 guibg=NONE gui=NONE
hi Removed guifg=#ffc0b9 guibg=NONE gui=NONE
hi LineNr guifg=#5c6170 guibg=NONE gui=NONE
hi CursorLineNr guifg=#e0c15a guibg=NONE gui=NONE
hi CursorLine guifg=NONE guibg=#191e28 gui=NONE
hi CursorColumn guifg=NONE guibg=#2c2e33 gui=NONE
hi ColorColumn guifg=NONE guibg=#191e28 gui=NONE
hi SignColumn guifg=#5c6170 guibg=NONE gui=NONE
hi StatusLine guifg=#f3f6f9 guibg=#191e28 gui=NONE
hi StatusLineNC guifg=#5c6170 guibg=#191e28 gui=NONE
hi WinSeparator guifg=#232a40 guibg=NONE gui=NONE
hi Pmenu guifg=#f3f6f9 guibg=#06080f gui=NONE
hi PmenuSel guifg=#f3f6f9 guibg=#232a36 gui=bold
hi PmenuSbar guifg=NONE guibg=#232a40 gui=NONE
hi PmenuThumb guifg=NONE guibg=#313342 gui=NONE
hi PmenuMatch guifg=NONE guibg=NONE gui=bold
hi PmenuMatchSel guifg=NONE guibg=NONE gui=bold
hi Visual guifg=NONE guibg=#3b4261 gui=bold
hi Search guifg=#e0c15a guibg=#232a36 gui=NONE
hi IncSearch guifg=#06080f guibg=#e0c15a gui=NONE
hi CurSearch guifg=#06080f guibg=#e0c15a gui=NONE
hi MatchParen guifg=#e0c15a guibg=#232a36 gui=bold
hi NonText guifg=#5c6170 guibg=NONE gui=NONE
hi SpecialKey guifg=#5c6170 guibg=NONE gui=NONE
hi Whitespace guifg=#5c6170 guibg=NONE gui=NONE
hi Folded guifg=#27345c guibg=NONE gui=NONE
hi FoldColumn guifg=#5c6170 guibg=NONE gui=NONE
hi DiffAdd guifg=#d1e8a9 guibg=#1e2d1e gui=NONE
hi DiffChange guifg=#ffe066 guibg=#2d2a1e gui=NONE
hi DiffDelete guifg=#e2b93d guibg=#2d211e gui=NONE
hi DiffText guifg=#fff7b1 guibg=#332f1e gui=NONE
hi ErrorMsg guifg=#deba87 guibg=NONE gui=NONE
hi WarningMsg guifg=#ffe066 guibg=NONE gui=NONE
hi MoreMsg guifg=#ffaeea guibg=NONE gui=NONE
hi ModeMsg guifg=#313342 guibg=NONE gui=bold
hi Question guifg=#a3b5d6 guibg=NONE gui=NONE
hi Title guifg=#b7cc85 guibg=NONE gui=NONE
hi Directory guifg=#a3b5d6 guibg=NONE gui=NONE
hi TabLine guifg=#5c6170 guibg=NONE gui=NONE
hi TabLineFill guifg=NONE guibg=#06080f gui=NONE
hi TabLineSel guifg=#f3f6f9 guibg=NONE gui=NONE
hi WildMenu guifg=#06080f guibg=#a3b5d6 gui=NONE
hi QuickFixLine guifg=#cb7c94 guibg=#232a36 gui=bold
hi Conceal guifg=#191e28 guibg=NONE gui=NONE
hi SpellBad guifg=#deba87 guibg=#1c212c gui=NONE
hi SpellCap guifg=#e0c15a guibg=#1c212c gui=NONE
hi SpellRare guifg=#e0c15a guibg=#1c212c gui=NONE
hi SpellLocal guifg=#e0c15a guibg=#1c212c gui=NONE
hi Cursor guifg=#06080f guibg=#f3f6f9 gui=NONE
hi VisualNOS guifg=NONE guibg=#3b4261 gui=NONE
hi VertSplit guifg=#232a40 guibg=NONE gui=NONE
