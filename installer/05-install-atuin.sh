#!/bin/bash
#
# Installs atuin (shell history with fuzzy search) and links its config.
# Sync is disabled in the repo config: history never leaves the machine.

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

INSTALLER_NAME="05-install-atuin.sh"
INSTALLER_ABOUT="Installs atuin and links ~/.config/atuin/config.toml. Sync stays off.
  Extra flag: --version=X.Y.Z pins the release instead of resolving the latest."

SOURCE_CONFIG="$MARCKV_DOTS_DIR/atuin/config.toml"
TARGET_CONFIG_DIR="$HOME/.config/atuin"
TARGET_CONFIG="$TARGET_CONFIG_DIR/config.toml"
ATUIN_DATA_DIR="$HOME/.local/share/atuin"

if [[ $EUID -eq 0 ]]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi
ATUIN_BIN="$INSTALL_DIR/atuin"

# Used when the GitHub API will not answer. Bump it when a release matters.
ATUIN_FALLBACK_VERSION="18.22.0"
ATUIN_VERSION=""   # empty = resolve the latest release

# Flags this installer adds on top of the shared ones.
installer_flag() {
    case "$1" in
        --version=*) ATUIN_VERSION="${1#*=}"; return 0 ;;
    esac
    return 1
}

config_is_ours() { [[ -L "$TARGET_CONFIG" && "$TARGET_CONFIG" -ef "$SOURCE_CONFIG" ]]; }

do_install() {
    [[ -f "$SOURCE_CONFIG" ]] || die "Not found: $SOURCE_CONFIG"

    local have_bin=false
    command -v atuin >/dev/null 2>&1 && have_bin=true

    preview_open "Install atuin"
    if [[ "$have_bin" == true ]]; then
        preview_line "binary" "already installed ($(atuin --version 2>/dev/null)) — unchanged"
    else
        preview_line "binary" "${ATUIN_BIN}  ${ATUIN_VERSION:+(v$ATUIN_VERSION)}"
        preview_line "from"   "github.com/atuinsh/atuin releases"
    fi
    if config_is_ours; then
        preview_line "config" "already linked — unchanged"
    else
        preview_line "symlink" "$TARGET_CONFIG -> $SOURCE_CONFIG"
        [[ -e "$TARGET_CONFIG" ]] && preview_line "backup" "${TARGET_CONFIG}.backup.<timestamp>"
    fi
    preview_line "sync" "disabled — history stays on this machine"
    preview_close

    confirm "Install atuin?" || { info "Cancelled."; return 0; }

    if [[ "$have_bin" == true ]]; then
        info "atuin already installed: $(atuin --version)"
    else
        local arch
        case "$(uname -m)" in
            x86_64)  arch="x86_64" ;;
            aarch64) arch="aarch64" ;;
            *) die "Unsupported architecture: $(uname -m)" ;;
        esac

        if [[ -z "$ATUIN_VERSION" ]]; then
            info "Resolving latest release..."
            # The response is captured before it is parsed: piping curl into
            # `grep -m1` closes the pipe early and curl then reports
            # "(23) Failure writing output to destination".
            #
            # `|| true` because the API is a convenience, not a dependency. It
            # rate-limits at 60/h unauthenticated, and with `set -e` the 403
            # killed the installer outright — a container that had already run
            # a few installs could not install atuin at all, with nothing but
            # "curl: (22)" to explain it. Same fallback shape as install-nvim.sh.
            local release_json=""
            release_json="$(curl -fsSL --max-time 10 https://api.github.com/repos/atuinsh/atuin/releases/latest || true)"
            ATUIN_VERSION="$(printf '%s' "$release_json" | grep -m1 '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')"
            if [[ -z "$ATUIN_VERSION" ]]; then
                warn "GitHub did not answer (rate limit, or no network)"
                info "Falling back to the pinned ${BOLD}v${ATUIN_FALLBACK_VERSION}${NC} — override with ${YELLOW}--version=X.Y.Z${NC}"
                ATUIN_VERSION="$ATUIN_FALLBACK_VERSION"
            fi
        fi

        local tmp_dir
        tmp_dir="$(mktemp -d)"
        trap 'rm -rf "$tmp_dir"' EXIT

        # gnu first, musl as the fallback — and which one works is measured, not
        # predicted. The gnu build is linked against whatever GLIBC the release
        # was built on (2.39 as of v18.22.0) and simply does not start on the
        # older distros this repo supports: on Debian 11 it installed, printed
        # "[OK] atuin installed:" with an empty version, and exited 0, because
        # the failing $(atuin --version) sits in a command substitution where
        # set -e does not reach. The musl build is static and starts anywhere.
        #
        # A GLIBC table would have to be re-checked on every atuin release.
        # Running the binary answers the same question and never goes stale.
        local flavour installed=false downloaded=false
        for flavour in gnu musl; do
            local tarball="atuin-${arch}-unknown-linux-${flavour}.tar.gz"
            local url="https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/${tarball}"

            info "Downloading atuin v${ATUIN_VERSION} (${arch}, ${flavour})..."
            rm -rf "${tmp_dir:?}"/atuin-*
            curl -fsSL -o "$tmp_dir/$tarball" "$url" || { warn "Download failed: $url"; continue; }
            downloaded=true
            tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir" || { warn "Could not unpack $tarball"; continue; }

            local staged
            staged="$(echo "$tmp_dir"/atuin-*/atuin)"
            if ! "$staged" --version >/dev/null 2>&1; then
                warn "The ${flavour} build does not run here ($("$staged" --version 2>&1 | head -1))"
                continue
            fi

            mkdir -p "$INSTALL_DIR"
            install -m 0755 "$staged" "$ATUIN_BIN"
            installed=true
            break
        done

        # Nothing is left behind on failure: a binary that cannot start is worse
        # than no binary, because $PATH finds it and the shell blames itself.
        # Two different failures, and saying the wrong one sends the user
        # hunting for a version when the real problem was the network — which
        # is exactly what a DNS blip during the distro matrix made it do.
        if [[ "$installed" != true ]]; then
            [[ "$downloaded" == true ]] \
                && die "No atuin build for v${ATUIN_VERSION} runs here — try ${BOLD}--version=X.Y.Z${NC}" \
                || die "Could not download atuin v${ATUIN_VERSION} — check the network and retry"
        fi
        success "atuin installed: $("$ATUIN_BIN" --version)"

        if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
            warn "$INSTALL_DIR is not in your PATH"
            echo -e "  Add it with: ${YELLOW}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
        fi
    fi

    mkdir -p "$TARGET_CONFIG_DIR"
    if config_is_ours; then
        info "Config already linked"
    else
        if [[ -e "$TARGET_CONFIG" || -L "$TARGET_CONFIG" ]]; then
            local backup="${TARGET_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$TARGET_CONFIG" "$backup"
            info "Backup: $backup"
        fi
        ln -s "$SOURCE_CONFIG" "$TARGET_CONFIG"
        success "Symlink created: $TARGET_CONFIG -> $SOURCE_CONFIG"
    fi

    grep -q "atuin.sh" "$MARCKV_DOTS_DIR/bash/.bashrc" 2>/dev/null \
        && success "Shell integration present in bash/.bashrc" \
        || warn "bash/.bashrc does not source bash/atuin.sh — update the repository"

    echo
    info "Reload the shell (${YELLOW}exec bash${NC}), then ${YELLOW}Ctrl+R${NC}"
    info "Import what you already have: ${YELLOW}atuin import auto${NC}"
}

