#!/bin/bash
# marckv — one command to look after this repo on a server.
#
# A function and not a script in bash/bin: update, reload and cd act on the
# shell you are in, and a child process cannot touch its parent.

_MARCKV_PIECES="bash docker tmux nvim vim atuin"

marckv() {
    local sub="$1"
    [[ $# -gt 0 ]] && shift

    case "$sub" in
        update)          _marckv_update "$@" ;;
        reload)          _marckv_reload ;;
        help)            _marckv_help "$@" ;;
        cd)              cd "$MARCKV_DOTS_DIR" || return 1 ;;
        status)          _marckv_status ;;
        version)         _marckv_version ;;
        whatsnew)        _marckv_whatsnew ;;
        install)         _marckv_install "$@" ;;
        doctor)          _marckv_doctor ;;
        ""|-h|--help)    _marckv_usage ;;
        *)
            echo -e "${RED}error:${RESET} unknown command '$sub'" >&2
            _marckv_usage >&2
            return 1
            ;;
    esac
}

_marckv_usage() {
    local G="${GREEN}${BOLD}" Y="$YELLOW" RE="$RESET"
    echo -e "\n  ${BOLD}marckv${RE} — manage marckv.dots ($MARCKV_DOTS_DIR)\n"
    printf "  ${G}%-26s${RE}%s\n" \
        "marckv update"            "Pull the repo; reload bash if anything changed" \
        "marckv update --from <f>" "The same, offline, from a git bundle" \
        "  ... --no-verify"         "Skip the signature check (it is on by default)" \
        "marckv reload"            "Reload the bash config in this shell" \
        "marckv help [category]"   "Command reference for this bash setup" \
        "marckv cd"                "Go to the repo" \
        "marckv status"            "Repo state and what each installer reports" \
        "marckv version"           "Commit, date and nvim-lite version" \
        "marckv whatsnew"          "What the last update brought" \
        "marckv install [piece]"   "Run the installer: all, or one of: ${_MARCKV_PIECES// /, }" \
        "marckv doctor"            "Check the tools and settings this setup relies on"
    echo -e "\n  ${Y}↳${RE} marckv install nvim --full    flags after the piece go to its installer\n"
}

_marckv_git() { git -C "$MARCKV_DOTS_DIR" "$@"; }

# Where the last update that brought something started from. Kept by update
# itself rather than read from ORIG_HEAD: on git 2.25 and 2.30 (Ubuntu 20.04,
# Debian 11) a pull --ff-only that refuses still moves ORIG_HEAD; 2.34 does
# not. Inside .git, so it is never tracked.
_marckv_mark() { echo "$(_marckv_git rev-parse --absolute-git-dir)/marckv-last-update"; }

_marckv_is_repo() {
    if [[ ! -d "$MARCKV_DOTS_DIR/.git" ]]; then
        echo -e "${RED}error:${RESET} $MARCKV_DOTS_DIR is not a git repository" >&2
        return 1
    fi
}

# ~/.config/nvim as a real directory carrying nvim-lite's VERSION is a copy
# (04 --copy): a pull never reaches it.
_marckv_nvim_is_copy() {
    [[ -d "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" && -f "$HOME/.config/nvim/VERSION" ]]
}

# Same for vim-lite: ~/.vim as a real directory that 06 --copy made.
_marckv_vim_is_copy() {
    [[ -d "$HOME/.vim" && ! -L "$HOME/.vim" && -f "$HOME/.vim/plugin/lite.vim" ]]
}

