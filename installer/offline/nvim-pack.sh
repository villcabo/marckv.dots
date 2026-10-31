#!/bin/bash
#
# Builds the nvim-lite offline pack: everything nvim-lite would download, made
# here so a host with no internet only has to unpack it (nvim-unpack.sh).
#
# Runs on a machine with docker and internet. The pack is built inside
# ubuntu:22.04, by the repo's own installers — not by a second copy of their
# logic — because 22.04 has the oldest GLIBC (2.35) of the distros the pack is
# for: Ubuntu 22.04/24.04/26.04 and Debian 12/13. Parsers compiled there load
# on all of them, and every binary's GLIBC floor is checked with objdump before
# the pack is written, rather than assumed from the build distro: a binary an
# installer DOWNLOADS inside the container was never built there.
#
# What goes in, and where nvim-unpack.sh puts it — each is a place an installer
# or Neovim already looks, so no installer needs an offline mode:
#   nvim-<tag>-<archive>   -> /tmp cache of install-nvim.sh, then --version <tag>
#   share-nvim.tar.gz      -> ~/.local/share/nvim: lazy's plugins, compiled parsers
#   bin/fzf, bin/tree-sitter -> on PATH, where 04's deps step checks for them
#   MANIFEST               -> versions, and which nvim-lite the plugins match

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

INSTALLER_NAME="offline/nvim-pack.sh"
INSTALLER_ABOUT="Builds the nvim-lite offline pack (needs docker and internet)."

ref="main"
nvim_tag=""
out_dir="$HOME"
BUILD_IMAGE="ubuntu:22.04"
GLIBC_FLOOR="2.35"   # Ubuntu 22.04, the oldest distro the pack is for

_next=""
installer_flag() {
    if [[ -n "$_next" ]]; then
        printf -v "$_next" '%s' "$1"
        _next=""
        return 0
    fi
    case "$1" in
        --ref)  _next=ref ;;
        --nvim) _next=nvim_tag ;;
        -o)     _next=out_dir ;;
        *) return 1 ;;
    esac
    return 0
}

installer_usage() {
    bold "marckv.dots — ${INSTALLER_NAME}"
    echo
    echo -e "  ${INSTALLER_ABOUT}"
    echo
    echo -e "${BLUE}Usage:${NC} installer/offline/nvim-pack.sh [--ref main] [--nvim vX.Y.Z] [-o dir] [-y]"
    echo
    echo -e "  ${YELLOW}--ref${NC}    What to build the plugins for. Default: main — what the host"
    echo -e "           will have after cloning or updating from a bundle of main."
    echo -e "  ${YELLOW}--nvim${NC}   Neovim tag. Default: the one install-nvim.sh picks for GLIBC 2.35."
    echo -e "  ${YELLOW}-o${NC}       Where to write the pack. Default: \$HOME"
    echo -e "  ${YELLOW}-y${NC}       Skip the confirmation."
    echo
    echo -e "Then: ${BOLD}scp ~/marckv-nvim-<tag>.tgz <host>:${NC} and, there, once per user:"
    echo -e "      ${BOLD}~/.marckv.dots/installer/offline/nvim-unpack.sh ~/marckv-nvim-<tag>.tgz${NC}"
    echo
}

