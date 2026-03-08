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

# Show top 10 directories consuming the most disk space
# Usage: diskusage [path]   (default: current directory)
diskusage() {
    local target="${1:-.}"
    echo "Top 10 largest directories in ${target}:"
    du -h --max-depth=1 "$target" 2>/dev/null | sort -rh | head -11 | tail -10
}

# Memory breakdown: totals, buffers, swap
meminfo() {
    echo "=== Memory ==="
    free -h
    echo ""
    if [[ -f /proc/meminfo ]]; then
        echo "=== Details ==="
        awk '/MemTotal|MemFree|MemAvailable|Buffers|^Cached|SwapTotal|SwapFree/{printf "%-20s %s\n", $1, $2" "$3}' /proc/meminfo
    fi
}

# Active TCP connections grouped by state
# Usage: connections [port]
connections() {
    if ! command -v ss &>/dev/null; then
        echo "ss not available"; return 1
    fi
    if [[ -n "$1" ]]; then
        echo "=== Connections on port $1 ==="
        ss -tnp "sport = :$1 or dport = :$1"
    else
        echo "=== Connection summary by state ==="
        ss -tan | awk 'NR>1{count[$1]++} END{for(s in count) printf "%-15s %d\n", s, count[s]}' | sort -k2 -rn
        echo ""
        echo "=== Established connections ==="
        ss -tnp state established
    fi
}

# Show which process is using a given port
# Usage: findport <port>
findport() {
    if [[ -z "$1" ]]; then
        echo "Usage: findport <port>"
        return 1
    fi
    local port="$1"
    echo "=== Listening on port $port ==="
    ss -tlnp "sport = :$port"
    echo ""
    echo "=== Process info ==="
    local pid
    pid=$(ss -tlnp "sport = :$port" 2>/dev/null | awk 'NR>1{match($0,/pid=([0-9]+)/,a); if(a[1]) print a[1]}' | head -1)
    if [[ -n "$pid" ]]; then
        ps -p "$pid" -o pid,user,cmd --no-headers
    else
        echo "No process found (may require sudo)"
        sudo ss -tlnp "sport = :$port" 2>/dev/null | awk 'NR>1'
    fi
}

# Create a timestamped backup of a file
# Usage: backup <file>
backup() {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file>"
        return 1
    fi
    if [[ ! -e "$1" ]]; then
        echo "Error: '$1' not found"
        return 1
    fi
    local dest="${1}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -a "$1" "$dest" && echo "Backup created: $dest"
}

# Follow a log file with optional grep filter
# Usage: watchlog <file> [pattern]
watchlog() {
    if [[ -z "$1" ]]; then
        echo "Usage: watchlog <file> [pattern]"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' not found"
        return 1
    fi
    if [[ -n "$2" ]]; then
        sudo tail -f "$1" | grep --line-buffered --color=auto "$2"
    else
        sudo tail -f "$1"
    fi
}

# Clean apt cache, old kernels, temp files, and rotated logs
cleanup() {
    echo "=== Cleanup preview ==="
    echo "  apt cache:    $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
    local old_kernels
    old_kernels=$(dpkg -l 'linux-image-*' 'linux-headers-*' 2>/dev/null \
        | awk '/^ii/{print $2}' \
        | grep -v "$(uname -r | sed 's/-generic//')" \
        | grep -v "linux-image-generic" \
        | grep -v "linux-headers-generic" \
        | wc -l)
    echo "  old kernels:  ${old_kernels} package(s)"
    echo "  /tmp files:   $(find /tmp -maxdepth 1 -mtime +7 2>/dev/null | wc -l) older than 7 days"
    echo "  rotated logs: $(find /var/log -name '*.gz' -o -name '*.1' 2>/dev/null | wc -l) file(s)"
    echo ""
    read -r -p "Proceed with cleanup? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && echo "Cancelled." && return 0

    echo "Cleaning apt cache..."
    sudo apt-get autoremove -y && sudo apt-get autoclean -y

    echo "Cleaning /tmp (files older than 7 days)..."
    find /tmp -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null || true

    echo "Cleaning rotated logs..."
    sudo find /var/log -name '*.gz' -delete 2>/dev/null || true
    sudo find /var/log -name '*.1' -delete 2>/dev/null || true

    echo "Done."
}

# Check SSL certificate expiry for a domain
# Usage: certcheck <domain> [port]   (default port: 443)
certcheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: certcheck <domain> [port]"
        return 1
    fi
    local domain="$1"
    local port="${2:-443}"
    if ! command -v openssl &>/dev/null; then
        echo "Error: openssl not found"
        return 1
    fi
    local cert_info
    cert_info=$(echo | openssl s_client -servername "$domain" -connect "${domain}:${port}" 2>/dev/null \
        | openssl x509 -noout -subject -dates -issuer 2>/dev/null)
    if [[ -z "$cert_info" ]]; then
        echo "Error: could not retrieve certificate for ${domain}:${port}"
        return 1
    fi
    echo "=== Certificate: $domain ==="
    echo "$cert_info"
    echo ""
    local expiry
    expiry=$(echo "$cert_info" | grep 'notAfter' | cut -d= -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    if (( days_left <= 14 )); then
        echo "  ⚠️  EXPIRES IN ${days_left} DAY(S) — renew immediately!"
    elif (( days_left <= 30 )); then
        echo "  ⚠  Expires in ${days_left} days"
    else
        echo "  ✓  Expires in ${days_left} days"
    fi
}

# Full system snapshot: OS, CPU, memory, disk, network, top processes
sysinfo() {
    echo -e "${BOLD}${CYAN}════════════════════ System Info ════════════════════${RESET}"

    # OS / Kernel
    echo -e "${BOLD}${BLUE}OS:${RESET}      $(uname -sr)"
    command -v lsb_release &>/dev/null && echo -e "${BOLD}${BLUE}Distro:${RESET}  $(lsb_release -d | cut -f2)"
    echo -e "${BOLD}${BLUE}Host:${RESET}    $(hostname -f 2>/dev/null || hostname)"
    echo -e "${BOLD}${BLUE}Uptime:${RESET}  $(uptime -p 2>/dev/null || uptime)"

    # CPU
    echo ""
    echo -e "${BOLD}${BLUE}CPU:${RESET}     $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"
    echo -e "${BOLD}${BLUE}Cores:${RESET}   $(nproc) logical / $(grep -c '^processor' /proc/cpuinfo) total threads"
    echo -e "${BOLD}${BLUE}Load:${RESET}    $(uptime | awk -F'load average:' '{print $2}' | xargs)"

    # Memory
    echo ""
    echo -e "${BOLD}${BLUE}Memory:${RESET}"
    free -h | awk 'NR<=2'

    # Disk
    echo ""
    echo -e "${BOLD}${BLUE}Disk:${RESET}"
    df -h --output=target,size,used,avail,pcent | grep -v 'tmpfs\|udev\|loop' | head -10

    # Network interfaces
    echo ""
    echo -e "${BOLD}${BLUE}Network:${RESET}"
    ip -brief address show 2>/dev/null | grep -v '^lo' || hostname -I

    # Top 5 CPU-consuming processes
    echo ""
    echo -e "${BOLD}${BLUE}Top processes (CPU):${RESET}"
    ps aux --sort=-%cpu | awk 'NR==1 || NR<=6' | awk '{printf "%-10s %-6s %-6s %s\n", $1, $2, $3, $11}'

    echo -e "${BOLD}${CYAN}═════════════════════════════════════════════════════${RESET}"
}