# Every commit an update brings must be signed by a key this copy already
# trusts — keys/ as it is BEFORE the update, so a commit that adds a key is
# checked against the old ones and refused. A plain commit needs the owner's
# key (keys/marckv.asc); only a merge may also carry GitHub's (keys/github-
# web-flow.asc), which is what "Merge pull request" commits are signed with.
# Not GitHub's for anything else: someone holding the account who edits a
# file on the web gets a commit GitHub signs, and that is exactly the one to
# stop.
#
# Checked in a throwaway GNUPGHOME, so the host's own keyring is neither read
# nor written. The keys are imported, not trusted — `U`, a good signature from
# a key of unknown validity, is accepted when its fingerprint is in keys/.
_marckv_verify() {  # <from> <to>
    local keys="$MARCKV_DOTS_DIR/keys" home mine github allowed sha st fp parents bad="" n=0

    if ! command -v gpg >/dev/null 2>&1; then
        echo -e "${RED}error:${RESET} gpg is not installed, so the update cannot be verified" >&2
        return 1
    fi
    if [[ ! -f "$keys/marckv.asc" ]]; then
        echo -e "${RED}error:${RESET} no trusted key in this copy ($keys/marckv.asc)" >&2
        return 1
    fi
    # Everything gpg does here happens in a throwaway home: without one even
    # --show-keys creates ~/.gnupg in the account being updated.
    home=$(mktemp -d) || return 1
    mine=$(GNUPGHOME="$home" gpg --batch --with-colons --show-keys "$keys/marckv.asc" 2>/dev/null | awk -F: '$1=="fpr"{print $10}')
    github=$(GNUPGHOME="$home" gpg --batch --with-colons --show-keys "$keys/github-web-flow.asc" 2>/dev/null | awk -F: '$1=="fpr"{print $10}')
    GNUPGHOME="$home" gpg --batch --quiet --import "$keys"/*.asc >/dev/null 2>&1

    while IFS=$'\t' read -r sha st fp parents; do
        n=$((n + 1))
        allowed="$mine"
        [[ "$parents" == *" "* ]] && allowed="$mine"$'\n'"$github"
        if [[ "$st" != G && "$st" != U ]] || ! grep -qx "$fp" <<< "$allowed"; then
            bad+="  ${sha:0:9} $(_marckv_git log -1 --format='%s' "$sha" | cut -c1-60)  [signature: $st${fp:+ ${fp: -16}}]"$'\n'
        fi
    # Tab-separated: an empty field (no signature, so no fingerprint) must not
    # shift the parents into its place. %GP is the primary key behind a
    # subkey signature; %GF when the primary signed directly.
    done < <(GNUPGHOME="$home" git -C "$MARCKV_DOTS_DIR" log --format='%H%x09%G?%x09%GP%x09%GF%x09%P' "$1..$2" 2>/dev/null \
        | awk -F'\t' -v OFS='\t' '{ print $1, $2, ($3 != "" ? $3 : ($4 != "" ? $4 : "-")), $5 }')
    rm -rf "$home"

    if [[ -n "$bad" ]]; then
        echo -e "${RED}error:${RESET} not signed by a trusted key — nothing was changed:" >&2
        printf '%s' "$bad" >&2
        return 1
    fi
    [[ $n -gt 0 ]] && echo "Verified: $n new commit(s), all signed by a trusted key."
    return 0
}

_marckv_update() {
    _marckv_is_repo || return 1
    local before after target bundle="" verify=true

    # --from <file>: a host with no internet updates from a git bundle made
    # on a machine that has one —  git bundle create marckv.bundle main
    # Everything after the fetch is the same as an update from GitHub.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from)
                bundle=$(readlink -f "${2:-}" 2>/dev/null)
                if [[ -z "${2:-}" || ! -f "$bundle" ]]; then
                    echo -e "${RED}error:${RESET} --from needs a bundle file: marckv update --from ~/marckv.bundle" >&2
                    return 1
                fi
                # A full bundle has no prerequisites; an incremental one that
                # needs commits this repo lacks is rejected here.
                if ! _marckv_git bundle verify "$bundle" >/dev/null 2>&1; then
                    echo -e "${RED}error:${RESET} $bundle is not a bundle this repo can use" >&2
                    _marckv_git bundle verify "$bundle" 2>&1 | sed 's/^/       /' >&2
                    return 1
                fi
                shift 2
                ;;
            --no-verify) verify=false; shift ;;
            *)
                echo -e "${RED}error:${RESET} usage: marckv update [--from <bundle>] [--no-verify]" >&2
                return 1
                ;;
        esac
    done

    before=$(_marckv_git rev-parse HEAD) || return 1
    echo "Updating marckv.dots ($MARCKV_DOTS_DIR)${bundle:+ from $bundle}..."

    # Fetch, verify, then move: nothing in the working tree changes until
    # every new commit has passed.
    if [[ -n "$bundle" ]]; then
        _marckv_git fetch -q "$bundle" main || { echo -e "${RED}Update failed.${RESET}" >&2; return 1; }
        target=$(_marckv_git rev-parse FETCH_HEAD)
    else
        _marckv_git fetch -q || { echo -e "${RED}Update failed.${RESET} Check the error above." >&2; return 1; }
        target=$(_marckv_git rev-parse '@{upstream}') || return 1
    fi

    if [[ "$verify" == true ]]; then
        _marckv_verify "$before" "$target" || return 1
    else
        echo -e "${YELLOW}[WARN]${RESET} --no-verify: taking these commits without checking who signed them."
    fi

    # --ff-only: a server only follows origin. A local commit there should
    # stop the update, not be merged into a commit nobody pushes.
    if ! _marckv_git merge --ff-only -q "$target"; then
        echo -e "${RED}Update failed.${RESET} Check the error above." >&2
        return 1
    fi
    # The bundle IS origin's main as of when it was made, so origin/main moves
    # with it. Left behind, whatsnew counted the new commits as local ones and
    # reported nothing, and status called them unpushed.
    [[ -n "$bundle" ]] && _marckv_git update-ref refs/remotes/origin/main "$target"
    after=$(_marckv_git rev-parse HEAD)

    # Compared by commit, not by git's "Already up to date": that text is
    # translated, and with git in Spanish it never matched.
    if [[ "$before" == "$after" ]]; then
        echo "Already up to date. No reload needed."
        return 0
    fi

    echo "$before" > "$(_marckv_mark)"
    echo
    _marckv_git --no-pager log --format='  %h %s' "$before..$after"
    echo

    if _marckv_nvim_is_copy && ! _marckv_git diff --quiet "$before" "$after" -- nvim-lite; then
        echo -e "${YELLOW}[WARN]${RESET} nvim-lite changed, and ~/.config/nvim is a copy the pull did not touch."
        echo -e "       To bring it up to date: ${BOLD}marckv install nvim --copy${RESET}"
        echo
    fi
    # nvim-lite installed from an offline pack: its plugins were built for one
    # nvim-lite. A config that now wants others makes lazy try to clone them,
    # on every start, with no network to do it.
    local pack="$HOME/.local/share/nvim/marckv-pack.manifest" built_for now_lua
    if [[ -f "$pack" ]]; then
        built_for=$(sed -n 's/^NVIM_LITE_LUA_TREE=//p' "$pack")
        now_lua=$(_marckv_git rev-parse "$after:nvim-lite/lua" 2>/dev/null)
        if [[ -n "$built_for" && "$built_for" != "$now_lua" ]]; then
            echo -e "${YELLOW}[WARN]${RESET} nvim-lite changed since its offline pack was built."
            echo -e "       Rebuild it on a machine with internet (${BOLD}installer/offline/nvim-pack.sh${RESET})"
            echo -e "       and unpack it here (${BOLD}installer/offline/nvim-unpack.sh${RESET})."
            echo
        fi
    fi
    if _marckv_vim_is_copy && ! _marckv_git diff --quiet "$before" "$after" -- vim; then
        echo -e "${YELLOW}[WARN]${RESET} vim-lite changed, and ~/.vim is a copy the pull did not touch."
        echo -e "       To bring it up to date: ${BOLD}marckv install vim --copy${RESET}"
        echo
    fi

    _marckv_reload
}

_marckv_reload() {
    # Not chained with &&: .bashrc ends in a loop whose last test is usually
    # false (no /etc/profile.d/go.sh), so its status is 1 on a good reload.
    # A real error prints its own message.
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
    echo "Bash configuration reloaded."
}

_marckv_version() {
    _marckv_is_repo || return 1
    local repo_v="" inst_v="" mode

    printf "  %-12s %s\n" "marckv.dots" \
        "$(_marckv_git --no-pager log -1 --format='%h  %cs  %s')"
    printf "  %-12s %s\n" "branch" "$(_marckv_git rev-parse --abbrev-ref HEAD)"

    [[ -f "$MARCKV_DOTS_DIR/nvim-lite/VERSION" ]] && repo_v=$(<"$MARCKV_DOTS_DIR/nvim-lite/VERSION")
    if [[ -L "$HOME/.config/nvim" ]]; then
        mode="symlink"
    elif _marckv_nvim_is_copy; then
        mode="copy"
        inst_v=$(<"$HOME/.config/nvim/VERSION")
    fi

    if [[ -z "$mode" ]]; then
        printf "  %-12s %s\n" "nvim-lite" "${repo_v:-?} in the repo, not installed"
    elif [[ "$mode" == copy && "$inst_v" != "$repo_v" ]]; then
        # %b: colors.sh's fallback colours are '\033' text, not escape bytes.
        printf "  %-12s %b\n" "nvim-lite" \
            "${repo_v:-?} in the repo, ${YELLOW}${inst_v} installed (copy)${RESET} — marckv install nvim --copy"
    else
        printf "  %-12s %s\n" "nvim-lite" "${repo_v:-?} ($mode)"
    fi

    repo_v="" mode=""
    [[ -f "$MARCKV_DOTS_DIR/vim/VERSION" ]] && repo_v=$(<"$MARCKV_DOTS_DIR/vim/VERSION")
    if [[ -L "$HOME/.vim" && "$HOME/.vim" -ef "$MARCKV_DOTS_DIR/vim" ]]; then
        printf "  %-12s %s\n" "vim-lite" "${repo_v:-?} (symlink)"
    elif _marckv_vim_is_copy; then
        inst_v=$(<"$HOME/.vim/VERSION")
        if [[ "$inst_v" != "$repo_v" ]]; then
            printf "  %-12s %b\n" "vim-lite" \
                "${repo_v:-?} in the repo, ${YELLOW}${inst_v} installed (copy)${RESET} — marckv install vim --copy"
        else
            printf "  %-12s %s\n" "vim-lite" "${repo_v:-?} (copy)"
        fi
    else
        printf "  %-12s %s\n" "vim-lite" "${repo_v:-?} in the repo, not installed"
    fi
}

_marckv_whatsnew() {
    _marckv_is_repo || return 1
    local tip=HEAD base from mark

    mark=$(_marckv_mark)
    [[ -f "$mark" ]] && from=$(<"$mark")
    if [[ -z "$from" ]] || ! _marckv_git rev-parse -q --verify "$from^{commit}" >/dev/null; then
        echo "No update recorded yet."
        return 0
    fi
    # Stop where HEAD meets origin, so a commit made on the server is not
    # reported as something the update brought.
    base=$(_marckv_git merge-base HEAD '@{upstream}' 2>/dev/null) && tip=$base
    if [[ -z "$(_marckv_git rev-list "$from..$tip")" ]]; then
        echo "The last update brought nothing new."
        return 0
    fi
    echo "The last update brought:"
    _marckv_git --no-pager log --format='  %h  %cs  %s' "$from..$tip"
}

_marckv_status() {
    _marckv_is_repo || return 1
    local branch upstream counts behind ahead changes fetched=yes

    branch=$(_marckv_git rev-parse --abbrev-ref HEAD)
    echo -e "${BOLD}━━━ repo ━━━${RESET}"
    printf "  %-10s %s\n" "path" "$MARCKV_DOTS_DIR"
    printf "  %-10s %s\n" "commit" "$(_marckv_git --no-pager log -1 --format='%h  %cs  %s')"
    printf "  %-10s %s\n" "branch" "$branch"

    # Without a fetch, "behind" is measured against whatever origin looked
    # like last time. Bounded, so an offline server does not hang here.
    GIT_TERMINAL_PROMPT=0 timeout 15 git -C "$MARCKV_DOTS_DIR" fetch --quiet 2>/dev/null || fetched=no

    if upstream=$(_marckv_git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
        counts=$(_marckv_git rev-list --left-right --count "HEAD...@{upstream}")
        ahead=${counts%%[[:space:]]*}
        behind=${counts##*[[:space:]]}
        if [[ "$behind" -gt 0 ]]; then
            printf "  %-10s ${YELLOW}%s${RESET}\n" "origin" "$behind commit(s) behind $upstream — marckv update"
        else
            printf "  %-10s %s\n" "origin" "up to date with $upstream"
        fi
        [[ "$ahead" -gt 0 ]] && printf "  %-10s ${YELLOW}%s${RESET}\n" "" "$ahead local commit(s) not on $upstream"
        [[ "$fetched" == no ]] && printf "  %-10s %s\n" "" "(could not reach origin: compared with the last fetch)"
    else
        printf "  %-10s %s\n" "origin" "no upstream for $branch"
    fi

    changes=$(_marckv_git status --porcelain | wc -l)
    if [[ "$changes" -gt 0 ]]; then
        printf "  %-10s ${YELLOW}%s${RESET}\n" "changes" "$changes file(s) changed locally — an update may refuse to run"
    else
        printf "  %-10s %s\n" "changes" "none"
    fi

    "$MARCKV_DOTS_DIR/installer/install.sh" status
}

_marckv_install() {
    local piece="$1" script
    [[ $# -gt 0 ]] && shift

    case "$piece" in
        ""|all)  script="install.sh" ;;
        bash)    script="01-install-bash.sh" ;;
        docker)  script="02-install-docker-aliases.sh" ;;
        tmux)    script="03-install-tmux.sh" ;;
        nvim)    script="04-install-nvim-lite.sh" ;;
        atuin)   script="05-install-atuin.sh" ;;
        vim)     script="06-install-vim.sh" ;;
        *)
            echo -e "${RED}error:${RESET} unknown piece '$piece' — one of: all ${_MARCKV_PIECES}" >&2
            return 1
            ;;
    esac

    # In a subshell: the installers cd and set -e, and neither may leak here.
    ( cd "$MARCKV_DOTS_DIR/installer" && "./$script" "$@" )
}

_marckv_doctor() {
    local problems=0 v glibc

    _doc_ok()   { printf "  ${GREEN}[OK]${RESET}   %-10s %s\n" "$1" "$2"; }
    _doc_warn() { printf "  ${YELLOW}[WARN]${RESET} %-10s %s\n" "$1" "$2"; problems=$((problems + 1)); }
    _doc_info() { printf "  ${CYAN}[--]${RESET}   %-10s %s\n" "$1" "$2"; }

    if command -v git >/dev/null; then
        _doc_ok git "$(git --version)"
    else
        _doc_warn git "not installed — marckv update cannot work"
    fi

    if [[ -d "$MARCKV_DOTS_DIR/.git" ]]; then
        _doc_ok repo "$MARCKV_DOTS_DIR"
    else
        _doc_warn repo "$MARCKV_DOTS_DIR is not a git clone"
    fi

    # Under C/POSIX the tables count bytes, and every —, → or ∞ eats padding.
    v=$(locale charmap 2>/dev/null)
    if [[ "$v" == UTF-8 ]]; then
        _doc_ok locale "${LC_ALL:-${LANG:-UTF-8}}"
    else
        _doc_warn locale "${v:-unknown} — tables misalign; set LANG=C.UTF-8"
    fi

    if [[ ":$PATH:" == *":$MARCKV_DOTS_DIR/bash/bin:"* ]]; then
        _doc_ok PATH "includes bash/bin (ips)"
    else
        _doc_warn PATH "bash/bin is missing — ips is not reachable"
    fi

    if ! command -v docker >/dev/null; then
        _doc_info docker "not installed"
    elif timeout 10 docker info >/dev/null 2>&1; then
        _doc_ok docker "$(docker version --format '{{.Server.Version}}' 2>/dev/null) — daemon reachable"
    else
        _doc_warn docker "daemon not reachable as $USER (not running, or not in the docker group)"
    fi

    if command -v tmux >/dev/null; then
        _doc_ok tmux "$(tmux -V)"
    else
        _doc_info tmux "not installed"
    fi

    # A Neovim built for a newer GLIBC is on the PATH and still fails to start,
    # so run it rather than trusting command -v.
    glibc=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    if ! command -v nvim >/dev/null; then
        _doc_info nvim "not installed"
    elif v=$(nvim --version 2>&1 | head -n1) && [[ "$v" == NVIM* ]]; then
        _doc_ok nvim "$v (GLIBC ${glibc:-?})"
    else
        _doc_warn nvim "installed but does not start on GLIBC ${glibc:-?} — sudo $MARCKV_DOTS_DIR/installer/install-nvim.sh"
    fi

    if command -v nvim >/dev/null; then
        if command -v gcc >/dev/null || command -v cc >/dev/null; then
            _doc_ok compiler "present — treesitter parsers can build"
        else
            _doc_warn compiler "no gcc — treesitter parsers cannot build (marckv install nvim -d)"
        fi
    fi

    # vim-tiny is what a minimal Debian ships: no syntax, and vim-lite can only
    # give it the basic settings.
    if ! command -v vim >/dev/null; then
        _doc_info vim "not installed"
    elif vim --version 2>/dev/null | grep -q '+eval'; then
        _doc_ok vim "$(vim --version | head -n1 | sed -E 's/.*IMproved ([0-9.]+).*/\1/'), full"
    else
        _doc_warn vim "only vim-tiny — no syntax, no vim-lite pickers (apt install vim)"
    fi

    # marckv update refuses to move without both: gpg to check signatures, and
    # the keys it checks them against.
    if ! command -v gpg >/dev/null; then
        _doc_warn gpg "not installed — marckv update cannot verify signatures (apt install gnupg)"
    elif [[ ! -f "$MARCKV_DOTS_DIR/keys/marckv.asc" ]]; then
        _doc_warn keys "no keys/marckv.asc in the repo — marckv update cannot verify signatures"
    else
        _doc_ok signing "gpg present, updates are checked against keys/"
    fi

    unset -f _doc_ok _doc_warn _doc_info
    echo
    if [[ $problems -eq 0 ]]; then
        echo -e "  ${GREEN}Nothing to fix.${RESET}"
    else
        echo -e "  ${YELLOW}$problems thing(s) to look at.${RESET}"
        return 1
    fi
}

_marckv_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "update reload help cd status version whatsnew install doctor" -- "$cur")
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case "${COMP_WORDS[1]}" in
            help)    mapfile -t COMPREPLY < <(compgen -W "nav git system processes network services logs packages files shell security docker" -- "$cur") ;;
            install) mapfile -t COMPREPLY < <(compgen -W "all $_MARCKV_PIECES" -- "$cur") ;;
        esac
    fi
}
complete -F _marckv_complete marckv
