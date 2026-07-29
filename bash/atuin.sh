#!/bin/bash
# Atuin - magical shell history (https://atuin.sh)
#
# Sourced from bash/.bashrc. If atuin is not installed this file does nothing,
# so the same dotfiles work on servers with and without it.
#
# Install with: ~/.marckv.dots/installer/05-install-atuin.sh

# Skip silently when atuin is not available
command -v atuin >/dev/null 2>&1 || return 0

# atuin >= 18 ships bash-preexec built in, no extra dependency needed.
# Its own guard also disables the integration on non-interactive shells,
# so CI jobs and scripts are never affected.
eval "$(atuin init bash)"
