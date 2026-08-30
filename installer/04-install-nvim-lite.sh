#!/bin/bash

# Script to install marckv.dots nvim-lite configuration
# Default: creates a symlink from ~/.config/nvim to repo nvim-lite/
# With -c/--copy: copies the directory instead (useful for remote servers without repo access)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

# Resolve repository root based on this script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARCKV_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_NVIM_LITE="$MARCKV_DOTS_DIR/nvim-lite"
TARGET_NVIM_LITE="$HOME/.config/nvim"

# Parse command + flags
command=""
use_copy=false
use_sync=false
use_deps=false
use_clean=false
use_nvim=false
use_reinstall=false
assume_yes=false

for arg in "$@"; do
    case "$arg" in
        status|uninstall)
            command="$arg"
            ;;
        -c|--copy) use_copy=true ;;
        -s|--sync) use_sync=true ;;
        -d|--deps) use_deps=true ;;
        --clean) use_clean=true ;;
        --nvim) use_nvim=true ;;
        --reinstall) use_reinstall=true ;;
        -y|--yes) assume_yes=true ;;
        -h|--help)
            bold "marckv.dots nvim-lite installer"
            echo ""
            echo -e "${BLUE}Usage:${NC} $0 [command] [options]"
            echo ""
            echo -e "${BLUE}Commands:${NC}"
            echo -e "  ${YELLOW}(none)${NC}        Install the config (symlink by default)."
            echo -e "  ${YELLOW}status${NC}        Report what is installed."
            echo -e "  ${YELLOW}uninstall${NC}     Remove the config (and optionally its data)."
            echo ""
            echo -e "${BLUE}Options:${NC}"
            echo -e "  ${YELLOW}-c, --copy${NC}       Copy the config directory instead of creating a symlink."
            echo -e "                    Useful for remote servers where the repo won't be available."
            echo ""
            echo -e "  ${YELLOW}-d, --deps${NC}       Install system dependencies (gcc, make, ripgrep, fzf, fd,"
            echo -e "                    tree-sitter CLI). Requires root or sudo."
            echo ""
            echo -e "  ${YELLOW}-s, --sync${NC}       Install plugins and treesitter parsers headlessly."
            echo -e "                    Run this after install to avoid waiting on first launch."
            echo ""
            echo -e "  ${YELLOW}--clean${NC}          Remove Neovim's data dirs (share, state, cache) first."
            echo ""
            echo -e "  ${YELLOW}--nvim${NC}           Install or verify the Neovim binary itself."
            echo ""
            echo -e "  ${YELLOW}--reinstall${NC}      Everything, in order: clean, deps, nvim, config, sync."
            echo ""
            echo -e "  ${YELLOW}-y, --yes${NC}        Do not ask for confirmation."
            echo ""
            echo -e "  ${YELLOW}-h, --help${NC}       Show this help."
            echo ""
            echo -e "By default (no options), only the config is installed — a symlink so changes"
            echo -e "in the repo reflect immediately. Passing any of -d/-s/--clean/--nvim runs ONLY"
            echo -e "the steps requested; the config step is skipped unless --reinstall is used."
            echo ""
            exit 0
            ;;
        *)
            error "Unknown argument: $arg (use --help)"
            exit 1
            ;;
    esac
done

# Detect privilege level once: root / sudo / user
# Sets PRIV_MODE to: "root", "sudo", or "user"
if [[ $EUID -eq 0 ]]; then
    PRIV_MODE="root"
elif command -v sudo &>/dev/null; then
    PRIV_MODE="sudo"
else
    PRIV_MODE="user"
fi

# Run a command with appropriate privileges
_run() {
    case "$PRIV_MODE" in
        root) "$@" ;;
        sudo) sudo "$@" ;;
        user)
            error "Cannot run: $*"
            info "No root or sudo access. Run manually with: ${BOLD}sudo $*${NC}"
            return 1
            ;;
    esac
}

# Helper: install packages via apt
_apt_install() {
    local apt_cmd="apt-get install -y $*"
    info "Running: ${BOLD}${apt_cmd}${NC}"
    _run apt-get update -qq || return 1
    _run apt-get install -y "$@"
}

