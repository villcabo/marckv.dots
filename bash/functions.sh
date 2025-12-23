#!/bin/bash
# Utility functions for enhanced shell experience

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar e "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.tbz2) tar xjf "$1" ;;
            *.tgz) tar xzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *) echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find and kill process by name
pkillbyname() {
    if [[ -z "$1" ]]; then
        echo "Usage: pkillbyname <process_name>"
        return 1
    fi
    
    local pids=$(pgrep -f "$1")
    if [[ -n "$pids" ]]; then
        echo "Killing processes matching '$1':"
        echo "$pids" | xargs ps -p
        echo "$pids" | xargs kill
    else
        echo "No processes found matching '$1'"
    fi
}

# List open ports and associated processes
ports_func() {
    if command -v netstat &>/dev/null; then
        netstat -tulpen
    elif command -v ss &>/dev/null; then
        ss -tulpen
    else
        echo "No netstat or ss command found"
    fi
}
