# marckv.dots

Personal dotfiles for Linux — enhanced bash, Docker aliases with colored output, Neovim, Kitty, and Tmux. Targets Debian/Ubuntu systems (Ubuntu 20/22/24, Debian 11/12).

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
./02-install-docker-color.sh            # Docker aliases + docker-color-output binary
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
├── docker-aliases/         # Docker & Compose shortcuts with completion
├── nvim/                   # Full Neovim config (LazyVim)
├── nvim-lite/              # Minimal Neovim config for servers (LazyVim)
├── kitty/                  # Kitty terminal config
├── tmux/                   # Tmux config
└── installer/              # Installation scripts
```

### Docker Binary Installation
- **System-wide**: Requires sudo, installs to `/usr/local/bin`
- **User-only**: No sudo needed, installs to `~/.local/bin`
- **Architecture**: Supports x86_64 and aarch64

## Contributing

1. Use the Docker Compose testing environment
2. Test changes across multiple distributions
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
