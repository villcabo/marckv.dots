#!/bin/bash
# Bash completion configuration

# Better completion
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# Enable programmable completion features
if [[ -d /etc/bash_completion.d ]]; then
    for file in /etc/bash_completion.d/*; do
        [[ -r "$file" ]] && . "$file"
    done
fi

# Shell options for better experience
shopt -s histappend     # Append to history file
shopt -s checkwinsize   # Check window size after each command
shopt -s autocd         # Change to directory by typing its name
shopt -s cdspell        # Correct minor spelling errors in cd commands
shopt -s dirspell       # Correct minor spelling errors in directory names
shopt -s globstar       # Enable ** for recursive globbing
