#!/bin/bash
# Environment variables and PATH configuration

# Default editor preference
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
    export VISUAL=nvim
elif command -v vim >/dev/null 2>&1; then
    export EDITOR=vim
    export VISUAL=vim
else
    export EDITOR=nano
    export VISUAL=nano
fi

# Less options for better paging
export LESS='-R -i -M -S -x4'

# Colored man pages
export LESS_TERMCAP_mb=$'\e[1;32m'     # begin blinking
export LESS_TERMCAP_md=$'\e[1;32m'     # begin bold
export LESS_TERMCAP_me=$'\e[0m'        # end mode
export LESS_TERMCAP_se=$'\e[0m'        # end standout-mode
export LESS_TERMCAP_so=$'\e[01;33m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\e[0m'        # end underline
export LESS_TERMCAP_us=$'\e[1;4;31m'   # begin underline

export HISTSIZE=100000
export HISTFILESIZE=200000
# Better history handling
export HISTCONTROL=ignoreboth:erasedups
# History with date and time
export HISTTIMEFORMAT="%d/%m/%y %T "
# HISTIGNORE for server environments - Exclude repetitive commands AND dangerous operations for security
# Security: exclude dangerous commands to prevent accidental execution from history
export HISTIGNORE="ls:ll:la:l:cd:cd -:cd ..:pwd:exit:logout:clear:history:history *:date:uptime:whoami:id:* --help:man *:ps:ps aux:top:htop:df:df -h:free:free -h:lsblk:bg:fg:jobs:rm:rm *:rmdir:reboot:shutdown:halt:poweroff:init 0:init 6:kill:killall:pkill:systemctl stop*:systemctl restart*:systemctl disable*:umount:fdisk:mkfs*:dd:shred:wipefs"

# PATH enhancements
# Add local bin directories to PATH if they exist
for dir in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin"; do
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        PATH="$dir:$PATH"
    fi
done

# Add Node.js path if installed via our installer
if [[ -d "/opt/nodejs/bin" && ":$PATH:" != *":/opt/nodejs/bin:"* ]]; then
    PATH="$PATH:/opt/nodejs/bin"
fi

# Add Neovim path if installed via our installer
if [[ -d "/opt/nvim/bin" && ":$PATH:" != *":/opt/nvim/bin:"* ]]; then
    PATH="$PATH:/opt/nvim/bin"
fi

# Export the updated PATH
export PATH
