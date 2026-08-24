#!/bin/bash

# Script to install Neovim system-wide
# Requires root/sudo

set -e

# An installer that writes to /opt and /etc/profile.d serves the WHOLE system,
# so the umask of whoever runs it must not decide who may use what it installs
# — and it did. Neovim's tarball carries no entry for its own top-level
# directory, so tar has to create that one itself, and creates it with the
# umask in effect. Under this repo's own `umask 027` (bash/environment.sh) that
# is 0750: root can enter /opt/nvim and nobody else can, so every other user
# gets "command not found" while $PATH points straight at it.
umask 022

# Colors — tput when the terminal supports it, ANSI otherwise.
#
# The guard is not cosmetic. These were bare `$(tput …)` assignments, and with
# `set -e` a tput that fails takes the whole script with it: with no $TERM,
# tput exits 2 and the installer died on line 9, before printing anything but
# "No value for $TERM and no -T specified". That is every non-interactive
# context — cron, CI, `ssh host './install-nvim.sh'`, `docker exec -T` — so the
# script could not be tested in a container at all. Same shape as bash/colors.sh.
if tput setaf 1 &> /dev/null; then
    GREEN=$(tput setaf 114)
    ORANGE=$(tput setaf 208)
    BLUE=$(tput setaf 75)
    YELLOW=$(tput setaf 221)
    RED=$(tput setaf 196)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    GREEN='\033[0;32m'
    ORANGE='\033[0;33m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
fi

# Paths
NVIM_PATH="/opt/nvim"
PROFILE_PATH="/etc/profile.d/nvim.sh"

# Version to install (empty = latest). Can be set via --version flag.
NVIM_VERSION=""

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

die() { error "$1"; exit 1; }

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            bold "marckv.dots Neovim installer"
            echo ""
            echo -e "Installs Neovim system-wide to ${ORANGE}$NVIM_PATH${NC}."
            echo -e "Requires ${ORANGE}root/sudo${NC}."
            echo ""
            echo -e "${BLUE}Usage:${NC} sudo $0 [--version <tag>]"
            echo ""
            echo -e "${BLUE}Flags:${NC}"
            echo -e "  ${YELLOW}--version <tag>${NC}   Install a specific version (e.g. v0.10.3)"
            echo -e "  ${YELLOW}--ls-remote${NC}       List installable versions with distro compatibility"
            echo -e "  ${YELLOW}-h, --help${NC}        Show this help"
            echo ""
            echo -e "${BLUE}GLIBC:${NC}"
            echo -e "  Neovim's prebuilt binaries need a recent GLIBC, and the older"
            echo -e "  distros this repo supports do not have one. With no ${YELLOW}--version${NC},"
            echo -e "  the newest release this system can actually run is chosen:"
            echo ""
            echo -e "    ${ORANGE}GLIBC 2.34+${NC} ${BOLD}→${NC} latest      ${ORANGE}(Debian 12+, Ubuntu 22.04+)${NC}"
            echo -e "    ${ORANGE}GLIBC 2.31+${NC} ${BOLD}→${NC} v0.10.3    ${ORANGE}(Debian 11, Ubuntu 20.04)${NC}"
            echo -e "    ${ORANGE}older${NC}       ${BOLD}→${NC} v0.9.5"
            echo ""
            echo -e "  ${YELLOW}--version${NC} overrides that. Whatever is chosen, the binary is run"
            echo -e "  before anything is installed: if it cannot start, the install is"
            echo -e "  abandoned and the working one is left untouched."
            echo ""
            exit 0
            ;;
        --version)
            NVIM_VERSION="$2"
            [[ -z "$NVIM_VERSION" ]] && die "--version requires a tag argument (e.g. v0.10.3)"
            shift 2
            ;;
        --ls-remote)
            LS_REMOTE=true
            shift
            ;;
        *)
            error "Unknown argument: $1"
            info "Run with ${BOLD}--help${NC} for usage"
            exit 1
            ;;
    esac
done

