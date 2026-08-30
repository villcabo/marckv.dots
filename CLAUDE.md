# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**marckv.dots** is a personal Linux dotfiles repo: modular bash, Docker aliases with colored output and previews, Neovim (LazyVim — full `nvim/` and server-focused `nvim-lite/`), Kitty, and Tmux. Targets Debian/Ubuntu: Debian 11/12/13 and Ubuntu 20.04/22.04/24.04/26.04.

## Commands

### Installation (run from `installer/`)

Core installers — numbered prefixes define execution order. Each supports `install` (default), `status`, and `uninstall`:

```bash
./01-install-bash.sh                    # Bash modules (robbyrussell theme, aliases, functions)
./02-install-docker-aliases.sh          # Docker & Compose shortcuts (bash + zsh)
./03-install-tmux.sh                    # Tmux config (symlink) + TPM
./04-install-nvim-lite.sh [--copy]      # Server-focused Neovim config (symlink, or copy)
```

`04-install-nvim-lite.sh` also orchestrates the whole Neovim stack, because the
four scripts that used to do it separately left the user as the orchestrator:

```bash
./04-install-nvim-lite.sh --reinstall   # clean, deps, nvim, config, sync — in that order
./04-install-nvim-lite.sh -d -s         # any subset; the flags compose
./04-install-nvim-lite.sh status
```

`deps` runs before `nvim` and `sync` on purpose: `gcc` has to exist before the
sync step compiles treesitter parsers. Add `-y` to skip every confirmation.

It delegates rather than duplicating — `install-nvim.sh` for the binary (it
needs root; this one does not) and `clean-nvim-data.sh` for the data dirs.

Helpers (not part of the numbered lifecycle):

```bash
sudo ./install-nvim.sh [-y]             # Neovim binary, system-wide
./install-bash-extensions-gradle-functions.sh   # Adds bash-extensions/bash_gradle_functions.sh
./clean-nvim-data.sh [-y]               # Wipe ~/.local/share/nvim, ~/.cache/nvim, etc.
```

### Testing (always use Docker, never test on host)

Installers — the repo-root `docker-compose.yml`. Service names have **no dash**
(`ubuntu24`, not `ubuntu-24`):

```bash
docker compose up -d ubuntu24                   # Start primary test container
docker compose exec ubuntu24 bash               # Enter container
# Inside: cd /root/.marckv.dots/installer && ./01-install-bash.sh

for dist in ubuntu24 ubuntu22 debian12; do
    docker compose exec $dist bash -c "cd /root/.marckv.dots/installer && ./01-install-bash.sh"
done

docker compose down
```

`install-nvim.sh` has a scenario suite of its own, because what it gets wrong
is distro-specific — which Neovim binary a given GLIBC can run, and whether
what it leaves behind is reachable by anyone but root:

```bash
cd installer/tests
./run.sh                       # six distros
./run.sh debian11              # one — the GLIBC 2.31 case
```

It writes to `/opt` and `/etc/profile.d`, so it only ever runs in a container.

`nvim-lite` has one too, for the same reason — whether a parser can be built at
all depends on the distro's GLIBC, in two different ways depending on the
Neovim version:

```bash
cd nvim-lite/tests
./run.sh                       # six distros
./run.sh debian12              # one — the GLIBC 2.36 case, the awkward one
```

Docker aliases — their own harness, which also carries `bats` and `zsh`:

```bash
cd docker-aliases/tests
./run.sh                       # every case, bash + zsh
./run.sh bash dcup             # one shell, one case — the fast loop
docker compose up -d           # the 7 distro images
docker compose exec -T ubuntu24 /repo/docker-aliases/tests/run.sh
```

### Neovim Lua formatting
Follows `nvim/stylua.toml`: 2-space indent, 120 column width.

## Architecture

### Deployment model
No symlinks. Installers append `source` lines to `~/.bashrc` and `~/.bash_aliases` that point into the repo (e.g., `~/.marckv.dots/bash/.bashrc`). Changes in the repo are immediately live. Backups are created with timestamps before any modification.

### Bash module load order (bash/.bashrc)
`colors.sh` → `environment.sh` → `completion.sh` → `aliases.sh` → `functions.sh` → `themes/robbyrussell.sh` → `welcome.sh` → `~/.bash_aliases` → `~/.bash_local` → `/etc/profile.d/*`

Colors must load first as other modules depend on them. The theme depends on functions from `colors.sh` and `functions.sh`.

### Installer conventions
- Numbered prefixes (`01-` … `04-`) on core installers define execution order
- Every core installer supports the `install` / `status` / `uninstall` lifecycle — keep parity when adding new ones
- Destructive operations require preview + explicit confirmation
- Architecture detection (x86_64/aarch64) for binary downloads
- User privilege detection: root → direct install, sudo user → sudo install, regular user → `~/.local/bin`
- `04-install-nvim-lite.sh` defaults to a symlink (live edits from repo); `--copy` snapshots the dir so the host no longer depends on the repo path

### Component layout
- `bash/` — modules loaded by `bash/.bashrc` (see load order above)
- `bash-extensions/` — optional add-ons sourced separately (e.g. `bash_gradle_functions.sh`)
- `docker-aliases/` — docker/compose shortcuts for bash and zsh. Eleven commands
  (`dcup dclt dcdown dcx dcd dps dcps dcver dver di dlt`), one file each in `commands/`,
  a doc page each in `docs/`, a bats case file each in `tests/cases/`. Adding a
  command means adding those three; `init.sh` globs and needs no editing.
  **Read `docker-aliases/README.md` before changing anything there** — its
  design rules (mandatory preview, preview on stderr, confirmation scaled to
  blast radius, resolve files and profiles exactly as docker does) are the
  reason it exists in that shape.
