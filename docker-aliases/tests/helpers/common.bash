#!/usr/bin/env bash
# docker-aliases tests — shared setup and command wrappers.
#
# Loaded by every .bats file:
#     load '../helpers/common'
#
# THE SHELL DIMENSION
#
# bats itself runs in bash, but the code under test has to behave identically in
# bash and zsh — every portability bug this suite has caught lived in that gap.
# So the shell is a parameter: every wrapper invokes "$DA_SHELL -c", and run.sh
# runs the whole suite once per shell. That keeps one test per assertion instead
# of looping inside them, so a failure names the shell it happened in.

DA_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DA_DIR="$(dirname "$DA_TESTS_DIR")"
INIT="${DA_DIR}/init.sh"

# Which shell the code under test runs in. run.sh sets it; bare `bats` defaults
# to bash so a single file can be run by hand.
DA_SHELL="${DA_SHELL:-bash}"

# The workspace (fixtures + shimmed docker) is built once by run.sh and passed
# in. Running a .bats file directly builds its own, so `bats cases/dcup.bats`
# works with nothing else set up.
if [[ -z "${DA_WORK:-}" ]]; then
    DA_WORK="$(mktemp -d)"
    export DA_WORK
    cp -r "${DA_TESTS_DIR}/fixtures" "${DA_WORK}/fixtures"
    mkdir -p "${DA_WORK}/fake-project" "${DA_WORK}/other-project"
    # shellcheck source=./shim.bash
    source "${DA_TESTS_DIR}/helpers/shim.bash"
    _write_shim "$DA_WORK" "$(command -v docker)"
fi

WORK="$DA_WORK"
F="${DA_WORK}/fixtures"

export PATH="${DA_WORK}/bin:${PATH}"
export DOCKER_ALIASES_NERD_FONT=0
export DOCKER_ALIASES_CACHE_TTL=0

# ---------------------------------------------------------------------------
# Running the code under test
#
# Each wrapper is a thin shell invocation. They exist so a test reads as one
# line of intent rather than five of plumbing.
# ---------------------------------------------------------------------------

strip_ansi() { sed -e 's/\x1b\[[0-9;]*m//g'; }

# in_dir <dir> <script…> — run a snippet with the aliases loaded
in_dir() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 | strip_ansi
}

# out_of <dir> <script…> — stdout only, for anything that gets piped
out_of() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>/dev/null | strip_ansi
}

# err_of <dir> <script…> — stderr only, where previews and errors live
err_of() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 >/dev/null | strip_ansi
}

# rc_of <dir> <script…> — the exit code, with no pipe to mask it
rc_of() {
    local dir="$1"; shift
    printf 'no\n' | "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " >/dev/null 2>&1
    printf '%s' "$?"
}

# declined <dir> <script…> — answer "no" at any prompt, capture everything
declined() {
    local dir="$1"; shift
    printf 'no\n' | "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 | strip_ansi
}

# argv_of <dir> <script…> — only the shimmed argv lines, prompts auto-answered
argv_of() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        export DOCKER_ALIASES_AUTO_YES=1
        source '$INIT'
        $*
    " 2>&1 | strip_ansi | grep '^ARGV:'
}

# answer <dir> <answer> <script…> — ACCEPT if it ran, REJECT if it did not
answer() {
    local dir="$1" reply="$2"; shift 2
    local out
    out=$(printf '%s\n' "$reply" | "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 | strip_ansi)
    case "$out" in
        *"ARGV:"*) printf 'ACCEPT' ;;
        *)         printf 'REJECT' ;;
    esac
}

# lib_call <dir> <expression> — call a library function directly
lib_call() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>/dev/null
}

# ---------------------------------------------------------------------------
# Completion
#
# bash completion is driven exactly as bash drives it: set COMP_WORDS and
# COMP_CWORD, read COMPREPLY. That is the real mechanism.
#
# zsh cannot be driven that way — compadd and _files only exist inside a live
# completion — so those are stubbed and the function is called directly. That
# covers the branching and the data it feeds on, which is where the portability
# bugs have actually been. It does NOT cover compsys wiring; pressing TAB in a
# real zsh stays a manual check.
# ---------------------------------------------------------------------------

# complete_in <dir> <cword> <word>… — completion candidates for a command line
complete_in() {
    local dir="$1" cword="$2"; shift 2
    local words=("$@")

    if [[ "$DA_SHELL" == "bash" ]]; then
        local cmd="${words[0]}"
        local quoted="" w
        for w in "${words[@]}"; do quoted+=" '${w}'"; done
        bash -c "
            cd '$dir' || exit 99
            source '$INIT'
            COMP_WORDS=($quoted)
            COMP_CWORD=$cword
            _${cmd}_complete_bash
            printf '%s\n' \"\${COMPREPLY[@]}\"
        " 2>&1
        return
    fi

    local cmd="${words[0]}"
    local quoted="" w
    for w in "${words[@]}"; do quoted+=" '${w}'"; done
    zsh -c "
        cd '$dir' || exit 99
        source '$INIT'
        compadd() {
            local -a items
            if [[ \"\$1\" == \"-a\" ]]; then items=(\${(P)2}); else items=(\"\$@\"); fi
            print -l -- \$items
        }
        _files() { print -l -- '__files__'; }
        words=($quoted)
        CURRENT=$(( cword + 1 ))
        _${cmd}_complete_zsh
    " 2>&1
}
