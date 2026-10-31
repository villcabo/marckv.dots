" vim-lite: what makes plain Vim feel like nvim-lite on a server.
"
" Loaded by Vim itself from ~/.vim/plugin/. Everything here is Vim script that
" ships with Vim — no plugin, no download, no compiler. What each feature
" needs is checked where it is used, not assumed from a version number:
" findfunc and wildtrigger (the live menus) exist only in recent 9.1 builds
" — measured, Ubuntu 26.04 has both and Ubuntu 24.04's 9.1 has neither — and
" everything older gets the same keys as the plain :find and :Grep.
"
" The floor is 8.1.1372, for g:statusline_winid: Ubuntu 20.04 ships 8.1.2269
" and gets everything below. Debian 10's 8.1.0875 does not, and keeps vimrc.

scriptencoding utf-8

if exists('g:loaded_lite') || !has('patch-8.1.1372')
  finish
endif
let g:loaded_lite = 1

let s:dir = expand('<sfile>:p:h:h')
let s:version = filereadable(s:dir . '/VERSION') ? trim(readfile(s:dir . '/VERSION')[0]) : '?'

" --- State: swap, backup, undo and netrw history, out of ~/.vim ------------
"
" ~/.vim is this repo when installed as a symlink. Vim's defaults write undo
" files, and netrw its .netrwhist, into the first runtimepath entry — that is,
" into the git checkout, where they show up as untracked files on every pull.
let s:state = expand('~/.local/state/vim')
for s:sub in ['swap', 'backup', 'undo']
  if !isdirectory(s:state . '/' . s:sub)
    silent! call mkdir(s:state . '/' . s:sub, 'p', 0700)
  endif
endfor
let &undodir = s:state . '/undo//'
set undofile
let g:netrw_home = s:state

