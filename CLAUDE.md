# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**marckv.dots** is a personal Linux dotfiles repo: modular bash, Docker aliases with colored output and previews, Neovim (LazyVim — full `nvim/` and server-focused `nvim-lite/`), Kitty, and Tmux. Targets Debian/Ubuntu (Ubuntu 20/22/24, Debian 11/12).

## Commands

### Installation (run from `installer/`)

Core installers — numbered prefixes define execution order. Each supports `install` (default), `status`, and `uninstall`:

```bash
./01-install-bash.sh                    # Bash modules (robbyrussell theme, aliases, functions)
./02-install-docker-aliases.sh          # Docker & Compose shortcuts (bash + zsh)
./03-install-tmux.sh                    # Tmux config (symlink) + TPM
./04-install-nvim-lite.sh [--copy]      # Server-focused Neovim config (symlink, or copy)
```

Helpers (not part of the numbered lifecycle):

```bash
sudo ./install-nvim.sh                  # Neovim binary, system-wide
./install-bash-extensions-gradle-functions.sh   # Adds bash-extensions/bash_gradle_functions.sh
./clean-nvim-data.sh                    # Wipe ~/.local/share/nvim, ~/.cache/nvim, etc.
```

### Testing (always use Docker, never test on host)
```bash
docker compose up -d ubuntu-24                  # Start primary test container
docker compose exec ubuntu-24 bash              # Enter container
# Inside container: cd /root/.marckv.dots/installer && ./01-install-bash.sh

# Multi-distro test
for dist in ubuntu-24 ubuntu-22 debian-12; do
    docker compose exec $dist bash -c "cd /root/.marckv.dots/installer && ./01-install-bash.sh"
done

docker compose down                             # Cleanup
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
- `docker-aliases/` — docker/compose shortcuts with completion. Nine commands,
  bash and zsh, each with a doc page in `docker-aliases/docs/`. Its own e2e suite
  runs every check in both shells across 7 distros — see
  `docker-aliases/tests/README.md`. No external binaries: it renders its own
  coloured tables rather than piping through `docker-color-output`.
- `nvim/` vs `nvim-lite/` — full LazyVim setup vs. minimal server profile; both have their own `stylua.toml`
- `kitty/`, `tmux/` — terminal/multiplexer configs

### Docker test environment
`docker-compose.yml` mounts the repo read-only at `/root/.marckv.dots` in 5 containers (ubuntu-20/22/24, debian-11/12). Primary target: `ubuntu-24`.

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
