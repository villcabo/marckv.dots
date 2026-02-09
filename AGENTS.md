# Repository Guidelines

## Project Structure & Module Organization
This repository is a Linux dotfiles/developer-environment setup.

- `bash/`: modular shell config loaded by `bash/.bashrc` (`aliases.sh`, `environment.sh`, `functions.sh`, `themes/robbyrussell.sh`, etc.).
- `docker-aliases/`: Docker and Docker Compose shortcuts (`docker-color_aliases.sh`).
- `installer/`: executable setup scripts (`01-install-bash.sh`, `02-install-docker-color.sh`, plus optional tooling installers like `install-node.sh` and `install-nvim.sh`).
- `nvim/`: Neovim/LazyVim configuration (`init.lua`, `lua/config`, `lua/plugins`, `stylua.toml`).
- `docker-compose.yml`: multi-distro test environment (Ubuntu 20/22/24, Debian 11/12).
- `.github/copilot-instructions.md`: contributor testing/safety expectations.

## Build, Test, and Development Commands
No compile/build step exists; use installer and container-based validation.

- `cd installer && ./01-install-bash.sh`: install shell configuration.
- `cd installer && ./01-install-bash.sh status|uninstall`: verify or remove bash setup.
- `cd installer && ./02-install-docker-color.sh`: install Docker aliases + binary checks.
- `docker compose up -d ubuntu-24`: start primary test container.
- `docker compose exec ubuntu-24 bash`: run installer tests in-container.
- `docker compose down`: stop test environment.

## Coding Style & Naming Conventions
- Shell scripts: Bash (`#!/bin/bash` or `#!/usr/bin/env bash`), clear function-based structure, uppercase constants for globals (for example, `MARCK_DOTS_DIR`), snake_case function names.
- Prefer modular additions in existing folders instead of monolithic scripts.
- Keep installer scripts executable and use numeric prefixes for ordered entry points (`01-`, `02-`).
- Neovim Lua formatting follows `nvim/stylua.toml` (2 spaces, width 120).

## Testing Guidelines
- Test in Docker containers, not directly on host.
- Minimum check for installer changes: `install`, `status`, and `uninstall`.
- Primary target is `ubuntu-24`; verify compatibility on at least one additional distro (for example `debian-12`).
- Confirm prompt behavior, alias availability (`d`, `dc`, `dq`), and safe confirmation flows for destructive operations.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style used in history: `feat: ...`, `fix: ...`.
- Keep commits scoped to one logical change.
- PRs should include:
  - concise summary and affected paths,
  - test evidence (commands + distro used),
  - screenshots/terminal snippets for prompt or CLI UX changes,
  - linked issue/context when applicable.