" --- Options -------------------------------------------------------------
set relativenumber cursorline
set sidescrolloff=8 smartindent
set mouse=a noshowmode confirm updatetime=300
set signcolumn=yes belloff=all autoread
set list listchars=tab:»\ ,trail:·,nbsp:␣
set fillchars=vert:│
" eob: is Vim 8.2.2508+; Debian 11 has 8.2.2434, where it fails the whole line
silent! execute 'set fillchars+=eob:\ '
set shortmess+=I
set completeopt=menu,menuone,noselect
set path=.,** wildignore+=*/.git/*,*/node_modules/*
set wildmenu
silent! set wildoptions=pum
silent! set wildoptions+=fuzzy
" Menu opens as you type with nothing preselected (Vim 9.1); classic otherwise
silent! set wildmode=noselect:lastused,full

" Packages that ship with Vim itself. No `!`: this file already runs during
" Vim's plugin-loading step, so `packadd!` would add them to runtimepath after
" the moment their plugin/ files get sourced, and gc would never exist.
silent! packadd comment      " gc / gcc to comment, as in nvim-lite
silent! packadd hlyank       " flash what was yanked
silent! packadd nohlsearch   " clear the search highlight once you move on
silent! packadd matchit

" --- Colours -------------------------------------------------------------
"
" gentleman when the terminal can show 24-bit colour, habamax (or desert on
" Vim 8.2) when it cannot: gentleman is GUI colours only, and on a 256-colour
" terminal it would come out as the terminal's defaults. COLORTERM rarely
" survives ssh, so a 256color TERM counts as capable too — every terminal
" that reports one today also does truecolor. g:lite_truecolor = 0 forces
" the fallback.
let s:truecolor = has('termguicolors') && get(g:, 'lite_truecolor', 1)
      \ && ($COLORTERM =~? 'truecolor\|24bit'
      \     || $TERM =~? '256color\|kitty\|direct\|truecolor\|ghostty\|wezterm\|alacritty')
if s:truecolor
  if $TERM =~# '^\%(screen\|tmux\)'
    " tmux needs these spelled out; xterm-* gets them from Vim already
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  endif
  set termguicolors
  silent! colorscheme gentleman
endif
if get(g:, 'colors_name', '') !=# 'gentleman'
  silent! colorscheme habamax
  if get(g:, 'colors_name', '') !=# 'habamax'
    silent! colorscheme desert
  endif
endif

" --- Statusline: the mode, coloured, as lualine shows it -------------------
let s:modes = {'n': ['NORMAL', 'N'], 'i': ['INSERT', 'I'], 'v': ['VISUAL', 'V'],
      \ 'V': ['V-LINE', 'V'], "\<C-v>": ['V-BLOCK', 'V'], 's': ['SELECT', 'V'],
      \ 'R': ['REPLACE', 'R'], 'c': ['COMMAND', 'C'], 't': ['TERMINAL', 'C']}

function! s:StatusColours() abort
  let fg = '#06080f'
  for [k, bg, cterm] in [['N', '#8fb8dd', 110], ['I', '#b7cc85', 150], ['V', '#c99ad6', 176],
        \ ['R', '#c4746e', 167], ['C', '#e0c15a', 179]]
    execute printf('hi LiteMode%s guifg=%s guibg=%s gui=bold ctermfg=234 ctermbg=%d cterm=bold',
          \ k, fg, bg, cterm)
  endfor
endfunction
call s:StatusColours()
augroup lite_colours
  autocmd!
  autocmd ColorScheme * call s:StatusColours()
augroup END

function! LiteStatus() abort
  let [name, key] = get(s:modes, mode(), [mode(), 'N'])
  if g:statusline_winid != win_getid()
    return ' %f %m%r%=%y '
  endif
  return '%#LiteMode' . key . '# ' . name . ' %#StatusLine# %f %m%r'
        \ . (get(b:, 'lite_bigfile', 0) ? ' [big]' : '')
        \ . '%=%y  %{&fileencoding?&fileencoding:&encoding}  %l:%c  %p%% '
endfunction
set statusline=%!LiteStatus()

" --- Files: <Space><Space> -------------------------------------------------
"
" :find with a fuzzy function behind it. The list comes from the fastest tool
" on the box, once per prompt rather than once per keystroke, and is capped:
" started from / it would otherwise walk the whole disk.
let s:list_cmd = executable('rg') ? 'rg --files --hidden --glob "!.git"'
      \ : executable('fdfind') ? 'fdfind --type f --hidden --exclude .git'
      \ : executable('fd') ? 'fd --type f --hidden --exclude .git'
      \ : 'find . -type f -not -path "*/.git/*" | sed "s|^\./||"'

function! LiteFind(arg, cmdcomplete) abort
  if !exists('s:files')
    let s:files = systemlist(s:list_cmd . ' 2>/dev/null | head -n 30000')
  endif
  return empty(a:arg) ? s:files : matchfuzzy(s:files, a:arg)
endfunction
if exists('+findfunc')
  set findfunc=LiteFind
endif

" --- Grep: <Space>/ --------------------------------------------------------
"
" Live: matches appear from the third character. Picking one opens it at that
" line; <Enter> without picking sends every match to the quickfix list.
let s:grep_cmd = executable('rg')
      \ ? 'rg --vimgrep --smart-case --hidden --glob "!.git" --max-count 20 -- '
      \ : 'grep -rnIi --exclude-dir=.git -m 20 -- '
let s:grep_dot = executable('rg') ? '' : ' .'
" Each keystroke runs the search again; bounded so a huge tree cannot freeze
" the prompt.
let s:timeout = executable('timeout') ? 'timeout 2 ' : ''

function! LiteGrepComplete(arglead, cmdline, pos) abort
  let q = substitute(a:cmdline, '^\s*Grep\s\+', '', '')
  if strchars(q) < 3
    return []
  endif
  return systemlist(s:timeout . s:grep_cmd . shellescape(q) . s:grep_dot
        \ . ' 2>/dev/null | cut -c1-200 | head -n 300')
endfunction

function! s:Grep(args) abort
  let m = matchlist(a:args, '\(\f\+\):\(\d\+\):\%(\(\d\+\):\)\?')
  if !empty(m) && filereadable(m[1])
    execute 'edit +' . m[2] . ' ' . fnameescape(m[1])
    if m[3] !=# ''
      call cursor(str2nr(m[2]), str2nr(m[3]))
    endif
    normal! zz
    return
  endif
  let &l:grepprg = substitute(s:grep_cmd, ' -- $', '', '')
  execute 'silent grep! -- ' . shellescape(a:args) . s:grep_dot
  copen
  redraw!
endfunction
command! -nargs=+ -complete=customlist,LiteGrepComplete Grep call s:Grep(<q-args>)

" --- Recent files: <Space>fr ----------------------------------------------
function! LiteRecentComplete(arglead, cmdline, pos) abort
  let files = filter(copy(v:oldfiles), 'filereadable(expand(v:val))')
  if empty(a:arglead)
    return files
  endif
  " matchfuzzy is 8.2.1665; a plain substring match before that
  return exists('*matchfuzzy') ? matchfuzzy(files, a:arglead)
        \ : filter(files, 'stridx(v:val, a:arglead) >= 0')
endfunction
command! -nargs=1 -complete=customlist,LiteRecentComplete Recent execute 'edit ' . fnameescape(<q-args>)

if exists('*wildtrigger')
  augroup lite_pickers
    autocmd!
    autocmd CmdlineEnter : unlet! s:files
    autocmd CmdlineChanged : if getcmdline() =~# '^\%(fin\%[d]\|Grep\|Recent\|b\%[uffer]\|setf\%[iletype]\) '
          \ | call wildtrigger() | endif
  augroup END
endif

" --- Windows: into tmux when there is no split left -----------------------
"
" Same as nvim-tmux-navigation in nvim-lite: only Vim's side. From a tmux pane
" back into Vim is tmux's prefix + arrow, since tmux.conf binds nothing for it.
function! s:Navigate(dir) abort
  let nr = winnr()
  execute 'wincmd ' . a:dir
  if nr == winnr() && !empty($TMUX)
    if trim(system('tmux display-message -p "#{window_zoomed_flag}"')) !=# '1'
      call system('tmux select-pane -' . tr(a:dir, 'hjkl', 'LDUR'))
    endif
  endif
endfunction

" --- Big files: syntax off ------------------------------------------------
"
" A 500 MB log with syntax and undo on is how Vim freezes on a server.
" nvim-lite gets this from snacks' bigfile; this is the same idea in Vim.
let g:lite_bigfile_size = get(g:, 'lite_bigfile_size', 2 * 1024 * 1024)
augroup lite_bigfile
  autocmd!
  autocmd BufReadPre * let s:size = getfsize(expand('<afile>'))
        \ | if s:size > g:lite_bigfile_size || s:size == -2
        \ |   let b:lite_bigfile = 1 | setlocal noundofile noswapfile
        \ | endif
  " FileType too: filetype detection runs after this BufReadPost (setfiletype
  " below, and Vim's own), and the Syntax it triggers would switch it back on.
  autocmd BufReadPost,FileType * if get(b:, 'lite_bigfile', 0)
        \ | setlocal syntax=OFF foldmethod=manual norelativenumber nocursorline
        \ | endif
augroup END

" --- Save as root: :W -----------------------------------------------------
"
" Logged in as a user, editing a file root owns: write it through sudo.
command! W execute 'write !sudo tee ' . shellescape(expand('%:p'), 1) . ' >/dev/null'
      \ | if !v:shell_error | edit! | endif

" --- Clipboard over SSH: yanks reach the laptop ---------------------------
"
" osc52 ships with Vim 9.1. Yanks only: pasting through OSC 52 blocks on
" terminals that do not answer, so `p` keeps using Vim's own registers.
if has('vim9script') && !empty(globpath(&packpath, 'pack/*/opt/osc52'))
  silent! packadd osc52
  silent! set clipmethod+=osc52
  augroup lite_osc52
    autocmd!
    autocmd TextYankPost * if v:event.operator ==# 'y' && get(v:, 'clipmethod', '') =~# 'osc52'
          \ | call setreg('+', v:event.regcontents, v:event.regtype) | endif
  augroup END
