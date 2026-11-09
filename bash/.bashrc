#!/bin/bash
# ~/.bashrc extension for Debian/Ubuntu based systems
# This file can be sourced from your system's ~/.bashrc
# source ~/.marckv.dots/bash/.bashrc

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

# Load interactive help
source "$BASH_MODULES_DIR/help.sh"

# Load marckv: update, reload, help, status... for this repo
source "$BASH_MODULES_DIR/marckv.sh"

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

# Load atuin (shell history). Must come after the theme: atuin hooks into
# PROMPT_COMMAND and a theme loaded afterwards would override it.
# No-op when atuin is not installed.
source "$BASH_MODULES_DIR/atuin.sh"

# =============================================================================
# ADDITIONAL CONFIGURATIONS
# =============================================================================

# Source additional custom configurations if they exist.
#
# ~/.bash_aliases is skipped when ~/.bashrc already sources it, which the stock
# Ubuntu and Debian .bashrc both do — a few lines above the one that loads this
# file. Sourcing it here as well loaded the docker aliases twice in every shell.
for config_file in "$HOME/.bash_aliases" "$HOME/.bash_local" "$HOME/.bashrc.local"; do
    if [[ "$config_file" == "$HOME/.bash_aliases" ]] \
        && grep -qsE '^[^#]*\.bash_aliases' "$HOME/.bashrc"; then
        continue
    fi
    [[ -r "$config_file" ]] && . "$config_file"
done

# Source profile.d scripts for our custom installations
for script in /etc/profile.d/{nvim,node,go}.sh; do
    [[ -r "$script" ]] && . "$script"
done

# One entry per directory in PATH, the first occurrence wins. A login shell has
# already run those profile.d scripts once, and install-nvim.sh's nvim.sh
# appends without checking, so /opt/nvim/bin came out twice — and once more on
# every `marckv reload`.
_dedupe_path() {
    local out="" dir IFS=:
    for dir in $PATH; do
        [[ -n "$dir" && ":$out:" != *":$dir:"* ]] && out="${out:+$out:}$dir"
    done
    PATH="$out"
}
_dedupe_path
