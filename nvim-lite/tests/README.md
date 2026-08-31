# nvim-lite tests

```bash
cd nvim-lite/tests
./run.sh                 # every distro
./run.sh debian12        # one — the awkward GLIBC 2.36 case
```

Runs only in containers. Every scenario installs Neovim into `/opt`, replaces
`~/.config/nvim` and clones the whole plugin set.


## No edites el repo mientras corre la suite

Los contenedores montan el repo **en vivo** (read-only, pero en vivo). Un archivo
Lua guardado a medias mientras un distro lo está leyendo produce una cascada de
fallos que parecen del código y son del editor: en una corrida, Ubuntu 20.04
reportó 9 errores — `starts`, `lazy reports what the config disables`, `the
LazyVim core is intact` — todos a la vez, que es la firma de un archivo
incompleto y no la de un bug.

Si tenés que cambiar algo, esperá a que termine, o corré primero el distro que
te interesa (`./run.sh debian10`) y editá después.

## Why this suite exists

`nvim-lite` shipped for months without a single treesitter parser on any
server. Not yaml, not json, not dockerfile. Nobody noticed, because Vim's
legacy regex syntax takes over and the file still comes out coloured — it just
stops understanding the structure. The bug was visible only as "the
highlighting feels poor".

Nothing about that is catchable by reading the config. It depends on the
distro's GLIBC, in two different ways, and the only way to know is to run it on
each one.

## Design rules

These came out of this component breaking, not from a style guide.

**Test that it RUNS, not that it exists.** A Neovim built for a newer GLIBC
answers `command -v` perfectly and dies the moment it is executed. The first
version of this suite used `command -v nvim`, inherited a broken binary the
test images were shipping, and reported six failures on Ubuntu 20.04 that had
nothing to do with treesitter. The same mistake had already been fixed in
`install-nvim.sh` a week earlier — `[ -x file ]` there, `command -v` here.
Presence is not capability, for a binary or for a parser.

**Assert on the live highlighter, not on the file on disk.** A parser sitting
in `parser/yaml.so` proves the download worked. What matters is
`vim.treesitter.highlighter.active[buf]` — whether the editor is actually using
it. Every other assertion in S3 passed on a machine that was rendering the file
with regex syntax.

**Read the GLIBC floor off the binary, never from documentation.** Every
version pin in this component came from `objdump -T … | grep GLIBC_`:

| | GLIBC floor |
|---|---|
| Neovim v0.12.5 / v0.10.3 / v0.9.5 | 2.34 / 2.29 / 2.14 |
| tree-sitter CLI v0.26.13 / v0.25.10 / v0.24.7 | 2.39 / 2.34 / 2.29 |

The CLI's floor is the one that matters most and the least obvious: mason
fetches the newest, which needs **2.39**, so Debian 12 (2.36) and Ubuntu 22.04
(2.35) get a binary that cannot start and every install reports
`Installed 0/16 languages`.

**Both parser directories, always.** nvim-treesitter's `master` branch keeps
parsers inside the plugin directory; its `main` branch writes them to the site
directory. A check against one of them passes or fails according to the distro
rather than according to whether anything worked.

**The distro matrix is not thoroughness, it is the test.** Two GLIBC bands
behave completely differently:

| GLIBC | Neovim | nvim-treesitter | needs |
|---|---|---|---|
| 2.28 – 2.33 | 0.9 / 0.10 | `master` | a C compiler |
| 2.34+ | latest | `main` | a working tree-sitter CLI |

Debian 11 passing says nothing about Debian 12, and Debian 12 passing said
nothing about Ubuntu 20.04 — which is how the broken image slipped through.

**A test that cannot fail is not a test.** Plant the regression and watch it go
red before believing a green run. This suite has already caught three of its
own false positives that way:

- `TSInstallSync` reported "the parser cannot be built" when the command did
  not exist, because the plugin was lazy-loaded and never came up
- `pcall(vim.treesitter.get_parser, …)` returned true on a machine with no
  parsers at all: since Neovim 0.11 it returns `nil` instead of throwing, so
  `pcall` succeeds either way
- looking for `yaml.so` in one directory reported failure on the distros that
  write it to the other one

Each of those made the suite say the opposite of the truth.

## The fixture

`fixtures/docker-compose.yml` is not a minimal file on purpose. It carries
anchors (`&common`), aliases (`<<: *common`), block scalars, flow collections
and `${VAR:-default}` — the shapes where regex syntax degrades and a parser
does not. A fixture of three flat keys looks identical either way, and would
have passed all through the outage this suite exists to prevent.
