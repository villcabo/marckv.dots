# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**marckv.dots** is a personal Linux dotfiles repository providing modular bash configuration, Docker aliases with colored output, Neovim (LazyVim) config, Kitty terminal config, and Tmux config. Targets Debian/Ubuntu systems (Ubuntu 20/22/24, Debian 11/12).

## Commands

### Installation (run from `installer/` directory)
```bash
./01-install-bash.sh                    # Install bash configuration
./01-install-bash.sh status             # Check installation status
./01-install-bash.sh uninstall          # Remove bash configuration
./02-install-docker-color.sh            # Install docker aliases + binary
./02-install-docker-color.sh status     # Check docker installation status
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
- Numbered prefixes for core installers (`01-`, `02-`) define execution order
- Every installer supports: install, status, and uninstall lifecycle
- Destructive operations require preview + explicit confirmation
- Architecture detection (x86_64/aarch64) for binary downloads
- User privilege detection: root → direct install, sudo user → sudo install, regular user → `~/.local/bin`

### Docker test environment
`docker-compose.yml` mounts the repo read-only at `/root/.marckv.dots` in 5 containers (ubuntu-20/22/24, debian-11/12). Primary target: `ubuntu-24`.

## Conventions

- **Shell**: `#!/bin/bash` or `#!/usr/bin/env bash`, use `set -e`
- **Functions**: snake_case (`get_compact_pwd`, `git_prompt_info`)
- **Constants**: UPPERCASE (`MARCK_DOTS_DIR`, `BASH_MODULES_DIR`)
- **Colors**: tput with ANSI fallback pattern (see `bash/colors.sh`)
- **Logging**: `info()`, `success()`, `warn()`, `error()` functions with colored `[INFO]`/`[OK]`/`[WARN]`/`[ERROR]` prefixes
- **Commits**: Conventional Commits (`feat:`, `fix:`, `refactor:`)
- **New features**: Add as modular files in existing directories, not monolithic scripts
