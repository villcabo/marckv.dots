# GitHub Copilot Instructions

When working on this bash configuration project, use the following testing and development guidelines:

## 🧪 Testing Environment

**IMPORTANT**: Always use the provided Docker Compose setup for testing. Do NOT test directly on the host system.

### Testing Setup Commands

```bash
# Start test environment
docker compose up -d ubuntu-24

# Access container for testing
docker compose exec ubuntu-24 bash

# Navigate to project directory (already mounted)
cd /root/.marck.dots
```

## 📋 Available Test Distributions

Use these containers for testing across different Linux distributions:

- `ubuntu-24` - Ubuntu 24.04 LTS (PRIMARY - use this for main testing)
- `ubuntu-22` - Ubuntu 22.04 LTS  
- `ubuntu-20` - Ubuntu 20.04 LTS
- `debian-12` - Debian 12
- `debian-11` - Debian 11

### Access any distribution:
```bash
docker compose exec <distribution-name> bash
```

## 🧪 Testing Procedures

### 1. Test Bash Configuration
```bash
cd /root/.marck.dots/installer
./01-install-bash.sh           # Install
./01-install-bash.sh status    # Check status  
./01-install-bash.sh uninstall # Uninstall
```

### 2. Test Docker Color Aliases
```bash
cd /root/.marck.dots/installer
./02-install-docker-color.sh          # Complete install (binary + aliases)
./02-install-docker-color.sh aliases  # Only aliases
./02-install-docker-color.sh binary   # Only binary check
./02-install-docker-color.sh status   # Check status
```

### 3. Verify Expected Results
After installation, verify these features:

**Bash Configuration:**
- Robbyrussell theme active
- Compact directory display (e.g., `~/.../installer` instead of full path)
- Git branch/status in prompt
- Color-coded user (red for root, green for regular user)
- Enhanced history management

**Docker Aliases:**
- `docker-color-output` binary installed (when sudo available)
- Docker shortcuts: `d`, `dc`, `dq`, `dcq` 
- Smart confirmations for destructive operations
- Enhanced autocompletion

## 🔧 Development Guidelines

### File Structure
```
├── bash/                    # Bash configuration modules
│   ├── .bashrc             # Main bash configuration
│   ├── aliases.sh          # General aliases
│   ├── colors.sh           # Color definitions
│   ├── environment.sh      # Environment variables & PATH
│   ├── functions.sh        # Utility functions
│   └── themes/             # Prompt themes
│       └── robbyrussell.sh # Default theme
├── docker-aliases/         # Docker-specific aliases
│   └── docker-color_aliases.sh
└── installer/              # Installation scripts
    ├── 01-install-bash.sh  # Bash configuration installer
    └── 02-install-docker-color.sh # Docker aliases installer
```

### Key Components

**Bash Theme (robbyrussell.sh):**
- Uses `get_compact_pwd()` function for directory display
- Supports git integration with status indicators
- Color-coded based on user privileges

**Installers:**
- Always check for existing installations
- Create backups before modifications
- Provide status and uninstall options
- Use preview + confirmation for safety

### Testing Multi-Distribution
```bash
# Test across multiple distributions
for dist in ubuntu-24 ubuntu-22 debian-12; do
    echo "Testing on $dist..."
    docker compose exec $dist bash -c "cd /root/.marck.dots/installer && ./01-install-bash.sh"
done
```

## 🐛 Debugging & Troubleshooting

### Common Issues

1. **Path not working**: Check if `~/.local/bin` is in PATH
2. **Permissions**: Use appropriate user (root in containers, sudo for system-wide)
3. **Git not showing**: Verify git repository status
4. **Theme not active**: Check if `.bashrc` sources the theme correctly

### Debug Commands
```bash
# Check installation files
ls -la ~/.bashrc ~/.bash_aliases

# Verify marck.dots loading
grep "marck.dots" ~/.bashrc ~/.bash_aliases

# Manual component testing
source ~/.marck.dots/bash/.bashrc
source ~/.marck.dots/bash/themes/robbyrussell.sh
```

## 📝 Code Modification Guidelines

### When modifying bash themes:
- Test the `get_compact_pwd()` function with various directory structures
- Ensure git integration works in different repository states
- Verify color codes work across different terminals

### When modifying installers:
- Always include preview + confirmation for user safety
- Test both installation and uninstallation procedures
- Verify backup creation and restoration
- Test with and without sudo privileges

### When adding new features:
- Follow the modular structure (separate files for different concerns)
- Add appropriate status checks in installer scripts
- Update help messages and documentation
- Test across multiple distributions

## 🧹 Cleanup

```bash
# Stop containers
docker compose down

# Full cleanup (removes containers and networks)
docker compose down --volumes --remove-orphans
```

## ⚠️ Important Notes

- **Container environment**: All containers run as root with project mounted at `/root/.marck.dots`
- **Read-only mount**: Project directory is mounted read-only to prevent accidental modifications
- **Network**: Containers use `marckv-net` bridge network for inter-container communication
- **Primary testing**: Use `ubuntu-24` as the primary testing environment (most recent LTS)
- **Safety**: Always use Docker containers for testing, never test directly on development machine

## 🎯 Success Criteria

A successful modification should:
1. ✅ Install cleanly on all supported distributions
2. ✅ Display compact directory paths in prompt
3. ✅ Show git status when in repository
4. ✅ Provide working Docker aliases (when applicable)
5. ✅ Allow clean uninstallation
6. ✅ Create proper backups
7. ✅ Handle edge cases gracefully (no sudo, missing dependencies, etc.)

Use these guidelines when suggesting code changes or improvements to ensure compatibility and proper testing coverage.