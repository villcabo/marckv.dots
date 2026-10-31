#!/bin/bash
#
# One installer for the whole working setup: bash, the docker aliases, tmux and
# Neovim with the nvim-lite config — what used to take eight commands and two
# `source` lines typed by hand in between.
#
# It does not re-implement any of them. Each step is the numbered installer
# that already owns that piece, called with -y after ONE preview of the whole
# plan and ONE confirmation here. Every one of them still prints its own
# preview as it runs, so the output is the record of what was done.
#
# The two `source` lines the manual sequence needed are gone for different
# reasons. The one after 01 only ever served the user's own shell — no
# installer reads bash/ — so it becomes one `exec bash` at the end. The one
# after install-nvim.sh was a bug: Neovim landed in /opt with its PATH in
# /etc/profile.d, which a running process never re-reads, and the config step
# right after it said Neovim was not installed. 04 now adopts the new PATH for
# the rest of its own run.
#
# 05 (atuin) is left out on purpose: it is optional, and has its own installer.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="install.sh"
INSTALLER_ABOUT="The whole setup in one go: bash, docker aliases, tmux, and an editor config."

use_copy=false
editor=nvim
_editor_next=false

# --editor takes a value, and the shared parser hands flags over one argument
# at a time — so `--editor` notes that the NEXT argument is its value.
# `--editor=vim` works too.
_set_editor() {
    case "$1" in
        nvim|vim|none) editor="$1" ;;
        *) die "--editor takes nvim, vim or none — got '${1}'" ;;
    esac
}

installer_flag() {
    if [[ "$_editor_next" == true ]]; then
        _editor_next=false
        _set_editor "$1"
        return 0
    fi
    case "$1" in
        -c|--copy)  use_copy=true ;;
        --editor)   _editor_next=true ;;
        --editor=*) _set_editor "${1#--editor=}" ;;
        *) return 1 ;;
    esac
    return 0
}

installer_usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    echo
    echo -e "  ${INSTALLER_ABOUT}"
    echo
    echo -e "${BLUE}Usage:${NC} ./${INSTALLER_NAME} [install|status|uninstall] [--editor nvim|vim|none] [-c] [-y]"
    echo
    echo -e "  ${YELLOW}install${NC}      Everything below, in order. The default."
    echo -e "  ${YELLOW}status${NC}       What each piece reports about itself."
    echo -e "  ${YELLOW}uninstall${NC}    Undo all of it, in reverse order."
    echo
    echo -e "  ${YELLOW}-c, --copy${NC}   Copy the nvim-lite config instead of symlinking it — for a"
    echo -e "               server that should not depend on the repo staying where it is."
    echo -e "  ${YELLOW}--editor${NC}     Which editor config is step 4:"
    echo -e "                 ${BOLD}nvim${NC}  Neovim + nvim-lite — plugins, parsers, downloads. The default."
    echo -e "                 ${BOLD}vim${NC}   vim-lite — plain Vim, no plugins, nothing downloaded. For a"
    echo -e "                       host with no internet, or an EDR."
    echo -e "                 ${BOLD}none${NC}  no editor: bash, docker and tmux only."
    echo -e "  ${YELLOW}-y, --yes${NC}    Skip the one confirmation. The plan is still printed."
    echo
    echo -e "${BLUE}Runs:${NC}"
    echo -e "  1. 01-install-bash.sh             bash config, loaded from ~/.bashrc"
    echo -e "  2. 02-install-docker-aliases.sh   docker and compose commands"
    echo -e "  3. 03-install-tmux.sh             tmux config + TPM and its plugins"
    echo -e "  4. 04-install-nvim-lite.sh --full system deps, Neovim, the config, plugins"
    echo
    echo -e "Every step skips what is already in place, so running it again is how you"
    echo -e "finish an install that stopped half way."
    echo
}

# The steps, in order, as "label<TAB>script<TAB>what it does". One record per
# step rather than parallel lists, so a label can never drift from its script.
_steps() {
    local nvim_args="--full" vim_args=""
    [[ "$use_copy" == true ]] && nvim_args="--full --copy" vim_args="--copy"
    printf '%s\t%s\t%s\n' \
        "bash"   "01-install-bash.sh"           "loads bash/.bashrc from ~/.bashrc" \
        "docker" "02-install-docker-aliases.sh" "loads docker-aliases/init.sh from ~/.bash_aliases" \
        "tmux"   "03-install-tmux.sh"           "links ~/.tmux.conf, installs TPM and its plugins"
    case "$editor" in
        nvim) printf '%s\t%s\t%s\n' "nvim" "04-install-nvim-lite.sh $nvim_args" "system deps, Neovim, the nvim-lite config, plugins" ;;
        vim)  printf '%s\t%s\t%s\n' "vim" "06-install-vim.sh $vim_args" "vim-lite as ~/.vim: plain Vim, nothing downloaded" ;;
    esac
}