do_install() {
    command -v docker &>/dev/null || die "docker is required to build the pack"
    git -C "$MARCKV_DOTS_DIR" rev-parse --verify -q "$ref^{commit}" >/dev/null \
        || die "No such ref in the repo: $ref"

    local commit plugins_tree lite_version
    commit=$(git -C "$MARCKV_DOTS_DIR" rev-parse --short "$ref")
    plugins_tree=$(git -C "$MARCKV_DOTS_DIR" rev-parse "$ref:nvim-lite/lua")
    lite_version=$(git -C "$MARCKV_DOTS_DIR" show "$ref:nvim-lite/VERSION" | tr -d '[:space:]')
    mkdir -p "$out_dir"
    out_dir=$(cd "$out_dir" && pwd)

    preview_open "Build the nvim-lite offline pack"
    preview_line "from" "$ref ($commit), nvim-lite $lite_version"
    preview_line "neovim" "${nvim_tag:-what install-nvim.sh picks for GLIBC $GLIBC_FLOOR}"
    preview_line "built in" "$BUILD_IMAGE, a throwaway container (--rm)"
    preview_line "downloads" "Neovim, ~20 plugins, 24 parser sources, fzf, tree-sitter CLI"
    preview_line "writes" "$out_dir/marckv-nvim-<tag>.tgz (~90 MB)"
    preview_close
    confirm "Build it?" || { info "Cancelled."; return 0; }

    local work
    work=$(mktemp -d "${TMPDIR:-/tmp}/marckv-nvim-pack.XXXXXX")
    trap 'rm -rf "$work"' EXIT
    mkdir -p "$work/repo"
    git -C "$MARCKV_DOTS_DIR" archive "$ref" | tar -x -C "$work/repo"

    # The build runs as a file, not piped to `bash -s`: with stdin detached (a
    # background job, cron) a piped script reads nothing and exits 0.
    cat > "$work/build.sh" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq ca-certificates curl git binutils >/dev/null
cp -a /work/repo /root/.marckv.dots
cd /root/.marckv.dots/installer

# deps first: gcc, make, libc6-dev, ripgrep, fd, then fzf and the tree-sitter
# CLI into /usr/local/bin — the same step a host with internet runs.
./04-install-nvim-lite.sh -d -y </dev/null
tag="${NVIM_TAG:-$(./install-nvim.sh --print-target 2>/dev/null | tail -n1)}"
./install-nvim.sh --version "$tag" -y </dev/null
export PATH="/opt/nvim/bin:$PATH"
./04-install-nvim-lite.sh -y </dev/null
./04-install-nvim-lite.sh -s -y </dev/null

archive=$(basename "$(ls /tmp/nvim-"$tag"-*.tar.gz)")
mkdir -p /out/pack/bin
cp "/tmp/$archive" /out/pack/
cp /usr/local/bin/fzf /usr/local/bin/tree-sitter /out/pack/bin/
tar -czf /out/pack/share-nvim.tar.gz -C /root/.local/share nvim

# Every binary's GLIBC floor, measured. The highest is what the pack needs.
floor=$( { objdump -T /opt/nvim/bin/nvim /out/pack/bin/* /root/.local/share/nvim/site/parser/*.so 2>/dev/null \
    | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//'; echo 2.2.5; } | sort -V | tail -n1)
parsers=$(ls /root/.local/share/nvim/site/parser/*.so | wc -l)
{
    echo "NVIM_TAG=$tag"
    echo "NVIM_ARCHIVE=$archive"
    echo "GLIBC_NEEDED=$floor"
    echo "PARSERS=$parsers"
    echo "FZF=$(fzf --version | cut -d' ' -f1)"
    echo "TREE_SITTER=$(tree-sitter --version | cut -d' ' -f2)"
} > /out/pack/MANIFEST.build
chown -R "$HOST_UID:$HOST_GID" /out
EOF

    info "Building in $BUILD_IMAGE — a few minutes, most of it downloads"
    docker run --rm --restart no -e NVIM_TAG="$nvim_tag" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
        -v "$work:/work:ro" -v "$work:/out" "$BUILD_IMAGE" bash /work/build.sh \
        || die "The build failed — see the output above"

    local pack="$work/pack" tag glibc
    tag=$(sed -n 's/^NVIM_TAG=//p' "$pack/MANIFEST.build")
    glibc=$(sed -n 's/^GLIBC_NEEDED=//p' "$pack/MANIFEST.build")
    if [[ "$(printf '%s\n%s\n' "$glibc" "$GLIBC_FLOOR" | sort -V | tail -n1)" != "$GLIBC_FLOOR" ]]; then
        die "Something in the pack needs GLIBC $glibc, newer than Ubuntu 22.04's $GLIBC_FLOOR — not written"
    fi
    {
        cat "$pack/MANIFEST.build"
        echo "REPO_REF=$ref"
        echo "REPO_COMMIT=$commit"
        echo "NVIM_LITE_VERSION=$lite_version"
        echo "NVIM_LITE_LUA_TREE=$plugins_tree"
        echo "BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$pack/MANIFEST"
    rm -f "$pack/MANIFEST.build"

    local file="$out_dir/marckv-nvim-${tag}.tgz"
    tar -czf "$file" -C "$work" pack
    echo
    success "Pack written: $file ($(du -h "$file" | cut -f1))"
    sed 's/^/  /' "$pack/MANIFEST"
    echo
    info "On the host, once per user (root first):"
    echo -e "  ${BOLD}~/.marckv.dots/installer/offline/nvim-unpack.sh ~/$(basename "$file")${NC}"
}

do_status() { installer_usage; }
do_uninstall() { info "Nothing to uninstall: the pack is a file. Delete it when you no longer need it."; }

installer_main "$@"