# Install fzf from GitHub (apt version is too old for fzf-lua)
_install_fzf() {
    local fzf_version arch fzf_url
    info "Fetching latest fzf version from GitHub API..."
    fzf_version=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [[ -z "$fzf_version" ]]; then
        error "Failed to fetch fzf version from GitHub API"
        info "Run manually: ${BOLD}curl -s https://api.github.com/repos/junegunn/fzf/releases/latest${NC}"
        return 1
    fi
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac
    fzf_url="https://github.com/junegunn/fzf/releases/download/v${fzf_version}/fzf-${fzf_version}-linux_${arch}.tar.gz"
    local fzf_bin="$HOME/.local/bin"
    if [[ "$PRIV_MODE" == "root" ]]; then
        fzf_bin="/usr/local/bin"
    else
        mkdir -p "$fzf_bin"
    fi
    local tmp_file
    tmp_file=$(mktemp /tmp/fzf-XXXXXX.tar.gz)
    info "Downloading: ${BOLD}fzf v${fzf_version} (${arch})${NC}"
    info "URL: ${fzf_url}"
    info "Install to: ${BOLD}${fzf_bin}/fzf${NC}"
    curl -fSL "$fzf_url" -o "$tmp_file" || { error "Failed to download fzf"; rm -f "$tmp_file"; return 1; }
    tar -C "$fzf_bin" -xzf "$tmp_file" fzf || { error "Failed to extract fzf to ${fzf_bin}"; rm -f "$tmp_file"; return 1; }
    rm -f "$tmp_file"
}

# Install the tree-sitter CLI, pinned to a build this machine's GLIBC can run
#
# Only nvim-treesitter's `main` branch needs this — the `master` branch used on
# Neovim 0.10 downloads pre-generated C sources and builds them with cc alone.
# But `main` is what Neovim 0.11+ gets, and without a WORKING CLI it installs
# exactly nothing: measured on Debian 12, `Installed 0/16 languages`, while the
# file still looked coloured because Vim's legacy regex syntax takes over.
#
# LazyVim asks mason for the CLI and mason fetches the latest, which is built
# against GLIBC 2.39 — newer than Debian 12 (2.36) or Ubuntu 22.04 (2.35), so
# it cannot start. Those two sit in a gap: too new for the old branch, too old
# for the current CLI.
#
# The floors below were read off the binaries with objdump, not guessed:
#   v0.26.13 → GLIBC 2.39   (Debian 13, Ubuntu 24.04+)
#   v0.25.10 → GLIBC 2.34   (Debian 12, Ubuntu 22.04)
#   v0.24.7  → GLIBC 2.29   (Debian 11, Ubuntu 20.04)
#
# Installing it on PATH is enough: LazyVim checks `executable("tree-sitter")`
# first and returns before it ever reaches mason.
_install_tree_sitter_cli() {
    local glibc major minor version arch url dest tmp
    glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    major="${glibc%%.*}"
    minor="${glibc##*.}"
    [[ -z "$major" || -z "$minor" ]] && { error "Could not read the system GLIBC"; return 1; }

    if [[ "$major" -gt 2 ]] || [[ "$major" -eq 2 && "$minor" -ge 39 ]]; then
        version="0.26.13"
    elif [[ "$major" -eq 2 && "$minor" -ge 34 ]]; then
        version="0.25.10"
    elif [[ "$major" -eq 2 && "$minor" -ge 29 ]]; then
        version="0.24.7"
    else
        # Debian 10 and older. Every tree-sitter CLI release ever published,
        # back to v0.20.9, needs GLIBC 2.29 — there is no build to fall back
        # to. It does not matter: a GLIBC that old only runs Neovim 0.9/0.10,
        # which uses nvim-treesitter's `master` branch, and that one builds
        # pre-generated C sources with cc and never asks for a CLI.
        info "GLIBC ${BOLD}${glibc}${NC} — no tree-sitter CLI build runs here, and none is needed"
        info "Neovim 0.9/0.10 uses nvim-treesitter's ${BOLD}master${NC} branch, which only needs a C compiler"
        return 2
    fi

    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64) arch="arm64" ;;
        *) error "Unsupported architecture for tree-sitter CLI: $arch"; return 1 ;;
    esac
    url="https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter-linux-${arch}.gz"

    dest="$HOME/.local/bin"
    if [[ "$PRIV_MODE" == "root" ]]; then
        dest="/usr/local/bin"
    else
        mkdir -p "$dest"
    fi

    info "GLIBC ${BOLD}${glibc}${NC} — installing tree-sitter CLI ${BOLD}v${version}${NC} (${arch})"
    info "URL: ${url}"
    tmp=$(mktemp /tmp/tree-sitter-XXXXXX.gz)
    curl -fSL "$url" -o "$tmp" || { error "Failed to download the tree-sitter CLI"; rm -f "$tmp"; return 1; }
    gunzip -c "$tmp" > "${tmp}.bin" || { error "Failed to unpack the tree-sitter CLI"; rm -f "$tmp" "${tmp}.bin"; return 1; }
    rm -f "$tmp"
    chmod 755 "${tmp}.bin"

    # Run it before installing it. The whole reason this function exists is a
    # binary that downloads and unpacks perfectly and then cannot start, and an
    # executable bit says nothing about that.
    if ! "${tmp}.bin" --version >/dev/null 2>&1; then
        error "The tree-sitter CLI v${version} cannot run on this system:"
        "${tmp}.bin" --version 2>&1 | head -n2 | sed 's/^/  /'
        rm -f "${tmp}.bin"
        return 1
    fi

    _run mv "${tmp}.bin" "${dest}/tree-sitter" || { rm -f "${tmp}.bin"; return 1; }
    _run chmod 755 "${dest}/tree-sitter"
    return 0
}

