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
    
    # Special case for .marckv.dots subdirectories
    if [[ "$pwd_path" =~ ^~/.marckv.dots/.+ ]]; then
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

# Start the prompt on a line of its own, as zsh does.
#
# Output with no final newline — `curl` printing a JSON body, `printf x` — left
# the cursor mid-line, and bash drew the prompt right after it. Readline still
# believes the prompt starts at column 1, so the next redraw returned there and
# overwrote the output: `{"error":"...","error_description":"Usuario o clave
# incorrectos"}` came back as `o clave incorrectos"}` with the prompt on top.
#
# The trick is zsh's PROMPT_SP, and it asks the terminal nothing (a cursor
# query waits on a reply, which over a slow ssh arrives late and gets typed
# into the next command). Print a dim `%` and pad to exactly one line's width,
# then return and clear: started at column 1, that fills the line, `\r` comes
# back to its start and `\e[K` erases it — nothing shows. Started mid-line, the
# padding wraps, `\r` lands at the start of the NEW line, and the output above
# keeps its `%` to say it had no newline.
_prompt_own_line() {
    [[ -t 1 && -n "$COLUMNS" ]] || return 0
    printf '\e[2m%%\e[0m%*s\r\e[K' "$((COLUMNS - 1))" ''
}

# Custom prompt function (robbyrussell style)
set_robbyrussell_prompt() {
    local last_exit_code=$?
    _prompt_own_line

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

# Activate the theme: FIRST in PROMPT_COMMAND, and added to it, not over it.
#
# First, because set_robbyrussell_prompt reads $? for the arrow's colour and
# anything before it — `history -n` included — would leave $? at 0 and the
# arrow green after a failed command.
#
# Added rather than assigned: this line used to be PROMPT_COMMAND=..., which
# threw away the `history -n; history -a` environment.sh had just put there,
# and with it history shared across sessions. Checked before adding, so a
# reload (marckv reload sources .bashrc again) does not stack a second copy.
[[ ";${PROMPT_COMMAND};" == *";set_robbyrussell_prompt;"* ]] \
    || PROMPT_COMMAND="set_robbyrussell_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
