# nvim-lite

A LazyVim configuration for administering servers over SSH. Not a smaller copy
of the `nvim/` config in this repo — a different set of tradeoffs for a
different machine.

Current version is in [`VERSION`](VERSION). `:LiteVersion` reports it from
inside Neovim, and it is on the start screen.

## Install

From `installer/`:

```bash
./04-install-nvim-lite.sh              # symlink ~/.config/nvim to this directory
./04-install-nvim-lite.sh --copy       # copy it instead, for a host without the repo
```

The default is a symlink, so edits in the repo are live. `--copy` snapshots the
directory and drops `tests/` on the way (176K of the 276K here).

## Reinstall

One command, five steps, in this order:

```bash
./04-install-nvim-lite.sh --reinstall
```

| | | |
|---|---|---|
| 1 | `clean`  | removes `~/.local/share`, `state` and `cache` for nvim |
| 2 | `deps`   | gcc, make, ripgrep, fzf, fd, and the tree-sitter CLI where one can run |
| 3 | `nvim`   | installs the binary, or verifies the installed one is the right version |
| 4 | `config` | symlink or copy |
| 5 | `sync`   | plugins and treesitter parsers, headless |

`deps` runs before `nvim` and `sync` because `gcc` has to exist before step 5
compiles parsers.

Add `-y` to skip every confirmation. Each step is also available on its own
(`-d`, `-s`, `--clean`, `--nvim`) and they compose: `-d -s` runs both.

```bash
./04-install-nvim-lite.sh status      # what is installed, and how big it is
./04-install-nvim-lite.sh uninstall   # removes the config; backs it up if it is a real directory
```

## Supported systems

Debian 10 through 13, Ubuntu 20.04 through 26.04. The Neovim version is chosen
from the machine's GLIBC, because the prebuilt binaries need a recent one:

| GLIBC | Neovim | distros |
|---|---|---|
| 2.34+ | latest | Debian 12+, Ubuntu 22.04+ |
| 2.31+ | v0.10.3 | Debian 11, Ubuntu 20.04 |
| older | v0.9.5 | Debian 10 |

On Neovim 0.9, `lua/config/compat.lua` restores the two functions that arrived
in 0.10 and that plugins now assume (`vim.islist`, and `nvim_get_hl`'s `create`
option). That is why LazyVim runs there at all.

## What it does not ship, and why

No LSP: `nvim-lspconfig`, `mason`, `conform` and `nvim-lint` are off, because
without a completion engine they only produced diagnostics. No `neo-tree` —
`oil.nvim` is the explorer, and `<leader>e` points at it. No completion, no
session restore, no markdown rendering, no cursor animation.

24 treesitter parsers are declared and nothing else installs itself
(`auto_install = false`). Anything outside that list falls back to Vim's regex
syntax: still coloured, less accurate. The list is in
`lua/plugins/treesitter.lua` and adding to it is one edit — the installer reads
it from there.

## Versioning

`VERSION` is semver over the configuration, not over Neovim:

- **major** — something you used is gone, or a keymap changed
- **minor** — new plugins, parsers or filetypes
- **patch** — fixes that change nothing about how it is used

Bump it in the same commit as the change it describes.

## Tests

```bash
cd tests && ./run.sh              # eight distros, in parallel
cd tests && ./run.sh debian10     # one
```

See [`tests/README.md`](tests/README.md).