- `nvim/` vs `nvim-lite/` — full LazyVim setup vs. minimal server profile; both have their own `stylua.toml`
- `nvim-lite/VERSION` — plain text, semver over the CONFIG (not over Neovim).
  Bump it in the same commit as the change it describes: major when something
  in use is gone or a keymap moved, minor for new plugins/parsers/filetypes,
  patch for fixes. Plain text and not Lua because both the installer
  (`$(<VERSION)`) and `lua/config/branding.lua` read it, and one source beats
  parsing Lua from shell. It shows on the start screen and in `:LiteVersion`
- `kitty/`, `tmux/` — terminal/multiplexer configs

### Docker test environments
Two, on purpose:

- **`docker-compose.yml` (repo root)** — mounts the repo read-only at
  `/root/.marckv.dots` in 6 containers (debian11/12/13, ubuntu20/22/24) for
  exercising the **installers**. Primary target: `ubuntu24`.
- **`docker-aliases/tests/compose.yml`** — 7 containers (adds ubuntu26),
  mounting the repo at `/repo` and carrying `bats` and `zsh`, for the aliases'
  own suite. Mounts **no docker socket**: a socket would let a test inside a
  container act on the host's real containers.


## Shell portability (bash **and** zsh)

Everything shipped here has to behave identically in both. Every one of these
cost a real bug, found only by running the code in zsh — bash was happy in all
of them. Re-read this list before assembling any list, array or pattern.

| Trap | bash | zsh |
|---|---|---|
| `for f in $var` | splits on whitespace | does **not** split — collapses to one item |
| Array index | 0-based | 1-based |
| Expanding a variable whose *name* is in another variable | `${!v}` | `${(P)v}` — **no portable form**; pass data, not variable names |
| `${var,,}` | lowercases | syntax error |
| `IFS=, read -ra` | works | needs `read -rA` |
| `status` as a variable | ordinary | **read-only** (zsh's name for `$?`) — assigning aborts the function. Same for `path`, `argv`, `options` |
| `(` inside an expansion pattern — `${s%% (*}` | literal character | opens a glob group; unterminated, aborts. Quote it: `${s%%" ("*}` |
| `${var:+$'\n'}` | expands the escape | does **not** — put the newline in a plain variable first |
| `local x` on an already-local name | silent | **prints** the variable |

The way out of most of them is the same: **iterate, never index**, and when two
values must stay paired, join them into one record (`"$a<TAB>$b"`) instead of
keeping parallel arrays.

Nerd Font glyphs are a related trap: they live in the Unicode Private Use Area
and do not survive every editor or transfer. Write them as `\uXXXX` escapes,
never as literal characters — `docker-aliases/lib/ui.sh` once shipped with every
glyph silently emptied, and a blank icon looks exactly like one the terminal
cannot draw.

## Shipped scripts use only a POSIX shell and coreutils

`sd`, `rg`, `fd`, `bat`, `eza`, `jq` are excellent and **none of them is on a
fresh Debian server**, which is where these scripts run.

This is the one place the global instruction to prefer `rg`/`fd`/`sd` over
`grep`/`find`/`sed` does **not** apply: that rule is about commands *you* run
while working. Anything written into a script in this repo must survive on a
box with nothing installed. `docker-aliases/tests/cases/ui.bats` enforces it —
an `sd` reached `dcver.sh` once and only the distro matrix caught it.

## Conventions

- **Shell**: `#!/bin/bash` or `#!/usr/bin/env bash`, use `set -e`
- **Functions**: snake_case (`get_compact_pwd`, `git_prompt_info`)
- **Constants**: UPPERCASE (`MARCKV_DOTS_DIR`, `BASH_MODULES_DIR`)
- **Colors**: tput with ANSI fallback pattern (see `bash/colors.sh`)
- **Logging**: `info()`, `success()`, `warn()`, `error()` functions with colored `[INFO]`/`[OK]`/`[WARN]`/`[ERROR]` prefixes
- **Commits**: Conventional Commits ([conventionalcommits.org](https://www.conventionalcommits.org/en/v1.0.0/))
  - Only commit when explicitly asked by the user
  - Single line, maximum 100 characters
  - Format: `<type>[optional scope]: <description>`
  - Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`
  - Examples: `feat(docker): add dip command to search containers by IP`
  - No body, no footer, no multi-line messages
- **New features**: Add as modular files in existing directories, not monolithic scripts
- **Renames in git**: stage *both* sides in the **same** commit. Staging the new
  path in one commit and the deletion in the next records create+delete instead
  of a rename, and `git log --follow` stops reaching the history
- **Pin what you download**: installers and Dockerfiles pin versions
  (`DOCKER_VERSION`, `COMPOSE_VERSION`, `BATS_VERSION`) and never call the
  GitHub API — it rate-limits at 60/h unauthenticated, which surfaces later as
  build failures nobody can reproduce
- **Verify, do not assume**: check behaviour against the real tool before
  encoding it. Several bugs here came from believing docker worked a certain
  way — `--env-file` after `up` is rejected, `-f` disables the automatic
  `docker-compose.override.yml` merge, `--profile` *replaces* `COMPOSE_PROFILES`
  rather than adding to it