endif

" --- Filetypes nvim-lite recognises ---------------------------------------
augroup lite_filetypes
  autocmd!
  autocmd BufRead,BufNewFile *.log,*.log.*,/var/log/* setfiletype messages
  autocmd BufRead,BufNewFile docker-compose*.y*ml,compose*.y*ml setfiletype yaml
  autocmd BufRead,BufNewFile *.service,*.timer,*.socket,*.mount,*.target setfiletype systemd
  autocmd BufRead,BufNewFile nginx.conf,*/nginx/*.conf setfiletype nginx
  autocmd BufRead,BufNewFile */hosts setfiletype conf
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line('$') | execute 'normal! g`"' | endif
  autocmd FocusGained,BufEnter * silent! checktime
augroup END

" --- Keymaps: nvim-lite's -------------------------------------------------
"
" One list, used three times: the mappings, the start screen and <Space>?.
let s:keys = [
      \ ['n', '<leader><leader>', ':find<Space>', 'Find file'],
      \ ['n', '<leader>/', ':Grep<Space>', 'Grep (live)'],
      \ ['n', '<leader>sw', ':Grep <C-r><C-w>', 'Grep word under cursor'],
      \ ['n', '<leader>fr', ':Recent<Space>', 'Recent files'],
      \ ['n', '<leader>,', ':buffer<Space>', 'Switch buffer'],
      \ ['n', '<leader>e', ':Explore<CR>', 'Explorer (netrw)'],
      \ ['n', '-', ':Explore<CR>', 'Explorer (netrw)'],
      \ ['n', '<leader>cf', ':setfiletype<Space>', 'Change filetype'],
      \ ['n', '<leader>w', ':write<CR>', 'Save'],
      \ ['n', '<leader>q', ':quit<CR>', 'Quit'],
      \ ['n', '<leader>bd', ':bdelete<CR>', 'Close buffer'],
      \ ['n', '<leader>bq', ':%bdelete<Bar>edit #<Bar>normal `"<CR>', 'Close other buffers'],
      \ ['n', '<leader>br', ':checktime<CR>', 'Reload file from disk'],
      \ ['n', '<leader>md', ':delmarks!<Bar>delmarks A-Z0-9<CR>', 'Delete all marks'],
      \ ['n', '<leader>?', ':call LiteKeys()<CR>', 'This list'],
      \ ]