# Build URLs based on version selection
# Older versions (<= v0.10.3) use nvim-linux64.tar.gz
# Newer versions (>= v0.10.4) use nvim-linux-x86_64.tar.gz
build_urls() {
    local version="$1"
    local archive_name

    if [[ -z "$version" ]]; then
        # Latest release — use new naming
        archive_name="nvim-linux-x86_64.tar.gz"
        NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${archive_name}"
    else
        # Specific version — determine archive name by version
        local ver="${version#v}"
        local major minor patch
        IFS='.' read -r major minor patch <<< "$ver"
        # v0.10.3 and older use nvim-linux64.tar.gz
        if [[ "$major" -eq 0 && "$minor" -le 10 && "$patch" -le 3 ]] || [[ "$major" -eq 0 && "$minor" -lt 10 ]]; then
            archive_name="nvim-linux64.tar.gz"
        else
            archive_name="nvim-linux-x86_64.tar.gz"
        fi
        NVIM_URL="https://github.com/neovim/neovim/releases/download/${version}/${archive_name}"
    fi
    # The tag belongs in the cache path. Every release from v0.10.4 onward
    # ships under the SAME archive name, so keying the cache on the file name
    # alone made one stale download stand in for any version asked for later —
    # and the script still reported the version it had been asked for.
    NVIM_TAR="/tmp/nvim-${version:-latest}-${archive_name}"
    NVIM_ARCHIVE_DIR="${archive_name%.tar.gz}"
}

# Map a version tag to distro compatibility string.
# Based on the GLIBC requirement of Neovim's prebuilt binaries:
#   v0.10.4+  → GLIBC 2.34+ (Debian 12+, Ubuntu 22.04+)
#   v0.10.0-3 → GLIBC 2.31+ (Debian 11+, Ubuntu 20.04+)
#   v0.9.x-   → GLIBC 2.17+ (Debian 10+, Ubuntu 18.04+)
version_compat() {
    local ver="${1#v}"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    if [[ "$major" -ge 1 ]] || [[ "$major" -eq 0 && "$minor" -ge 11 ]]; then
        echo "Debian 12+, Ubuntu 22.04+"
    elif [[ "$major" -eq 0 && "$minor" -eq 10 ]]; then
        if [[ "${patch:-0}" -ge 4 ]]; then
            echo "Debian 12+, Ubuntu 22.04+"
        else
            echo "Debian 11+, Ubuntu 20.04+"
        fi
    else
        echo "Debian 10+, Ubuntu 18.04+"
    fi
}

# List installable Neovim versions with distro compatibility
list_remote_versions() {
    bold "=== Available Neovim versions ==="
    echo ""
    info "Fetching releases from GitHub API..."
    echo ""

    local releases
    releases=$(curl -sf "https://api.github.com/repos/neovim/neovim/releases?per_page=20") \
        || die "Failed to fetch releases from GitHub"

    local tags
    tags=$(echo "$releases" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | grep -v 'nightly')

    printf "  ${BOLD}%-12s${NC}  ${BOLD}%s${NC}\n" "VERSION" "SUPPORTED DISTROS"
    printf "  %-12s  %s\n" "-------" "-----------------"

    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        local compat
        compat=$(version_compat "$tag")
        printf "  ${YELLOW}%-12s${NC}  %s\n" "$tag" "$compat"
    done <<< "$tags"

    echo ""
    info "Install with: ${BOLD}sudo $0 --version <tag>${NC}"
    echo ""
    exit 0
}

# Handle --ls-remote before root check (listing doesn't need root)
[[ "${LS_REMOTE:-false}" == true ]] && list_remote_versions

# Verify root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    info "Usage: ${BOLD}sudo $0${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Repair
#
# Two things an earlier copy of this script left behind that installing again
# does not undo on its own, so they are corrected on every run.
# ---------------------------------------------------------------------------
repair_existing_install() {
    local repaired=false mode other f

    # 1. An install only root can reach. The mode came from the installing
    #    shell's umask, so it is already wrong on the machine it was installed
    #    on, and stays wrong until somebody notices that $PATH points at a
    #    directory they are not allowed to enter. Nothing about reinstalling
    #    fixes it, because the top-level directory is recreated the same way.
    if [ -d "$NVIM_PATH" ]; then
        mode=$(stat -c '%a' "$NVIM_PATH" 2>/dev/null || echo "")
        other="${mode: -1}"
        if [ -n "$mode" ] && [ "$(( other & 5 ))" -ne 5 ]; then
            warn "Existing install is unreachable by other users (mode $mode)"
            chmod -R go+rX "$NVIM_PATH"
            success "Permissions repaired: $NVIM_PATH is now $(stat -c '%a' "$NVIM_PATH")"
            repaired=true
        fi
    fi

    # 2. Cache files from before the version tag was part of the name. Nothing
    #    reads them any more, but an older copy of this script would still
    #    happily install one of them as whatever version it was asked for.
    for f in /tmp/nvim-linux64.tar.gz /tmp/nvim-linux-x86_64.tar.gz; do
        if [ -f "$f" ]; then
            info "Removing stale unversioned cache: $f ($(du -h "$f" | cut -f1))"
            rm -f "$f"
            repaired=true
        fi
    done

    [ "$repaired" = true ] && echo ""
    return 0
}

