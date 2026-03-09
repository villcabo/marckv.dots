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
# ignoredups: skip consecutive duplicates. erasedups intentionally avoided —
# on a server, keeping the full history sequence is important for auditing.
export HISTCONTROL=ignorespace:ignoredups
# Timestamp every history entry for audit trail
export HISTTIMEFORMAT="%d/%m/%y %T "
# All commands are recorded — full audit trail on a server.
unset HISTIGNORE

# Flush history to disk after every command so it survives dropped SSH sessions.
export PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Restrict default permissions: new files are rwxr-x--- (not readable by others).
umask 027

# Auto-logout idle SSH sessions after 30 minutes of inactivity.
# Guard against readonly TMOUT already set by the system (e.g. Debian 12 /etc/profile.d/).
if ! readonly -p | grep -q ' TMOUT='; then
    export TMOUT=1800
    readonly TMOUT
fi

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
