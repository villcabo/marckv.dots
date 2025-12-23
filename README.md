# 🏠 marckv.dots

> Personal dotfiles and development environment setup for Linux systems with enhanced bash configuration and Docker integration.

## ✨ Features

- **🎨 Enhanced Bash Experience**: Custom robbyrussell theme with compact directory display and git integration
- **🐳 Docker Color Integration**: Advanced Docker and Docker Compose aliases with colored output and smart confirmations  
- **📦 Modular Configuration**: Clean, organized bash modules (colors, aliases, functions, environment)
- **🔧 Easy Installation**: Automated installers with preview, confirmation, and rollback capabilities
- **🧪 Multi-Distribution Testing**: Docker Compose setup for testing across Ubuntu and Debian versions
- **⚡ Developer Optimized**: Enhanced history management, autocompletion, and productivity shortcuts

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/villcabo/marckv.dots.git ~/.marck.dots
cd ~/.marck.dots/installer
```

### 2. Install Components

**Install Enhanced Bash Configuration:**
```bash
./01-install-bash.sh
```

**Install Docker Color Aliases:**
```bash
./02-install-docker-color.sh
```

### 3. Activate Configuration

```bash
source ~/.bashrc
```

## 📋 What You Get

### Enhanced Bash Theme
- **Compact directory display**: `~/.../current-dir` instead of full paths
- **Git integration**: Branch and status indicators
- **Color-coded user**: Red for root, green for regular users
- **Smart history**: Deduplication, timestamps, and security filtering

### Docker Integration  
- **Short aliases**: `d ps`, `dc up`, `dq container cmd`
- **Smart confirmations**: Preview destructive operations before execution
- **Enhanced autocompletion**: Container and service name completion
- **Color output**: Automatic docker-color-output integration

### Example Workflow
```bash
# Before: root@server /home/user/projects/myapp/backend/src ➜
# After:  root@server ~/.../src git:(main) ✗ ➜

# Docker shortcuts
d ps              # docker ps with colors
dc up -l          # docker compose up with logs  
dq web bash       # quick exec into 'web' container
```

## 🧪 Testing & Development

**For Contributors and GitHub Copilot:**
See [.github/copilot-instructions.md](.github/copilot-instructions.md) for comprehensive development guidelines.

**Quick Test Environment:**
```bash
# Start test container
docker compose up -d ubuntu-24

# Test installations  
docker compose exec ubuntu-24 bash
cd /root/.marck.dots/installer
./01-install-bash.sh
```

**Supported Distributions:**
- Ubuntu 24.04 LTS (Primary)
- Ubuntu 22.04 LTS, Ubuntu 20.04 LTS
- Debian 12, Debian 11

## 📁 Project Structure

```
marckv.dots/
├── bash/                    # Modular bash configuration
│   ├── .bashrc             # Main configuration loader
│   ├── aliases.sh          # General aliases
│   ├── colors.sh           # Color definitions
│   ├── environment.sh      # Environment variables & PATH
│   ├── functions.sh        # Utility functions
│   └── themes/
│       └── robbyrussell.sh # Enhanced theme with compact display
├── docker-aliases/         # Docker-specific functionality
│   └── docker-color_aliases.sh # Comprehensive Docker aliases
├── installer/              # Installation scripts
│   ├── 01-install-bash.sh  # Bash configuration installer
│   └── 02-install-docker-color.sh # Docker setup installer
├── .github/
│   └── copilot-instructions.md # Development guidelines
└── docker-compose.yml      # Multi-distribution testing setup
```

## ⚙️ Configuration Options

### Bash Installation
```bash
./01-install-bash.sh          # Install with preview
./01-install-bash.sh status   # Check installation status
./01-install-bash.sh uninstall # Remove configuration
```

### Docker Installation
```bash
./02-install-docker-color.sh          # Complete setup (binary + aliases)
./02-install-docker-color.sh aliases  # Only aliases
./02-install-docker-color.sh binary   # Only docker-color-output binary
./02-install-docker-color.sh status   # Show detailed status
```

## 🔧 Advanced Usage

### Docker Aliases Reference
```bash
# Container management
d ps, d p          # List containers  
d logs, d l        # Follow logs
d x container cmd  # Execute command
d sh container     # Shell access

# Compose operations
dc up -l           # Up with logs
dc down            # Stop services  
dc build -r        # Build with recreate
dc x service cmd   # Execute in service

# Quick functions
dq pattern cmd     # Execute in first matching container
dcq pattern cmd    # Execute in first matching service
dstatus           # Show containers and services status
```

### Environment Customization
The configuration automatically:
- Adds `~/.local/bin` to PATH
- Loads system bash aliases from `~/.bash_aliases`
- Provides enhanced history with security filtering
- Sets up colored man pages and less options

## 🛠️ Troubleshooting

### Installation Issues
```bash
# Check status
./01-install-bash.sh status
./02-install-docker-color.sh status

# Manual verification
grep "marck.dots" ~/.bashrc ~/.bash_aliases
```

### Docker Binary Installation
- **System-wide**: Requires sudo, installs to `/usr/local/bin`
- **User-only**: No sudo needed, installs to `~/.local/bin`
- **Architecture**: Supports x86_64 and aarch64

## 🤝 Contributing

1. Use the Docker Compose testing environment
2. Test changes across multiple distributions
3. Follow the modular structure for new features
4. Update documentation and help messages
5. Ensure backward compatibility and proper cleanup

## 📄 License

This project is open source and available under the MIT License.

---

## 👨‍💻 Author

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

⭐ **If this project helped you, please consider giving it a star!** ⭐

*Built with ❤️ by villcabo*