do_status() {
    # Found on PATH is not the same as working. Before the install started
    # verifying this, a GLIBC-incompatible binary reported "[OK] atuin
    # installed:" with an empty version — status has to catch the ones already
    # put there by that older script, not just the ones it installs now.
    if command -v atuin >/dev/null 2>&1; then
        local version
        if version="$(atuin --version 2>&1)" && [[ -n "$version" ]]; then
            success "atuin installed: $version"
            preview_line "binary" "$(command -v atuin)"
        else
            error "atuin is at $(command -v atuin) but does not run"
            info "$(echo "$version" | head -1)"
            info "Reinstall it: ${BOLD}./${INSTALLER_NAME} install${NC}"
            return 1
        fi
    else
        warn "atuin not installed"
    fi
    config_is_ours && success "Config linked to $SOURCE_CONFIG" \
                   || { [[ -e "$TARGET_CONFIG" ]] && warn "Config exists but is not ours" \
                                                  || warn "Config not linked"; }
    [[ -d "$ATUIN_DATA_DIR" ]] && preview_line "history" "$ATUIN_DATA_DIR"
    # Explicit, and not decoration: a bare `[[ ... ]] && cmd` as the last line
    # of a function returns the TEST's status, so with no history directory
    # this reported a perfectly healthy install as rc=1.
    return 0
}

do_uninstall() {
    local removes_bin=false
    # Only a binary at OUR install path. atuin from apt, cargo or brew was not
    # put there by this script, and install() skips when it finds one — so
    # uninstall has no business deleting it either.
    [[ -f "$ATUIN_BIN" ]] && removes_bin=true

    if [[ "$removes_bin" == false ]] && ! config_is_ours; then
        warn "Nothing this installer put here — nothing to remove"
        command -v atuin >/dev/null 2>&1 && \
            info "atuin at $(command -v atuin) came from somewhere else, so it stays"
        return 0
    fi

    local restore=""
    restore="$(ls -1t "${TARGET_CONFIG}".backup.* 2>/dev/null | head -1 || true)"

    preview_open "Remove atuin"
    [[ "$removes_bin" == true ]] && preview_line "delete" "$ATUIN_BIN" \
                                 || preview_line "binary" "not ours — left alone"
    config_is_ours && preview_line "unlink" "$TARGET_CONFIG" \
                   || preview_line "config" "not ours — left alone"
    [[ -n "$restore" ]] && preview_line "restore" "$(basename "$restore")"
    # The history database is the whole point of having used atuin. It is not
    # created by this installer and it is never removed by it: years of
    # commands with no backup and no undo is not a side effect of uninstalling
    # a binary. Deleting it stays a decision someone makes on purpose.
    [[ -d "$ATUIN_DATA_DIR" ]] && preview_line "KEEPS" "$ATUIN_DATA_DIR  (your history — delete it yourself)"
    preview_close

    confirm "Remove atuin?" || { info "Cancelled."; return 0; }

    if [[ "$removes_bin" == true ]]; then
        _run rm -f "$ATUIN_BIN" && success "Removed $ATUIN_BIN"
    fi
    if config_is_ours; then
        rm -f "$TARGET_CONFIG"
        success "Symlink removed"
        if [[ -n "$restore" ]]; then
            mv "$restore" "$TARGET_CONFIG"
            success "Restored $(basename "$restore")"
        fi
    fi
    if [[ -d "$ATUIN_DATA_DIR" ]]; then
        echo
        info "Your history is still at ${BOLD}${ATUIN_DATA_DIR}${NC}"
        info "Remove it yourself with: ${YELLOW}rm -rf $ATUIN_DATA_DIR${NC}"
    fi
}

installer_main "$@"