for [s:mode, s:lhs, s:rhs, s:desc] in s:keys
  execute s:mode . 'noremap ' . s:lhs . ' ' . s:rhs
endfor

nnoremap <C-s> :update<CR>
inoremap <C-s> <C-o>:update<CR>
nnoremap <S-h> :bprevious<CR>
nnoremap <S-l> :bnext<CR>
nnoremap <silent> <C-h> :call <SID>Navigate('h')<CR>
nnoremap <silent> <C-j> :call <SID>Navigate('j')<CR>
nnoremap <silent> <C-k> :call <SID>Navigate('k')<CR>
nnoremap <silent> <C-l> :call <SID>Navigate('l')<CR>
nnoremap <F5> :checktime<CR>
inoremap <C-c> <Esc>
inoremap <C-b> <C-o>de
vnoremap < <gv
vnoremap > >gv

let g:netrw_banner = 0
let g:netrw_liststyle = 3

" --- Start screen and <Space>? --------------------------------------------
let s:other = [
      \ ['gc / gcc', 'Comment selection / line'], ['<C-s>', 'Save'],
      \ ['<S-h> / <S-l>', 'Previous / next buffer'], ['<C-h/j/k/l>', 'Move between splits and tmux panes'],
      \ ['<F5>', 'Reload file from disk'], [':W', 'Save through sudo'],
      \ ]

" Padded by display width: printf's %-14s counts bytes, and ␣ is three of
" them, so every leader key came out two columns short.
function! s:Pad(text, width) abort
  return a:text . repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

function! s:KeyLines() abort
  let lines = []
  for [m, lhs, rhs, desc] in s:keys
    call add(lines, '  ' . s:Pad(substitute(lhs, '<leader>', '␣', 'g'), 15) . desc)
  endfor
  call add(lines, '')
  for [lhs, desc] in s:other
    call add(lines, '  ' . s:Pad(lhs, 15) . desc)
  endfor
  return lines
endfunction

function! LiteKeys() abort
  if exists('*popup_create')
    call popup_create(s:KeyLines(), {'title': ' vim-lite ' . s:version . ' ', 'pos': 'center',
          \ 'border': [], 'padding': [0, 1, 0, 1], 'highlight': 'Pmenu', 'mapping': 0,
          \ 'filter': {id, key -> popup_close(id) || 1}})
  else
    echo join(s:KeyLines(), "\n")
  endif
endfunction

function! s:StartScreen() abort
  if argc() || line2byte('$') != -1 || get(g:, 'lite_stdin', 0) || &insertmode
    return
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nocursorline nolist signcolumn=no
  let host = substitute(system('hostname'), '\n', '', 'g')
  " $USER is empty under `su` without a login shell and in `docker exec`
  let user = empty($USER) ? trim(system('id -un')) : $USER
  call setline(1, ['', '  vim-lite ' . s:version . '   ·   ' . user . '@' . host
        \ . '   ·   vim ' . (v:version / 100) . '.' . (v:version % 100), ''] + s:KeyLines())
  setlocal nomodifiable nomodified
endfunction

command! LiteVersion echo 'vim-lite ' . s:version . '  (' . s:dir . ')'

augroup lite_start
  autocmd!
  autocmd StdinReadPre * let g:lite_stdin = 1
  autocmd VimEnter * call s:StartScreen()
augroup END
