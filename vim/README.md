# vim-lite

Plain Vim for the servers this repo supports, made to feel like nvim-lite where
it matters for support work: finding a file and grepping for a string.

**No plugins, no plugin manager, nothing downloaded or compiled.** Installing it
is copying this directory. That is the whole point: nvim-lite needs LazyVim and
~100 MB of plugins cloned from GitHub, treesitter parsers compiled with gcc, a
tree-sitter CLI and fzf. None of that can be installed on a host with no
internet, and downloading and running binaries is exactly what an EDR such as
CrowdStrike Falcon watches for.

## Install

```bash
cd ~/.marckv.dots/installer
./06-install-vim.sh            # ~/.vim -> this directory (repo edits are live)
./06-install-vim.sh --copy     # a copy, for a host that should not depend on the repo
./06-install-vim.sh status
./install.sh --editor vim      # the whole setup, with vim-lite instead of Neovim
marckv install vim             # the same, from anywhere
```

For a host with no internet — install once by hand, then update from a git
bundle with `marckv update --from` — see **Offline** in the repo's README.

The installer refuses to go past a `~/.vimrc` (Vim reads it *instead of*
`~/.vim/vimrc`) or a `~/.vim` it did not create. If the host has no Vim, or
only `vim-tiny`, it installs `vim` from apt when it has root or sudo, and
otherwise says what to ask an admin for.

## Keys

`<Space>` is the leader. Open `vim` with no file, or press `<Space>?`, for this
list on screen.

| Key | What |
|---|---|
| `<Space><Space>` | Find a file — fuzzy, with the menu open as you type |
| `<Space>/` | Grep, live: matches from the third character. Pick one to open it at that line; `<Enter>` without picking fills the quickfix list |
| `<Space>sw` | Grep the word under the cursor |
| `<Space>fr` | Recent files |
| `<Space>,` | Switch buffer |
| `-` / `<Space>e` | Explorer (netrw) |
| `<Space>cf` | Change filetype |
| `gc` / `gcc` | Comment the selection / line |
| `<C-s>` | Save |
| `:W` | Save through sudo — logged in as a user, editing a root file |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<C-h/j/k/l>` | Move between splits, and into tmux panes when there is none left |
| `<F5>` | Reload the file from disk |

File listing and grep use the fastest tool on the box — `rg`, then `fdfind`,
then `find`/`grep` — so nothing has to be installed for them to work. The file
list is capped at 30,000 entries, so starting from `/` does not walk the disk.

## What it does that plain Vim does not

- **Swap, backup and undo files go to `~/.local/state/vim`.** By default Vim
  leaves `.nginx.conf.swp` next to `/etc/nginx/nginx.conf`, in a directory the
  service reads. netrw's history goes there too, never into `~/.vim`, which is
  the repo.
- **UTF-8 regardless of the locale.** Reached over ssh with no `LANG`, Vim
  starts in latin1 and every `»`, `·` or `│` in the settings errors on start.
- **Big files open with syntax off** (over 2 MB, `g:lite_bigfile_size`). A
  500 MB log with syntax and undo on is how Vim freezes on a server.
- **Yanks reach the laptop's clipboard over ssh** (OSC 52, Vim 9.1). Yanks
  only: pasting through OSC 52 blocks on terminals that do not answer.
- **The gentleman theme** when the terminal shows 24-bit colour, `habamax`
  (or `desert`) when it does not. `g:lite_truecolor = 0` forces the fallback.

## Which Vim gets what

Measured per distro, not read off release notes — Ubuntu 24.04 and Debian 13
both say "9.1" and differ in exactly the features that matter here:

| Distro | Vim | Live menu as you type | Fuzzy `:find` | `gc` | OSC 52 |
|---|---|---|---|---|---|
| Ubuntu 26.04 | 9.1.2141 | yes | yes | yes | yes |
| Debian 13 | 9.1.1230 | — | yes, with `<Tab>` | yes | — |
| Ubuntu 24.04, Debian 12, Ubuntu 22.04, Debian 11, Ubuntu 20.04 | 9.1.0016 … 8.1.2269 | — | — | — | — |
| Debian 10 | 8.1.0875 | `vimrc` only: `plugin/lite.vim` needs 8.1.1372 | | | |
| vim-tiny | minimal Debian | the top of `vimrc`, without errors — install `vim` for the rest | | | |

Where a feature is missing, the key still works the older way:
`<Space><Space>` is the plain `:find` over `**` with `<Tab>` completion, and
`<Space>/` is `:Grep` completed with `<Tab>`. Everything else — the keys, the
statusline, the theme, big files, `:W`, the start screen — works from 8.1.1372.

## Layout

```
vim/
├── vimrc               # tiny-safe settings, then `if 1` for the rest
├── plugin/lite.vim     # pickers, keys, statusline, big files, :W, start screen
├── colors/gentleman.vim  # generated from gentleman-kanagawa-blur
├── VERSION             # semver over this config
└── tests/              # ./run.sh — eight distros
```

`colors/gentleman.vim` is **generated**: every colour is what the Neovim theme
resolves that group to (`nvim_get_hl`, links followed). Regenerate it the same
way rather than editing colours by hand.

## Traps, each paid for once

- `packadd!` (with `!`) in a `plugin/` file never loads the package: that step
  of startup has already run. Use `packadd`.
- Mapping `<Esc>` in normal mode breaks the arrow keys in terminal Vim — they
  start with an Esc too.
- `set fillchars+=eob:` does not exist before Vim 8.2.2508 (Debian 11 has
  8.2.2434), and an unknown flag fails the whole `set` line.
- Filetype detection runs after `BufReadPost` and its `Syntax` turns syntax
  back on: the big-file guard also hooks `FileType`.
