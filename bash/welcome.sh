#!/bin/bash
# Welcome message and system information

# Load colors if not already loaded
[[ -z "$GREEN" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Display system information on login (only for interactive sessions)
if [[ -n "$PS1" ]]; then
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $(hostname)${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # System
    echo -e "${BOLD}${BLUE}  System   ${RESET}$(uname -sr)"
    if command -v lsb_release >/dev/null 2>&1; then
        echo -e "${BOLD}${BLUE}  Distro   ${RESET}$(lsb_release -d | cut -f2)"
    fi
    echo -e "${BOLD}${BLUE}  Uptime   ${RESET}$(uptime -p 2>/dev/null || uptime)"
    echo -e "${BOLD}${BLUE}  Date     ${RESET}$(date '+%a %d %b %Y %H:%M:%S %Z')"

    # CPU load averages
    _load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "${BOLD}${BLUE}  Load     ${RESET}${_load}"

    # Memory usage with color thresholds (use 'command free' to bypass the alias free='free -h')
    if command -v free >/dev/null 2>&1; then
        _mem_total=$(command free -m | awk '/^Mem:/{print $2}')
        _mem_used=$(command free -m | awk '/^Mem:/{print $3}')
        _mem_pct=$(( _mem_used * 100 / (_mem_total > 0 ? _mem_total : 1) ))
        _mem_color="$GREEN"
        (( _mem_pct >= 80 )) && _mem_color="$RED"
        (( _mem_pct >= 60 && _mem_pct < 80 )) && _mem_color="$YELLOW"
        echo -e "${BOLD}${BLUE}  Memory   ${RESET}${_mem_color}${_mem_used}M / ${_mem_total}M (${_mem_pct}%)${RESET}"
    fi

    # Disk usage for root filesystem with color thresholds
    _disk_info=$(df -h / | awk 'NR==2{print $3, $2, $5}')
    _disk_used=$(echo "$_disk_info" | awk '{print $1}')
    _disk_total=$(echo "$_disk_info" | awk '{print $2}')
    _disk_pct=$(echo "$_disk_info" | awk '{gsub(/%/,""); print $3}')
    _disk_color="$GREEN"
    (( _disk_pct >= 90 )) && _disk_color="$RED"
    (( _disk_pct >= 75 && _disk_pct < 90 )) && _disk_color="$YELLOW"
    echo -e "${BOLD}${BLUE}  Disk /   ${RESET}${_disk_color}${_disk_used} / ${_disk_total} (${_disk_pct}%)${RESET}"

    # IP addresses (up to 3)
    _ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3 | tr '\n' '  ')
    [[ -n "$_ips" ]] && echo -e "${BOLD}${BLUE}  IP       ${RESET}${_ips}"

    # Logged-in users
    _users=$(who 2>/dev/null | awk '{print $1"("$5")"}' | sort -u | tr '\n' '  ')
    [[ -z "$_users" ]] && _users="$(whoami) (local)"
    echo -e "${BOLD}${BLUE}  Users    ${RESET}${_users}"

    # Last login (second entry in `last` = previous session)
    if command -v last >/dev/null 2>&1; then
        _lastlogin=$(last -n 2 "$USER" 2>/dev/null | awk 'NR==2 && $1!="" && $1!="wtmp" {
            printf "%s from %s on %s %s %s", $1, $3, $4, $5, $6
        }')
        [[ -n "$_lastlogin" ]] && echo -e "${BOLD}${BLUE}  Last     ${RESET}${_lastlogin}"
    fi

    # Failed login attempts (requires read access to /var/log/btmp)
    if command -v lastb >/dev/null 2>&1; then
        _fails=$(lastb -n 50 2>/dev/null | grep -c "^$USER" 2>/dev/null || true)
        if [[ -n "$_fails" ]] && (( _fails > 0 )); then
            echo -e "${BOLD}${BLUE}  Failures ${RESET}${RED}${BOLD}${_fails} failed attempt(s) for $USER (last 50 entries)${RESET}"
        fi
    fi

    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
