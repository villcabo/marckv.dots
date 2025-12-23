#!/bin/bash
# robbyrussell theme implementation (without oh-my-bash)

# Load colors if not already loaded
[[ -z "$GREEN" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../colors.sh"

# Git status functions (robbyrussell style)
git_prompt_info() {
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n "$branch" ]]; then
            echo " git:(${branch})$(git_prompt_status)"
        fi
    fi
}

git_prompt_status() {
    local status=""
    local git_status=$(git status --porcelain 2>/dev/null)
    
    if [[ -n "$git_status" ]]; then
        # Check for different types of changes
        if echo "$git_status" | grep -q '^??'; then
            status+="?"  # Untracked files
        fi
        if echo "$git_status" | grep -q '^[MADRC]'; then
            status+="+"  # Staged changes
        fi
        if echo "$git_status" | grep -q '^.[MD]'; then
            status+="!"  # Unstaged changes
        fi
        if git diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
            :  # Working directory clean
        else
            if [[ -z "$status" ]]; then
                status+="!"
            fi
        fi
    fi
    
    if [[ -n "$status" ]]; then
        echo " ✗"
    fi
}

# Compact directory display function
get_compact_pwd() {
    local pwd_path="$PWD"
    local home_path="$HOME"
    
    # Replace home with ~
    if [[ "$pwd_path" == "$home_path" ]]; then
        echo "~"
        return
    elif [[ "$pwd_path" == "$home_path"/* ]]; then
        pwd_path="~${pwd_path#$home_path}"
    fi
    
    # Special case for .marck.dots subdirectories
    if [[ "$pwd_path" =~ ^~/.marck.dots/.+ ]]; then
        echo "~/.../$(basename "$PWD")"
        return
    fi
    
    # Count the number of slashes to determine depth
    local slash_count=$(echo "$pwd_path" | grep -o "/" | wc -l)
    
    case "$slash_count" in
        0)  # Just ~
            echo "$pwd_path"
            ;;
        1)  # ~/dirname
            echo "$pwd_path"
            ;;
        2)  # ~/dir1/dir2
            echo "$pwd_path"
            ;;
        *)  # ~/dir1/dir2/dir3/... -> .../dir2/dir3
            local dir_name=$(basename "$PWD")
            local parent_name=$(basename "$(dirname "$PWD")")
            echo ".../$parent_name/$dir_name"
            ;;
    esac
}

# Custom prompt function (robbyrussell style)
set_robbyrussell_prompt() {
    local last_exit_code=$?
    
    # User and host info
    local user_host=""
    if [[ $EUID -eq 0 ]]; then
        # Root user - red
        user_host="\[${RED}${BOLD}\]$(whoami)@$(hostname -s)\[${RESET}\]"
    else
        # Normal user - green
        user_host="\[${GREEN}${BOLD}\]$(whoami)@$(hostname -s)\[${RESET}\]"
    fi
    
    # Current directory (compact format)
    local current_dir="\[${CYAN}${BOLD}\]$(get_compact_pwd)\[${RESET}\]"
    
    # Git information
    local git_info="\[${YELLOW}\]$(git_prompt_info)\[${RESET}\]"
    
    # Arrow with color based on last command success
    local arrow=""
    if [[ $last_exit_code -eq 0 ]]; then
        arrow="\[${GREEN}${BOLD}\]➜\[${RESET}\]"
    else
        arrow="\[${RED}${BOLD}\]➜\[${RESET}\]"
    fi
    
    # Build the complete prompt
    PS1="${user_host} ${current_dir}${git_info} ${arrow} "
}

# Activate the theme
PROMPT_COMMAND='set_robbyrussell_prompt'
