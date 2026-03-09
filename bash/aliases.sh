#!/bin/bash
# Useful aliases for Debian/Ubuntu systems

# marckv.dots
alias marckvdots='cd "$MARCKV_DOTS_DIR"'

# Enhanced ls aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git aliases (robbyrussell style)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# System aliases
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Package management aliases for Debian/Ubuntu
alias apt-update='sudo apt update'
alias apt-upgrade='sudo apt upgrade'
alias apt-install='sudo apt install'
alias apt-remove='sudo apt remove'
alias apt-search='apt search'
alias apt-show='apt show'

# System monitoring aliases
alias free='free -h'
alias df='df -h'
alias du='du -h'
alias ports='ports_func'

# Network aliases
alias publip='curl -m 5 -fsS https://ipinfo.io/ip || curl -m 5 -fsS https://ifconfig.me || curl -m 5 -fsS https://api.ipify.org; echo'
alias privip='hostname -I 2>/dev/null | awk "{print \$1}" || ip -4 addr show scope global | awk '\''/inet /{print $2}'\'' | cut -d/ -f1 | head -n1'

# Shell management aliases
alias clearhistory='history -c && history -w'
alias reloadbash='source ~/.bashrc && echo "Bash configuration reloaded."'

# systemctl shortcuts
alias scs='sudo systemctl status'
alias scst='sudo systemctl start'
alias scsp='sudo systemctl stop'
alias scr='sudo systemctl restart'
alias sce='sudo systemctl enable'
alias scd='sudo systemctl disable'
alias scrl='sudo systemctl reload'
alias scls='systemctl list-units --type=service --state=running'
alias scfail='systemctl list-units --state=failed'

# journalctl shortcuts
alias jlog='sudo journalctl -xe'
alias jlogf='sudo journalctl -f'
alias jlogu='sudo journalctl -u'       # usage: jlogu nginx
alias jlogb='sudo journalctl -b'       # logs since last boot
alias jlog1='sudo journalctl -b -1'    # logs from previous boot

# Network — active connections grouped by state
alias conns='ss -s'
alias listen='ss -tlnp'
alias established='ss -tnp state established'

# Server logs
alias tailauth='sudo tail -f /var/log/auth.log'
alias tailsys='sudo tail -f /var/log/syslog'
alias dmesgc='sudo dmesg -T --color=always | tail -50'

# Top processes by resource
alias pscpu='ps aux --sort=-%cpu | head -11'
alias psmem='ps aux --sort=-%mem | head -11'

# Recently modified files in current directory
# Usage: recent [n]  (default: 20 files)
alias recent='find . -maxdepth 3 -not -path "*/\.*" -type f -printf "%T@ %Tc %p\n" 2>/dev/null | sort -rn | head -20 | cut -d" " -f2-'
