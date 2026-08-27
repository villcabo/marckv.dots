# marckv.dots

Personal dotfiles for Linux — enhanced bash, Docker and Compose shortcuts,
Neovim, Kitty, and Tmux.

Targets Debian 11/12/13 and Ubuntu 20.04/22.04/24.04/26.04, in **bash and
zsh**.

## Installation

### 1. Clone

```bash
git clone https://github.com/villcabo/marckv.dots.git ~/.marckv.dots
cd ~/.marckv.dots/installer
```

### 2. Dependencies

Install the dependencies for the components you plan to use.

#### Bash config

No extra dependencies required.

#### Docker aliases

Requires Docker installed on the system.

#### Tmux

```bash
# Debian / Ubuntu
sudo apt install tmux git
```

#### Neovim (nvim-lite — server-focused)

```bash
# Debian / Ubuntu — required
sudo apt install gcc make libc6-dev git ripgrep

# Debian / Ubuntu — optional (better file finder)
sudo apt install fd-find
```

| Dependency | Why |
|---|---|
| `gcc`, `make`, `libc6-dev` | Treesitter compiles parsers for syntax highlighting |
| `git` | Lazy.nvim and plugin manager clone plugins |
| `ripgrep` | fzf-lua live grep (`<leader>sg`) |
| `fzf` (v0.40+) | Fuzzy finder for file/grep picker (`<leader>ff`, `<leader>sg`) — install from [GitHub](https://github.com/junegunn/fzf#installation), apt version is too old |
| `fd-find` | Faster file finder for fzf-lua — optional, falls back to `find` |

> Without `gcc`/`make`/`libc6-dev`, nvim-lite falls back to Neovim's built-in parsers (bash, lua, python, markdown, vim). You still get syntax highlighting, just for fewer languages.

### 3. Install components

Each script is independent — install only what you need.

```bash
./01-install-bash.sh                    # Custom bash config (robbyrussell theme, aliases, functions)
./02-install-docker-aliases.sh          # Docker & Compose shortcuts (bash + zsh)
./03-install-tmux.sh                    # Tmux config (symlink) + TPM plugin manager
./04-install-nvim-lite.sh               # Neovim config — server-focused, minimal (symlink)
./04-install-nvim-lite.sh --copy        # Same but copies the directory (no repo dependency)
```

Helper scripts:

```bash
sudo ./install-nvim.sh                          # Neovim binary (latest stable, system-wide)
./install-bash-extensions-gradle-functions.sh   # Gradle helper functions
./clean-nvim-data.sh                            # Wipe ~/.local/share/nvim, ~/.cache/nvim, etc.
```

### 4. Apply

```bash
source ~/.bashrc
```

---

## Project structure

```
~/.marckv.dots/
├── bash/                   # Bash modules (colors, aliases, functions, theme)
├── bash-extensions/        # Extra functions (Gradle, etc.)
├── docker-aliases/         # Ten Docker & Compose commands, with docs and tests
├── nvim/                   # Full Neovim config (LazyVim)
├── nvim-lite/              # Minimal Neovim config for servers (LazyVim)
├── kitty/                  # Kitty terminal config
├── tmux/                   # Tmux config
└── installer/              # Installation scripts
```

---

## Docker aliases

Eleven commands, in bash and zsh, each with its own page in
[`docker-aliases/docs/`](docker-aliases/docs/).

| | Host-wide | This compose project |
|---|---|---|
| what is running | `dps` | `dcps` |
| which build is running | `dver` | `dcver` |
| images, and what you could delete | `di` | |
| bring up | | `dcup` |
| logs | `dlt` | `dclt` |
| shell in, or run a command | | `dcx` |
| stop and remove | | `dcdown` |
| jump to the project directory | `dcd` | |

Every command previews what it is about to do — **naming the exact command it
will run** — before running it, and asks before anything that changes state.
Patterns are regular expressions everywhere: `dclt 'api|db'`, `dcd redmine`.

They need nothing but a POSIX shell, coreutils and docker itself — no binaries
to download. See [`docker-aliases/README.md`](docker-aliases/README.md) for the
design rules.

## Testing

The installers have a container per distro at the repo root:

```bash
docker compose up -d ubuntu24
docker compose exec ubuntu24 bash -c "cd /root/.marckv.dots/installer && ./01-install-bash.sh"
```

The docker aliases have their own suite — 357 checks per shell, run in **both**
bash and zsh across seven distros:

```bash
cd docker-aliases/tests
./run.sh                       # everything
./run.sh bash dcup             # one shell, one case
docker compose up -d           # the seven distro images
```

## Contributing

1. Use the Docker Compose testing environments above
2. Test across distributions **and both shells** — most bugs found here were
   bash-vs-zsh differences that bash was perfectly happy with
3. Follow the modular structure for new features
4. Update documentation and help messages
5. Ensure backward compatibility and proper cleanup

## License

This project is open source and available under the MIT License.

---

## Author

<div align="center">
  <img src="https://github.com/villcabo.png" width="100" height="100" style="border-radius: 50%;" alt="villcabo">
  <br/>
  <strong>Bismarck Villca</strong>
  <br/>
  <br/>
  <a href="https://github.com/villcabo">
    <img src="https://img.shields.io/badge/GitHub-villcabo-blue?style=for-the-badge&logo=github" alt="GitHub Profile">
  </a>
  <br/>
  <a href="https://linkedin.com/in/villcabo">
    <img src="https://img.shields.io/badge/LinkedIn-villcabo-0A66C2?style=for-the-badge&logo=linkedin" alt="LinkedIn Profile">
  </a>
  <br/>
  <a href="https://facebook.com/villcabo">
    <img src="https://img.shields.io/badge/Facebook-villcabo-1877F2?style=for-the-badge&logo=facebook" alt="Facebook Profile">
  </a>
  <br/>
  <a href="https://x.com/villcabo">
    <img src="https://img.shields.io/badge/X-@villcabo-000000?style=for-the-badge&logo=x" alt="X Profile">
  </a>
  <br/>
</div>

---

**If this project helped you, please consider giving it a star!**

*Built by villcabo*
