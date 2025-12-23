#!/bin/bash
# ~/.bashrc extension for Debian/Ubuntu based systems
# This file can be sourced from your system's ~/.bashrc
# source ~/.marck.dots/bash/.bashrc

# Only run if this is an interactive shell
[[ $- != *i* ]] && return

# Get the directory where this script is located
BASH_MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# LOAD MODULAR COMPONENTS
# =============================================================================

# Load colors first (required by other modules)
source "$BASH_MODULES_DIR/colors.sh"

# Load environment variables and PATH
source "$BASH_MODULES_DIR/environment.sh"

# Load completion configuration
source "$BASH_MODULES_DIR/completion.sh"

# Load aliases
source "$BASH_MODULES_DIR/aliases.sh"

# Load utility functions
source "$BASH_MODULES_DIR/functions.sh"

# Load theme (robbyrussell by default, can be changed with BASH_THEME)
BASH_THEME=${BASH_THEME:-robbyrussell}
if [[ -f "$BASH_MODULES_DIR/themes/${BASH_THEME}.sh" ]]; then
    source "$BASH_MODULES_DIR/themes/${BASH_THEME}.sh"
else
    echo "Warning: Theme '$BASH_THEME' not found, loading robbyrussell"
    source "$BASH_MODULES_DIR/themes/robbyrussell.sh"
fi

# Load welcome message
source "$BASH_MODULES_DIR/welcome.sh"

# =============================================================================
# ADDITIONAL CONFIGURATIONS
# =============================================================================

# Source additional custom configurations if they exist
for config_file in "$HOME/.bash_aliases" "$HOME/.bash_local" "$HOME/.bashrc.local"; do
    [[ -r "$config_file" ]] && . "$config_file"
done

# Source profile.d scripts for our custom installations
for script in /etc/profile.d/{nvim,node,go}.sh; do
    [[ -r "$script" ]] && . "$script"
done