bold "=== Neovim installer ==="
repair_existing_install
build_urls "$NVIM_VERSION"
[[ -n "$NVIM_VERSION" ]] && info "Requested version: ${BOLD}$NVIM_VERSION${NC}"

# Get the latest Neovim release tag
get_latest_version() {
    curl -s https://api.github.com/repos/neovim/neovim/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Get currently installed version
get_installed_version() {
    [ -x "$NVIM_PATH/bin/nvim" ] && \
        $NVIM_PATH/bin/nvim --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+'
}

# Compare version strings
compare_versions() {
    local installed="$1" latest="$2"
    local ic lc higher
    ic=$(echo "$installed" | sed 's/^v//')
    lc=$(echo "$latest" | sed 's/^v//')
    higher=$(printf '%s\n%s\n' "$ic" "$lc" | sort -V | tail -n1)
    [ "$higher" = "$lc" ] && [ "$ic" != "$lc" ]
}

# GLIBC of the running system, e.g. 2.31
system_glibc() {
    ldd --version 2>/dev/null | head -n1 | awk '{print $NF}'
}

# Newest release known to run against a given GLIBC. Empty means "latest".
#
# This only picks a DEFAULT, and it is a table, so it will rot — every Neovim
# release can raise the floor. Nothing depends on it being right: the binary is
# run before anything is installed, so a stale table costs a clear message and
# no damage. Its job is to make the common case on an older server work without
# the user having to know any of this.
default_version_for_glibc() {
    local major minor
    IFS='.' read -r major minor <<< "$1"
    major="${major:-0}"; minor="${minor:-0}"
    if [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 34 ]; }; then
        echo ""                 # latest is fine
    elif [ "$major" -eq 2 ] && [ "$minor" -ge 31 ]; then
        echo "v0.10.3"          # last release built against GLIBC 2.31
    else
        echo "v0.9.5"
    fi
}

# Determine target version
if [[ -n "$NVIM_VERSION" ]]; then
    target_version="$NVIM_VERSION"
else
    glibc=$(system_glibc)
    pinned=$(default_version_for_glibc "$glibc")
    if [[ -n "$pinned" ]]; then
        # Also spares the GitHub API call on exactly the machines least likely
        # to want a surprise.
        target_version="$pinned"
        info "GLIBC ${BOLD}$glibc${NC} — installing ${BOLD}$target_version${NC}, the newest release this system can run"
        info "Override with ${BOLD}--version <tag>${NC} if you know better"
    else
        info "Fetching latest release from GitHub..."
        target_version=$(get_latest_version)
        [[ -z "$target_version" ]] && die "Failed to fetch latest version from GitHub"
    fi
fi

# Rebuild URLs now that we know the target version
build_urls "$target_version"

# Detect currently installed version (if any)
installed_version=""
if [ -d "$NVIM_PATH" ] && [ -f "$PROFILE_PATH" ]; then
    installed_version=$(get_installed_version)
fi

# Short-circuit if already on target version (unless user forced --version)
if [[ -z "$NVIM_VERSION" && -n "$installed_version" && "$installed_version" == "$target_version" ]]; then
    success "✅ Already on the latest version ($installed_version)"
    exit 0
fi

# Preview
echo ""
bold "=== INSTALLATION PREVIEW ==="
echo -e "${BLUE}Target version:${NC}       ${YELLOW}${BOLD}$target_version${NC}"
if [[ -n "$installed_version" ]]; then
    echo -e "${BLUE}Currently installed:${NC}  ${ORANGE}$installed_version${NC}"
else
    echo -e "${BLUE}Currently installed:${NC}  ${ORANGE}none${NC}"
fi
echo -e "${BLUE}Supported distros:${NC}    $(version_compat "$target_version")"
echo -e "${BLUE}Install path:${NC}         ${ORANGE}$NVIM_PATH${NC}"
echo -e "${BLUE}Profile script:${NC}       ${ORANGE}$PROFILE_PATH${NC}"
echo -e "${BLUE}Download URL:${NC}         ${ORANGE}$NVIM_URL${NC}"
echo ""

