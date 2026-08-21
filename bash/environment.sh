#!/bin/bash
# Environment variables and PATH configuration

# marckv.dots repository location
export MARCKV_DOTS_DIR="$HOME/.marckv.dots"

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

# Share history between concurrent sessions.
#
#   history -n   read back what OTHER sessions appended since we last looked
#   history -a   append this session's new commands, so they survive a dropped
#                SSH connection
#
# Without the -n, every session writes and none of them read: a command run in
# another terminal is on disk but invisible here, which is exactly how it ends
# up feeling lost.
#
# THE ORDER MATTERS, and not in the obvious direction. "history -a" first looks
# natural and is what most snippets show, but -a advances bash's record of how
# much of the file it has consumed to the file's *new* end -- including the
# lines another session appended and this one never loaded. The next -n then
# starts past them. Measured on ubuntu24 and debian12: with "-a; -n" a session
# that ran five commands elsewhere shows up as four, the oldest one silently
# gone. With "-n; -a" it is five of five.
#
# -n rather than "history -c; history -r": -c/-r re-reads the entire file on
# every prompt. At the 100k entries HISTSIZE allows that measured 0.62s per 30
# prompts against 0.11s for -n, and it grows with the file while -n does not.
# -c also wipes and renumbers the in-memory list on every command.
export PROMPT_COMMAND="history -n; history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Restrict default permissions: new files are rwxr-x--- (not readable by others).
umask 027

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