# --- step: clean ------------------------------------------------------------
# Delegates to clean-nvim-data.sh for the data dirs. Never touches the config
# dir — that is step_config's job, so a --reinstall doesn't lose the backup
# logic step_config already has for an existing ~/.config/nvim.
step_clean() {
    local clean_args=()
    [[ "$assume_yes" == true ]] && clean_args+=(--yes)
    "$SCRIPT_DIR/clean-nvim-data.sh" "${clean_args[@]}"
}

# --- step: deps --------------------------------------------------------------
step_deps() {
    bold "=== nvim-lite dependencies ==="
    echo ""

    # apt packages: command_name -> package_name (use | for alternative command names)
    APT_DEPS="gcc:gcc make:make cc-headers:libc6-dev rg:ripgrep fd|fdfind:fd-find git:git curl:curl"
    missing_apt=()

    for entry in $APT_DEPS; do
        cmd="${entry%%:*}"
        pkg="${entry##*:}"
        # Special case: libc6-dev has no command, check header file
        if [[ "$cmd" == "cc-headers" ]]; then
            if ! echo '#include <stdint.h>' | gcc -E -x c - &>/dev/null 2>&1; then
                warn "libc6-dev not found (C headers missing)"
                missing_apt+=("$pkg")
            else
                success "libc6-dev found"
            fi
        elif [[ "$cmd" == *"|"* ]]; then
            # Multiple possible command names (e.g. fd|fdfind)
            found_alt=false
            for alt in ${cmd//|/ }; do
                if command -v "$alt" &>/dev/null; then
                    success "$pkg found: $($alt --version 2>&1 | head -n1)"
                    found_alt=true
                    break
                fi
            done
            if [[ "$found_alt" == false ]]; then
                warn "$pkg not found (checked: ${cmd//|/, })"
                missing_apt+=("$pkg")
            fi
        elif command -v "$cmd" &>/dev/null; then
            success "$pkg found: $($cmd --version 2>&1 | head -n1)"
        else
            warn "$pkg not found"
            missing_apt+=("$pkg")
        fi
    done

    # Install missing apt packages
    if [[ ${#missing_apt[@]} -gt 0 ]]; then
        echo ""
        info "Missing packages: ${BOLD}${missing_apt[*]}${NC}"
        _apt_install "${missing_apt[@]}" && success "apt packages installed" || error "Failed to install: ${missing_apt[*]}"
    else
        echo ""
        success "All apt dependencies are installed"
    fi

    # fzf: must be v0.40+ (apt version is too old)
    echo ""
    if command -v fzf &>/dev/null; then
        fzf_ver=$(fzf --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        fzf_major=$(echo "$fzf_ver" | cut -d. -f1)
        fzf_minor=$(echo "$fzf_ver" | cut -d. -f2)
        if [[ "$fzf_major" -eq 0 && "$fzf_minor" -lt 40 ]]; then
            warn "fzf found but too old (v$fzf_ver, need v0.40+)"
            info "Installing latest fzf from GitHub..."
            _install_fzf && success "fzf installed: $(fzf --version 2>&1 | head -1)" || error "Failed to install fzf"
        else
            success "fzf found: v$fzf_ver"
        fi
    else
        warn "fzf not found"
        info "Installing latest fzf from GitHub..."
        _install_fzf && success "fzf installed: $(fzf --version 2>&1 | head -1)" || error "Failed to install fzf"
    fi

    # tree-sitter CLI: only nvim-treesitter's `main` branch needs it, but that
    # is what Neovim 0.11+ gets, and without it no parser is ever built.
    echo ""
    if command -v tree-sitter &>/dev/null && tree-sitter --version &>/dev/null; then
        success "tree-sitter CLI found: $(tree-sitter --version 2>&1 | head -1)"
    else
        if command -v tree-sitter &>/dev/null; then
            warn "tree-sitter CLI found but it cannot run here:"
            tree-sitter --version 2>&1 | head -n2 | sed 's/^/  /'
        else
            warn "tree-sitter CLI not found"
        fi
        _install_tree_sitter_cli
        case $? in
            0) success "tree-sitter CLI installed: $(tree-sitter --version 2>&1 | head -1)" ;;
            2) success "tree-sitter CLI not required on this system" ;;
            *) error "Failed to install the tree-sitter CLI" ;;
        esac
    fi

    echo ""
    success "Dependencies check complete."
    return 0
}

# --- step: nvim ---------------------------------------------------------------
# install-nvim.sh REQUIRES root: it writes to /opt and /etc/profile.d. Without
# root or sudo, running it would just fail with a permission error, so instead
# we point the user at it and treat "nvim already installed" as good enough to
# let the rest of the sequence (config, sync) proceed.
step_nvim() {
    if [[ "$PRIV_MODE" == "user" ]]; then
        warn "No root or sudo access — cannot install Neovim automatically."
        info "Run manually: ${BOLD}sudo $SCRIPT_DIR/install-nvim.sh${NC}"
        if command -v nvim &>/dev/null; then
            info "Neovim is already installed: $(nvim --version | head -n1)"
            return 0
        fi
        error "Neovim is not installed."
        return 1
    fi

    # install-nvim.sh short-circuits on its own when the target version is
    # already installed, so this is a verify as much as an install.
    local nvim_args=()
    [[ "$assume_yes" == true ]] && nvim_args+=(--yes)
    _run "$SCRIPT_DIR/install-nvim.sh" "${nvim_args[@]}"
}

# --- step: config --------------------------------------------------------------
step_config() {
    if [[ "$use_copy" == true ]]; then
        bold "=== marckv.dots nvim-lite installer (copy mode) ==="
    else
        bold "=== marckv.dots nvim-lite installer (symlink mode) ==="
    fi

    # Verify source directory exists
    if [[ ! -d "$SOURCE_NVIM_LITE" ]]; then
        error "Source directory not found: $SOURCE_NVIM_LITE"
        return 1
    fi

    # Verify Neovim is installed
    if ! command -v nvim >/dev/null 2>&1; then
        error "Neovim is not installed."
        info "Install Neovim first: ${BOLD}sudo ./install-nvim.sh${NC}"
        return 1
    fi

    nvim_version=$(nvim --version | head -n1)
    info "Neovim found: $nvim_version"
    info "Source config: $SOURCE_NVIM_LITE"
    info "Target config: $TARGET_NVIM_LITE"
    if [[ "$use_copy" == true ]]; then
        info "Mode: ${BOLD}copy${NC} (independent — changes in repo will NOT reflect automatically)"
    else
        info "Mode: ${BOLD}symlink${NC} (live — changes in repo reflect immediately)"
    fi

    # Ensure ~/.config exists
    mkdir -p "$HOME/.config"

    # Check if already installed correctly (symlink mode only)
    if [[ "$use_copy" == false && -L "$TARGET_NVIM_LITE" && "$TARGET_NVIM_LITE" -ef "$SOURCE_NVIM_LITE" ]]; then
        warn "nvim-lite is already linked to repository config"
        info "No changes needed."
        return 0
    fi

    # Handle existing target
    if [[ -e "$TARGET_NVIM_LITE" || -L "$TARGET_NVIM_LITE" ]]; then
        warn "~/.config/nvim already exists"

        if [[ -L "$TARGET_NVIM_LITE" ]]; then
            info "Current symlink target: $(readlink "$TARGET_NVIM_LITE")"
        else
            info "Current target is a regular directory"
        fi

        # Create backup before replacing
        backup_dir="${TARGET_NVIM_LITE}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup: $backup_dir"
        mv "$TARGET_NVIM_LITE" "$backup_dir"
        success "Backup created: $backup_dir"
    fi

    if [[ "$use_copy" == true ]]; then
        cp -r "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
        # nvim-lite/tests is 176K of this directory's 276K (measured with `du
        # -sh`) — dev-only fixtures and harness that never run on the target
        # server. Shipping them defeats the point of a config whose whole
        # reason to exist is being light on a server.
        if [[ -d "$TARGET_NVIM_LITE/tests" ]]; then
            rm -rf "$TARGET_NVIM_LITE/tests"
            info "Removed copied tests/ (dev-only, not needed on the target host)"
        fi
        success "Directory copied: $SOURCE_NVIM_LITE → $TARGET_NVIM_LITE"
        # Remove lazy-lock.json so each host resolves plugins for its Neovim version.
        # On older Neovim (e.g. Debian 11 / Ubuntu 20), this is critical so the
        # LazyVim tag pin in lazy.lua actually gets applied instead of being
        # overridden by a lockfile generated on a newer system.
        if [[ -f "$TARGET_NVIM_LITE/lazy-lock.json" ]]; then
            rm -f "$TARGET_NVIM_LITE/lazy-lock.json"
            info "Removed copied lazy-lock.json so plugins resolve to this host's Neovim version"
        fi
    else
        ln -s "$SOURCE_NVIM_LITE" "$TARGET_NVIM_LITE"
        success "Symlink created: $TARGET_NVIM_LITE -> $SOURCE_NVIM_LITE"
    fi

    echo ""
    bold "To use nvim-lite:"
    echo -e "  ${YELLOW}nvim${NC}"
    echo ""
    info "First launch will install plugins automatically via lazy.nvim."
    if [[ "$use_copy" == true ]]; then
        info "Note: to sync future repo changes, run: ${BOLD}$0 --copy${NC}"
    fi

    if [[ -f "$SOURCE_NVIM_LITE/VERSION" ]]; then
        success "nvim-lite v$(cat "$SOURCE_NVIM_LITE/VERSION") ready."
    fi

    return 0
}

# --- step: sync ------------------------------------------------------------
step_sync() {
    bold "=== nvim-lite sync (headless) ==="

    if ! command -v nvim >/dev/null 2>&1; then
        error "Neovim is not installed."
        return 1
    fi

    if [[ ! -d "$TARGET_NVIM_LITE" ]]; then
        error "nvim-lite is not installed. Run ${BOLD}$0${NC} first."
        return 1
    fi

    info "Installing plugins..."
    # Lazy prints a fetch/status/checkout line per plugin per phase — over a
    # hundred lines that bury the two that matter. Kept in a log instead.
    if ! nvim --headless "+Lazy! sync" +qa >/tmp/nvim-lite-sync.log 2>&1; then
        warn "Lazy sync reported errors (may be non-fatal) — see /tmp/nvim-lite-sync.log"
    fi
    success "Plugins installed"

    # Parsers are installed EXPLICITLY, and then counted.
    #
    # What used to be here was one line:
    #     nvim --headless "+lua pcall(function() vim.cmd('TSUpdateSync') end)"
    # under a comment claiming "Lazy sync above already installs parsers
    # declared in ensure_installed". Both halves were wrong, and the pcall hid
    # it: TSUpdateSync only exists on nvim-treesitter's `master` branch, and
    # `main` — which is what Neovim 0.11+ gets — installs parsers lazily, when
    # a matching file is first opened. Measured on Debian 13 after a full
    # reinstall: 16 of 24, missing yaml, bash, python, markdown, json, make,
    # terraform and hcl. The ones a server actually opens.
    #
    # Nothing complained, because a missing parser is invisible: Vim's legacy
    # regex syntax takes over and the file still looks coloured.
    #
    # The language list is read out of the config rather than repeated here, so
    # adding a parser to nvim-lite is one edit, not two.
    local langs
    langs=$(sed -n '/^local server_parsers/,/^}/p' "$TARGET_NVIM_LITE/lua/plugins/treesitter.lua" 2>/dev/null \
            | grep -oE '"[a-z_]+"' | tr -d '"' | tr '\n' ' ')
    if [[ -z "$langs" ]]; then
        error "Could not read the parser list from the installed config."
        info "Expected: ${BOLD}${TARGET_NVIM_LITE}/lua/plugins/treesitter.lua${NC}"
        return 1
    fi

    local wanted
    wanted=$(printf '%s' "$langs" | wc -w)
    info "Compiling treesitter parsers (${BOLD}${wanted}${NC} declared)..."

    # Only what is missing, and synchronously. Both branches offer a
    # synchronous form, so no polling heuristic is needed:
    #   main   -> require("nvim-treesitter").install(langs):wait()
    #   master -> :TSInstallSync
    # Reinstalling the whole list is not free on master: it recompiles every
    # grammar from source, around 900 s.
    # Retried until it stops making progress, because one pass is not enough.
    #
    # On the `main` branch `install():wait()` returns before every grammar has
    # landed. Measured across the eight distros in one run: Ubuntu 22.04 came
    # out missing properties/regex, Ubuntu 24.04 missing hcl, Ubuntu 26.04
    # missing diff/regex — a DIFFERENT set each time, from an identical config.
    # The suite tolerated it because a file with no parser still gets Vim's
    # regex syntax and S7 accepts that, so the only symptom was a server that
    # silently ended up with a different editor than the one next to it.
    #
    # Looping while the missing list shrinks is not the "wait until the count
    # settles" heuristic that was rejected earlier — that one asked a compiling
    # parser whether it was done and read silence as yes. This asks the disk
    # what exists, reinstalls exactly what does not, and stops when a whole
    # pass adds nothing. Grammars that cannot exist on this branch (jsonc) end
    # it after one wasted pass rather than hanging on a timeout.
    nvim --headless -c "lua
        require('lazy').load({ plugins = { 'nvim-treesitter' } })
        local langs = vim.split('$langs', ' +', { trimempty = true })
        local data = vim.fn.stdpath('data')
        -- filereadable, not nvim_get_runtime_file: the runtime path is
        -- resolved against a cache, and a parser written moments ago by
        -- another process is exactly the case it gets wrong.
        local function missing_now()
          local out = {}
          for _, lang in ipairs(langs) do
            local main = data .. '/site/parser/' .. lang .. '.so'
            local master = data .. '/lazy/nvim-treesitter/parser/' .. lang .. '.so'
            if vim.fn.filereadable(main) == 0 and vim.fn.filereadable(master) == 0 then
              out[#out + 1] = lang
            end
          end
          return out
        end
        local ts = require('nvim-treesitter')
        local previous = #langs + 1
        for _ = 1, 4 do
          local missing = missing_now()
          if #missing == 0 or #missing >= previous then break end
          previous = #missing
          if type(ts.install) == 'function' then
            local h = ts.install(missing)
            if type(h) == 'table' and h.wait then h:wait(600000) end
          else
            vim.cmd('TSInstallSync ' .. table.concat(missing, ' '))
          end
        end
    " -c 'qa' 2>&1 | grep -vE '^$' || true

    # Count the DECLARED parsers, not every .so on disk.
    #
    # Counting files was the first version and it hid a real gap: the `main`
    # branch auto-installs a parser when a matching file is opened, so extras
    # (dtd, tsv, csv...) accumulate and push the total past the declared count
    # while a declared one is still missing. Debian 13 reported "25 built" with
    # jsonc absent, because main has no jsonc grammar at all.
    #
    # Asking Neovim is also the only portable way to look: master keeps parsers
    # inside the plugin directory, main writes them to the site directory, and
    # a hardcoded path is right on one branch and wrong on the other.
    local missing
    missing=$(nvim --headless -c "lua
        local data = vim.fn.stdpath('data')
        local out = {}
        for _, lang in ipairs(vim.split('$langs', ' +', { trimempty = true })) do
          local main = data .. '/site/parser/' .. lang .. '.so'
          local master = data .. '/lazy/nvim-treesitter/parser/' .. lang .. '.so'
          if vim.fn.filereadable(main) == 0 and vim.fn.filereadable(master) == 0 then
            out[#out + 1] = lang
          end
        end
        io.stderr:write(table.concat(out, ' '))
    " -c 'qa' 2>&1 >/dev/null | tr -d '\r')

    if [[ -n "$missing" ]]; then
        local n
        n=$(printf '%s' "$missing" | wc -w)
        warn "$((wanted - n)) of ${wanted} parsers built — missing: ${BOLD}${missing}${NC}"
        info "Those file types fall back to Vim's regex syntax: still coloured, less accurate"
        info "Some grammars do not exist on every nvim-treesitter branch, so this is not always fixable"
    else
        success "all ${wanted} treesitter parsers built"
    fi

    echo ""
    success "nvim-lite is ready to use."
    return 0
}

# --- command: status ---------------------------------------------------------
# Read-only: never modifies anything, always exits 0.
cmd_status() {
    bold "=== nvim-lite status ==="
    echo ""

    # config
    bold "-- config --"
    if [[ -L "$TARGET_NVIM_LITE" ]]; then
        local link_target
        link_target=$(readlink -f "$TARGET_NVIM_LITE" 2>/dev/null || readlink "$TARGET_NVIM_LITE")
        if [[ "$TARGET_NVIM_LITE" -ef "$SOURCE_NVIM_LITE" ]]; then
            success "symlink -> $link_target (this repo's nvim-lite)"
        else
            info "symlink -> $link_target (not this repo's nvim-lite)"
        fi
    elif [[ -d "$TARGET_NVIM_LITE" ]]; then
        info "regular directory: $TARGET_NVIM_LITE"
    else
        warn "not installed: $TARGET_NVIM_LITE"
    fi
    echo ""

    # version (of the installed config, not the repo)
    bold "-- version --"
    if [[ -f "$TARGET_NVIM_LITE/VERSION" ]]; then
        info "$(cat "$TARGET_NVIM_LITE/VERSION")"
    else
        info "unknown"
    fi
    echo ""

    # neovim
    bold "-- neovim --"
    if command -v nvim &>/dev/null; then
        success "$(nvim --version | head -n1)"
    else
        warn "nvim not found"
    fi
    local glibc
    glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    info "GLIBC: ${glibc:-unknown}"
    echo ""

    # deps
    bold "-- deps --"
    local dep_cmds="gcc make git curl rg fzf tree-sitter"
    for dep in $dep_cmds; do
        if command -v "$dep" &>/dev/null; then
            success "$dep found"
        else
            warn "$dep not found"
        fi
    done
    if command -v fd &>/dev/null; then
        success "fd found"
    elif command -v fdfind &>/dev/null; then
        success "fd found (as fdfind)"
    else
        warn "fd not found"
    fi
    echo ""

    # data
    bold "-- data --"
    local data_dirs=("$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim")
    local total_kb=0
    for dir in "${data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local size kb
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
            total_kb=$((total_kb + ${kb:-0}))
            info "$dir: $size"
        else
            info "$dir: not present"
        fi
    done
    if [[ "$total_kb" -gt 0 ]]; then
        info "total: $(awk -v kb="$total_kb" 'BEGIN { printf "%.1fM\n", kb / 1024 }')"
    fi
    echo ""

    # plugins
    bold "-- plugins --"
    local lazy_dir="$HOME/.local/share/nvim/lazy"
    if [[ -d "$lazy_dir" ]]; then
        local plugin_count
        plugin_count=$(find "$lazy_dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
        info "$plugin_count plugin(s) in $lazy_dir"
    else
        info "no plugins installed"
    fi
    echo ""

    # parsers
    bold "-- parsers --"
    local parser_count=0
    local p1_dir="$HOME/.local/share/nvim/lazy/nvim-treesitter/parser"
    local p2_dir="$HOME/.local/share/nvim/site/parser"
    if [[ -d "$p1_dir" ]]; then
        parser_count=$((parser_count + $(find "$p1_dir" -name '*.so' | wc -l)))
    fi
    if [[ -d "$p2_dir" ]]; then
        parser_count=$((parser_count + $(find "$p2_dir" -name '*.so' | wc -l)))
    fi
    info "$parser_count treesitter parser(s) built"
    echo ""

    return 0
}

# --- command: uninstall -------------------------------------------------------
cmd_uninstall() {
    bold "=== nvim-lite uninstall ==="
    echo ""

    if [[ ! -e "$TARGET_NVIM_LITE" && ! -L "$TARGET_NVIM_LITE" ]]; then
        success "Nothing to uninstall — $TARGET_NVIM_LITE does not exist."
    else
        bold "Preview:"
        if [[ -L "$TARGET_NVIM_LITE" ]]; then
            echo -e "  ${RED}${BOLD}${TARGET_NVIM_LITE}${NC} ${BLUE}(symlink -> $(readlink "$TARGET_NVIM_LITE"))${NC} — will be removed"
        else
            echo -e "  ${RED}${BOLD}${TARGET_NVIM_LITE}${NC} — will be moved to a timestamped backup"
        fi
        echo ""

        if [[ "$assume_yes" != true ]]; then
            read -p "Proceed? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Aborted. Nothing was removed."
                return 0
            fi
        fi

        if [[ -L "$TARGET_NVIM_LITE" ]]; then
            rm "$TARGET_NVIM_LITE"
            success "Removed symlink: $TARGET_NVIM_LITE"
        else
            local backup_dir="${TARGET_NVIM_LITE}.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$TARGET_NVIM_LITE" "$backup_dir"
            success "Moved to backup: $backup_dir"
        fi
    fi

    echo ""
    if [[ "$assume_yes" == true ]]; then
        info "Removing data dirs too (--yes)..."
        "$SCRIPT_DIR/clean-nvim-data.sh" --yes
    else
        read -p "Also remove Neovim's data dirs (share, state, cache)? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/clean-nvim-data.sh" --yes
        else
            info "Data dirs left untouched."
        fi
    fi

    echo ""
    info "The Neovim binary and system dependencies were NOT touched."
    return 0
}

# --- dispatcher --------------------------------------------------------------
if [[ "$command" == "status" ]]; then
    cmd_status
    exit $?
fi

if [[ "$command" == "uninstall" ]]; then
    cmd_uninstall
    exit $?
fi

if [[ "$use_reinstall" == true ]]; then
    use_clean=true
    use_deps=true
    use_nvim=true
    use_sync=true
fi

any_step_requested=false
if [[ "$use_clean" == true || "$use_deps" == true || "$use_nvim" == true || "$use_sync" == true || "$use_reinstall" == true ]]; then
    any_step_requested=true
fi

if [[ "$any_step_requested" == false ]]; then
    # Default behaviour: just install the config, same as before this refactor.
    step_config
    exit $?
fi

# Canonical execution order: clean -> deps -> nvim -> config -> sync.
#
# deps has to run before nvim and sync: gcc must exist before step_sync, which
# compiles treesitter parsers, and installing nvim itself doesn't depend on
# these deps but grouping deps early keeps the sequence linear and predictable.
steps=()
[[ "$use_clean" == true ]] && steps+=("clean")
[[ "$use_deps" == true ]] && steps+=("deps")
[[ "$use_nvim" == true ]] && steps+=("nvim")
# step_config only runs here as part of an explicit --reinstall — requesting
# -d/-s/--clean/--nvim on their own must NOT also install the config, to keep
# today's usage (e.g. `-d -s` alone) working the same way it always has.
[[ "$use_reinstall" == true ]] && steps+=("config")
[[ "$use_sync" == true ]] && steps+=("sync")

total_steps=${#steps[@]}
step_num=0
for step in "${steps[@]}"; do
    step_num=$((step_num + 1))
    echo ""
    bold "=== [${step_num}/${total_steps}] ${step} ==="
    # Called indirectly: the alternative was a five-arm case whose arms were
    # identical apart from the name, and every future step would have added a
    # sixth. `steps` is built above from our own flags, never from user input.
    if ! "step_${step}"; then
        error "Step '${step}' failed. Remaining steps did not run: ${steps[*]:${step_num}}"
        exit 1
    fi
done

echo ""
success "All requested steps completed."