read -p "Type '${YELLOW}${BOLD}yes${NC}' to confirm installation: " -r
echo
if [[ "$REPLY" != "yes" ]]; then
    info "Cancelled."
    exit 0
fi

echo ""

# Download
if [ -f "$NVIM_TAR" ] && [ -s "$NVIM_TAR" ]; then
    info "Using cached archive: $NVIM_TAR"
else
    info "Downloading Neovim from GitHub..."
    curl -L -o "$NVIM_TAR" "$NVIM_URL" || die "Failed to download Neovim"
fi

# Extract into a staging directory NEXT TO the destination
#
# Not into /tmp: the move that follows is only atomic while both ends live on
# the same filesystem, and /tmp is a separate one often enough to matter.
#
# Staging at all, because the previous version used to be deleted here, before
# anything had checked that the new one runs. On a host whose GLIBC is too old
# for the release being installed, that traded a working editor for a broken
# one — the exact case this repo targets, since Debian 11 and Ubuntu 20.04 are
# supported and both sit on GLIBC 2.31.
stage="/opt/.nvim-stage.$$"
trap 'rm -rf "$stage"' EXIT INT TERM
rm -rf "$stage"
mkdir -p "$stage"

info "Extracting..."
# --strip-components=1 drops the archive's own top-level directory, whose name
# changes between releases; it is also the directory tar would otherwise have
# to invent, and inventing it is what produced the unreachable install.
tar -C "$stage" --strip-components=1 -xzf "$NVIM_TAR" || die "Failed to extract Neovim"
[ -f "$stage/bin/nvim" ] || die "Unexpected archive structure: no bin/nvim inside $NVIM_TAR"

# Explicit, not inherited. umask 022 above already gets this right; saying it
# out loud means a future change to the umask cannot quietly take nvim away
# from every non-root user again.
chmod 755 "$stage"

# Verify by RUNNING it
#
# The check here used to be `[ -x .../nvim ]`, which asks whether a bit is set.
# A binary that cannot resolve its GLIBC symbols has that bit set and fails
# anyway. The real check ran later, as
#     version=$(... nvim --version | head -n1)
# where the exit status belongs to `head` — so it was 0 no matter what nvim
# did, `set -e` saw nothing, and the installer announced success over a binary
# that could not start.
if ! "$stage/bin/nvim" --version >/dev/null 2>&1; then
    reason=$("$stage/bin/nvim" --version 2>&1 | head -n 3)
    error "$target_version cannot run on this system:"
    printf '  %s\n' "$reason"
    echo ""
    if [ -n "$installed_version" ]; then
        info "Nothing was changed — ${BOLD}$installed_version${NC} is still installed and working"
    else
        info "Nothing was installed"
    fi
    glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    [ -n "$glibc" ] && info "This system has GLIBC ${BOLD}$glibc${NC}"
    info "Try: ${BOLD}sudo $0 --version v0.10.3${NC}"
    exit 1
fi

# Only now is the working installation touched. Both paths are on the same
# filesystem, so each move is a rename.
info "Installing to $NVIM_PATH..."
rm -rf "$NVIM_PATH.prev"
[ -d "$NVIM_PATH" ] && mv "$NVIM_PATH" "$NVIM_PATH.prev"
mv "$stage" "$NVIM_PATH"
trap - EXIT INT TERM
rm -rf "$NVIM_PATH.prev"
[ -d "/opt/nvim-linux-x86_64" ] && rm -rf "/opt/nvim-linux-x86_64"
[ -d "/opt/nvim-linux64" ] && rm -rf "/opt/nvim-linux64"

# Configure PATH
echo "export PATH=\"\$PATH:$NVIM_PATH/bin\"" > "$PROFILE_PATH"
chmod 644 "$PROFILE_PATH"

success "Neovim installed: $("$NVIM_PATH/bin/nvim" --version | head -n1)"
info "Location: $NVIM_PATH/bin/nvim"

echo ""
info "To use Neovim in new terminal sessions:"
echo -e "  ${YELLOW}${BOLD}1.${NC} Environment variables are already configured globally"
echo -e "  ${YELLOW}${BOLD}2.${NC} Restart your terminal, or run: ${YELLOW}${BOLD}source $PROFILE_PATH${NC}"
echo -e "  ${YELLOW}${BOLD}3.${NC} Verify with: ${YELLOW}${BOLD}nvim --version${NC}"
echo ""
success "Installation complete!"