# Ask for sudo now, while the person who just said yes is still watching.
#
# The first step that needs it is the fourth — apt, then Neovim into /opt — a
# minute or more in. Left to that point the password prompt lands in the middle
# of the output, after the screen has scrolled past the plan, on a run the
# person may have walked away from.
#
# Only an account lib/common.sh judged able to sudo gets here: one with no
# sudo rights is already in user mode, and is never asked.
#
# A refusal at a terminal still stops the run. Whoever typed a wrong password
# meant a system-wide install; quietly carrying on as a user would put a second
# Neovim under ~/.local instead, and that is not what they asked for. They are
# told how to ask for the user install. With no terminal there is nobody to
# type a password at all, so the run goes on as a user rather than failing at
# step 4.
_prime_sudo() {
    [[ "$PRIV_MODE" == "sudo" ]] || return 0
    if [[ -t 0 ]]; then
        info "System packages need ${BOLD}sudo${NC} — asking once, now"
        sudo -v && return 0
        error "sudo was not granted. Nothing was changed."
        info "To install for ${BOLD}$(id -un)${NC} only, under ~/.local: ${BOLD}MARCKV_PRIV_MODE=user ./${INSTALLER_NAME}${NC}"
        exit 1
    fi
    sudo -n true 2>/dev/null && return 0
    warn "sudo wants a password and there is no terminal to type it in — installing for ${BOLD}$(id -un)${NC} only"
    PRIV_MODE="user"
}

do_install() {
    local label script what n=0 total failed=""

    [[ "$_editor_next" == true ]] && die "--editor needs a value: nvim, vim or none"
    total=$(_steps | wc -l)

    preview_open "Install the marckv.dots setup"
    while IFS=$'\t' read -r label script what; do
        n=$((n + 1))
        preview_line "$n. $label" "$what"
        preview_line "" "${DIM}./$script${NC}"
    done < <(_steps)
    preview_line "privileges" "$(priv_label)"
    if [[ "$editor" != none ]]; then
        [[ "$use_copy" == true ]] \
            && preview_line "editor config" "copied — the server will not need the repo afterwards" \
            || preview_line "editor config" "symlinked — repo edits are live"
    fi
    preview_line "deletes" "nothing — every step backs up what it replaces"
    preview_close

    confirm "Install all of it?" || { info "Cancelled — nothing was changed."; return 0; }
    _prime_sudo
    # Every step re-sources lib/common.sh; this keeps them on the answer above.
    export MARCKV_PRIV_MODE="$PRIV_MODE"

    # Read into an array BEFORE running anything. Looping `while read … < <(_steps)`
    # would hand the step list to each installer as its stdin, and the first one
    # that reads anything — sudo, a prompt — would swallow the steps after it.
    local records=() rec
    while IFS= read -r rec; do records+=("$rec"); done < <(_steps)

    n=0
    for rec in "${records[@]}"; do
        IFS=$'\t' read -r label script what <<< "$rec"
        n=$((n + 1))
        echo
        bold "━━━ [$n/$total] $label ━━━"
        # Word-split on purpose: "$script" carries 04's flags. They come from
        # _steps above, never from the user.
        # shellcheck disable=SC2086
        if ! "$INSTALLER_DIR/"$script -y; then
            failed="$label"
            break
        fi
    done

    echo
    if [[ -n "$failed" ]]; then
        error "Stopped at step ${BOLD}$failed${NC}. The steps after it did not run."
        info "Fix what it reported, then run ${BOLD}./${INSTALLER_NAME}${NC} again — finished steps are skipped."
        return 1
    fi

    success "All $total steps finished."
    echo
    info "Load it into this shell with: ${YELLOW}exec bash${NC}   (or open a new terminal)"
}

do_status() {
    local label script what rc=0
    while IFS=$'\t' read -r label script what; do
        echo
        bold "━━━ $label ━━━"
        # status takes no step flags; only the script name is wanted here.
        "$INSTALLER_DIR/${script%% *}" status || rc=1
    done < <(_steps)
    return $rc
}

do_uninstall() {
    local label script what steps=()

    while IFS=$'\t' read -r label script what; do
        steps=("${script%% *}" "${steps[@]}")
    done < <(_steps)

    preview_open "Uninstall the marckv.dots setup"
    preview_line "order" "nvim, tmux, docker, bash — the reverse of install"
    preview_line "removes" "the source lines in ~/.bashrc and ~/.bash_aliases"
    preview_line "removes" "~/.tmux.conf and ~/.config/nvim, if they are ours"
    preview_line "deletes" "TPM and its plugins (~/.tmux/plugins)"
    preview_line "deletes" "Neovim's data: plugins, state, cache (~/.local/share/nvim …)"
    preview_line "keeps" "the repo, the Neovim binary, the system packages"
    preview_close

    # Destructive, not plain: plugins and Neovim's state are deleted, and a
    # pipe must not be enough to say yes to that. -y still is.
    local rc=0
    confirm_destructive "Uninstall all of it?" || rc=$?
    if (( rc != 0 )); then
        info "Cancelled — nothing was removed."
        return "$rc"
    fi

    local s
    for s in "${steps[@]}"; do
        echo
        bold "━━━ $s ━━━"
        "$INSTALLER_DIR/$s" uninstall -y </dev/null || {
            error "$s did not finish its uninstall; the ones after it did not run."
            return 1
        }
    done
    echo
    success "Uninstalled. Open a new shell to drop what the old one already loaded."
}

installer_main "$@"
