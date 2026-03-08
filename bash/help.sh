#!/bin/bash
# Interactive help for marckv.dots bash configuration
# Command: bashhelp [category]

bashhelp() {
    local R="${RED:-\033[0;31m}"
    local G="${GREEN:-\033[0;32m}"
    local Y="${YELLOW:-\033[1;33m}"
    local M="${MAGENTA:-\033[0;35m}"
    local C="${CYAN:-\033[0;36m}"
    local W="${WHITE:-\033[1;37m}"
    local BO="${BOLD:-\033[1m}"
    local RE="${RESET:-\033[0m}"

    # ── layout helpers ───────────────────────────────────────────────────────
    _h_header() {
        echo -e "\n${BO}${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RE}"
        echo -e "${BO}${C}  $1${RE}"
        echo -e "${BO}${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RE}"
    }
    _h_cmd() {
        # $1 = command/alias   $2 = description   $3 = (optional) usage example
        printf "  ${BO}${G}%-28s${RE}${W}%s${RE}\n" "$1" "$2"
        [[ -n "$3" ]] && printf "  ${Y}%-28s${C}%s${RE}\n" "" "$3"
    }
    _h_section() {
        echo -e "\n  ${BO}${M}▸ $1${RE}"
    }

    local category="${1:-all}"

    # ════════════════════════════════════════════════════════════════════════
    # Category menu
    # ════════════════════════════════════════════════════════════════════════
    if [[ "$category" == "all" ]]; then
        echo -e "\n${BO}${C}╔══════════════════════════════════════════════════════╗${RE}"
        echo -e "${BO}${C}║          marckv.dots — Command Reference             ║${RE}"
        echo -e "${BO}${C}╚══════════════════════════════════════════════════════╝${RE}"
        echo -e "  Usage: ${G}bashhelp${RE} ${Y}[category]${RE}\n"
        echo -e "  ${BO}Available categories:${RE}"
        printf "  ${G}%-18s${RE}%s\n" "nav"       "Directory navigation"
        printf "  ${G}%-18s${RE}%s\n" "git"       "Git aliases"
        printf "  ${G}%-18s${RE}%s\n" "system"    "System monitoring"
        printf "  ${G}%-18s${RE}%s\n" "processes" "Process management"
        printf "  ${G}%-18s${RE}%s\n" "network"   "Network and connections"
        printf "  ${G}%-18s${RE}%s\n" "services"  "systemctl and journalctl"
        printf "  ${G}%-18s${RE}%s\n" "logs"      "Server logs"
        printf "  ${G}%-18s${RE}%s\n" "packages"  "apt package management"
        printf "  ${G}%-18s${RE}%s\n" "files"     "File operations"
        printf "  ${G}%-18s${RE}%s\n" "shell"     "Shell configuration"
        printf "  ${G}%-18s${RE}%s\n" "security"  "Server security"
        echo -e "\n  ${Y}Example:${RE} bashhelp services"
        echo ""
        return 0
    fi

    case "$category" in

    # ════════════════════════════════════════════════════════════════════════
    nav|navigation)
        _h_header "Directory Navigation"
        _h_cmd ".."            "Go up one level"                         ".. → cd .."
        _h_cmd "..."           "Go up two levels"                        "... → cd ../.."
        _h_cmd "...."          "Go up three levels"                      ".... → cd ../../.."
        _h_cmd "mkcd <dir>"    "Create directory and cd into it"         "mkcd projects/new"
        _h_cmd "ls"            "List files with colors"
        _h_cmd "ll"            "List with details (permissions, size, date)"
        _h_cmd "la"            "List including hidden files"
        _h_cmd "l"             "List in compact columns"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    git)
        _h_header "Git — Aliases"
        _h_cmd "gs"            "Repository status (git status)"
        _h_cmd "ga <file>"     "Stage a file (git add)"                  "ga . → stage everything"
        _h_cmd "gc"            "Commit changes (git commit)"             "gc -m 'message'"
        _h_cmd "gp"            "Push changes to remote (git push)"
        _h_cmd "gl"            "Pull changes from remote (git pull)"
        _h_cmd "gd"            "Show diff (git diff)"
        _h_cmd "gb"            "List branches (git branch)"
        _h_cmd "gco <branch>"  "Switch branch (git checkout)"           "gco main"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    system)
        _h_header "System Monitoring"
        _h_section "Resources"
        _h_cmd "free"              "RAM and swap usage (human-readable)"
        _h_cmd "df"                "Disk usage per partition (human-readable)"
        _h_cmd "du"                "File/directory sizes (human-readable)"
        _h_cmd "meminfo"           "Detailed memory breakdown (RAM, buffers, swap)"
        _h_cmd "diskusage [dir]"   "Top 10 largest subdirectories"           "diskusage /var"
        _h_cmd "sysinfo"           "Full snapshot: CPU, RAM, disk, network, processes"
        _h_section "Quick access"
        _h_cmd "ports"             "Open ports and their associated processes"
        _h_cmd "findport <port>"   "Which process is using a port"            "findport 8080"
        _h_cmd "connections [p]"   "TCP connections by state, or filtered by port" "connections 5432"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    processes)
        _h_header "Process Management"
        _h_cmd "pscpu"             "Top 10 processes by CPU usage"
        _h_cmd "psmem"             "Top 10 processes by memory usage"
        _h_cmd "pkillbyname <n>"   "Kill processes by name with confirmation"  "pkillbyname java"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    network)
        _h_header "Network and Connections"
        _h_cmd "privip"            "Show server private IP"
        _h_cmd "publip"            "Show server public IP"
        _h_cmd "listen"            "TCP ports listening with associated process"
        _h_cmd "established"       "Currently established TCP connections"
        _h_cmd "conns"             "Connection summary grouped by state"
        _h_cmd "connections [p]"   "Connection details; filter by port if given"  "connections 443"
        _h_cmd "findport <port>"   "Process occupying a specific port"            "findport 3306"
        _h_cmd "certcheck <host>"  "Check SSL certificate expiry for a domain"    "certcheck example.com"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    services)
        _h_header "Services — systemctl and journalctl"
        _h_section "systemctl"
        _h_cmd "scs <service>"    "Show service status"                         "scs nginx"
        _h_cmd "scst <service>"   "Start a service"                             "scst postgresql"
        _h_cmd "scsp <service>"   "Stop a service"                              "scsp redis"
        _h_cmd "scr <service>"    "Restart a service"                           "scr nginx"
        _h_cmd "scrl <service>"   "Reload config without restarting"            "scrl nginx"
        _h_cmd "sce <service>"    "Enable service at system startup"            "sce docker"
        _h_cmd "scd <service>"    "Disable service at system startup"           "scd snapd"
        _h_cmd "scls"             "List currently active services"
        _h_cmd "scfail"           "List services in failed state"
        _h_section "journalctl"
        _h_cmd "jlog"             "View recent logs with error context"
        _h_cmd "jlogf"            "Follow logs in real time"
        _h_cmd "jlogu <service>"  "Logs for a specific service"                 "jlogu nginx"
        _h_cmd "jlogb"            "Logs since the current system boot"
        _h_cmd "jlog1"            "Logs from the previous boot"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    logs)
        _h_header "Server Logs"
        _h_cmd "tailauth"          "Follow /var/log/auth.log (SSH logins, sudo)"
        _h_cmd "tailsys"           "Follow /var/log/syslog"
        _h_cmd "dmesgc"            "Last 50 kernel messages with colors and timestamps"
        _h_cmd "watchlog <f> [p]"  "Follow any log file, optionally filtered by pattern" "watchlog /var/log/app.log ERROR"
        _h_cmd "jlogf"             "Follow systemd journal in real time"
        _h_cmd "jlogu <service>"   "Real-time logs for a specific service"              "jlogu postgresql"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    packages)
        _h_header "Package Management — apt"
        _h_cmd "apt-update"    "Refresh package list (apt update)"
        _h_cmd "apt-upgrade"   "Install available upgrades"
        _h_cmd "apt-install"   "Install a package"                        "apt-install htop"
        _h_cmd "apt-remove"    "Remove a package"                         "apt-remove snapd"
        _h_cmd "apt-search"    "Search for a package by name"             "apt-search nginx"
        _h_cmd "apt-show"      "Show detailed info about a package"       "apt-show curl"
        _h_cmd "cleanup"       "Free disk: apt cache, old kernels, /tmp, rotated logs (with confirmation)"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    files)
        _h_header "File Operations"
        _h_cmd "backup <file>"    "Timestamped copy before editing"         "backup /etc/nginx/nginx.conf"
        _h_cmd "extract <file>"   "Decompress any archive format"           "extract app.tar.gz"
        _h_cmd "recent"           "Recently modified files (top 20 in current dir)"
        _h_cmd "diskusage [dir]"  "Top 10 heaviest subdirectories"          "diskusage /var/log"
        _h_cmd "rm"               "Remove with confirmation (-i)"
        _h_cmd "cp"               "Copy with confirmation (-i)"
        _h_cmd "mv"               "Move with confirmation (-i)"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    shell)
        _h_header "Shell Configuration"
        _h_cmd "reloadbash"        "Reload bash config without closing the session"
        _h_cmd "clearhistory"      "Clear history for the current session"
        _h_cmd "bashhelp [cat]"    "This help; pass a category for details"   "bashhelp services"
        _h_section "Active settings"
        _h_cmd "histappend"        "History is always appended, never overwritten"
        _h_cmd "checkjobs"         "Warns before exit if background jobs are running"
        _h_cmd "PROMPT_COMMAND"    "History flushed to disk after every command"
        _h_cmd "TMOUT=1800"        "Auto-logout after 30 minutes of inactivity"
        ;;

    # ════════════════════════════════════════════════════════════════════════
    security)
        _h_header "Server Security"
        _h_section "Active protections"
        _h_cmd "umask 027"         "New files deny permissions to others (rwxr-x---)"
        _h_cmd "TMOUT=1800"        "Idle SSH sessions close automatically after 30 min"
        _h_cmd "readonly TMOUT"    "Timeout cannot be unset within the session"
        _h_cmd "HISTCONTROL"       "Records everything; skips consecutive duplicates only"
        _h_cmd "HISTTIMEFORMAT"    "Every command stamped with exact date and time"
        _h_section "Diagnostics"
        _h_cmd "tailauth"          "Watch SSH login attempts and sudo usage live"
        _h_cmd "dmesgc"            "Kernel messages (hardware errors, network issues)"
        _h_cmd "certcheck <host>"  "Verify SSL certificate is not about to expire"    "certcheck example.com"
        _h_cmd "lastb"             "View failed login attempts (requires sudo)"
        ;;

    *)
        echo -e "${R}Unknown category '${category}'.${RE}"
        echo -e "Run ${G}bashhelp${RE} to see available categories."
        return 1
        ;;
    esac

    echo ""
}
