#!/bin/bash
# Welcome message and system information

# Load colors if not already loaded
[[ -z "$GREEN" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Display system information on login (only for interactive sessions)
if [[ -n "$PS1" ]]; then
    echo -e "${BOLD}${CYAN}Welcome to $(hostname)!${RESET}"
    echo -e "${GREEN}System: $(uname -sr)${RESET}"
    if command -v lsb_release >/dev/null 2>&1; then
        echo -e "${GREEN}Distribution: $(lsb_release -d | cut -f2)${RESET}"
    fi
    echo -e "${YELLOW}Current time: $(date)${RESET}"
    echo -e "${MAGENTA}Uptime: $(uptime -p 2>/dev/null || uptime)${RESET}"
    echo ""
fi
