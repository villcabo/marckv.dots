#!/usr/bin/env bats
# The presentation layer, and one guard on the sources themselves.

load '../helpers/common'

# --- Nerd Font icons --------------------------------------------------------
#
# The whole suite runs with DOCKER_ALIASES_NERD_FONT=0, so for a long time
# nothing exercised the Nerd Font branch — and it shipped with every glyph
# replaced by an empty string. A blank icon looks exactly like a working one
# the terminal cannot draw, so nobody noticed.

icon_bytes() {
    "$DA_SHELL" -c "
        DOCKER_ALIASES_NERD_FONT=1
        export DOCKER_ALIASES_NERD_FONT
        source '$INIT'
        _icon $1" 2>/dev/null | wc -c | tr -d ' '
}

@test "icon 'docker' emits a glyph" {
    run icon_bytes docker
    [ "$output" = "3" ]
}

@test "icon 'file' emits a glyph" {
    run icon_bytes file
    [ "$output" = "3" ]
}

@test "icon 'services' emits a glyph" {
    run icon_bytes services
    [ "$output" = "3" ]
}

@test "icon 'flags' emits a glyph" {
    run icon_bytes flags
    [ "$output" = "3" ]
}

@test "icon 'cmd' emits a glyph" {
    run icon_bytes cmd
    [ "$output" = "3" ]
}

@test "icon 'dir' emits a glyph" {
    run icon_bytes dir
    [ "$output" = "3" ]
}

@test "icon 'volumes' emits a glyph" {
    run icon_bytes volumes
    [ "$output" = "3" ]
}

@test "icon 'warn' emits a glyph" {
    run icon_bytes warn
    [ "$output" = "3" ]
}

@test "icon 'confirm' emits a glyph" {
    run icon_bytes confirm
    [ "$output" = "3" ]
}

@test "icon 'health' emits a glyph" {
    run icon_bytes health
    [ "$output" = "3" ]
}

@test "icon 'health' is not the unknown-icon fallback" {
    run "$DA_SHELL" -c "
        DOCKER_ALIASES_NERD_FONT=1
        export DOCKER_ALIASES_NERD_FONT
        source '$INIT'
        _icon health"
    [[ "$output" != *"*"* ]]
}

# --- no workstation-only tools ----------------------------------------------
#
# These are excellent and they are on the author's machine. None is on a fresh
# Debian server, which is where these aliases get used. An `sd` slipped into
# dcver and only the distro matrix caught it.
#
# The first version of this claimed to catch the next one and did not. It
# required the tool to follow start-of-line, `;`, `&`, `|`, `(`, a backtick or
# `$(` — so `if jq …`, `then rg …`, `do sd …`, `! rg …`, `xargs fd …` and a
# `| jq` at end of line all walked straight past it. Falsified by planting
# seven forms: six escaped. Only a tool at the very start of a line was seen,
# which is exactly the shape the original `sd` happened to have.
#
# Two changes. The pattern now asks the real question — is this token a
# command word? — by rejecting only an identifier character before it, and it
# accepts end-of-line after it. And `uses_tool` no longer swallows its own
# failure: a `grep` that cannot read the sources is a broken test, not a pass.

uses_tool() {
    local dir="${2:-$DA_DIR}"
    # No `|| true`: grep exits 1 for "no match", which IS the passing case, so
    # the callers compare the OUTPUT. Pointing this at a directory that does
    # not exist used to come back empty and green.
    [ -d "$dir/commands" ] || { echo "MISSING SOURCES: $dir/commands"; return 0; }
    grep -rnE "(^|[^[:alnum:]_])${1}([[:space:]]|\$)" \
        "$dir/commands" "$dir/lib" "$dir/completions" "$dir/init.sh" 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
        | grep -vE '^[^:]+:[0-9]+:.*#.*' || true
}

# The positive control. Without it the twelve tests below are a dozen ways of
# asserting that an empty string is empty: they passed for a year over a
# pattern that caught one case in seven.
@test "uses_tool actually fires on the forms that slip past a naive pattern" {
    local sandbox="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$sandbox/commands" "$sandbox/lib" "$sandbox/completions"
    : > "$sandbox/init.sh"

    local form
    for form in \
        'jq . f' \
        'if jq -e . f; then :; fi' \
        '  then jq . f' \
        'for x in 1; do jq . f; done' \
        'cat f | jq' \
        'if ! jq -e . f; then :; fi' \
        'echo f | xargs jq .' \
        '{ jq . f; }'
    do
        printf '%s\n' "$form" > "$sandbox/lib/planted.sh"
        run uses_tool jq "$sandbox"
        if [ -z "$output" ]; then
            printf 'uses_tool did NOT see: %s\n' "$form" >&2
            return 1
        fi
    done

    # And the other direction: a name that merely contains the tool is not it.
    printf '%s\n' 'myjq=1; prjq "x"; echo nojq' > "$sandbox/lib/planted.sh"
    run uses_tool jq "$sandbox"
    [ -z "$output" ]
}

@test "uses_tool reports instead of passing when the sources are unreadable" {
    run uses_tool jq "$BATS_TEST_TMPDIR/nope"
    [[ "$output" == *"MISSING SOURCES"* ]]
}

@test "the sources call no 'sd'" {
    run uses_tool sd
    [ -z "$output" ]
}

@test "the sources call no 'rg'" {
    run uses_tool rg
    [ -z "$output" ]
}

@test "the sources call no 'fd'" {
    run uses_tool fd
    [ -z "$output" ]
}

@test "the sources call no 'bat'" {
    run uses_tool bat
    [ -z "$output" ]
}

@test "the sources call no 'jq'" {
    run uses_tool jq
    [ -z "$output" ]
}

@test "the sources call no 'yq'" {
    run uses_tool yq
    [ -z "$output" ]
}

@test "the sources call no 'eza'" {
    run uses_tool eza
    [ -z "$output" ]
}

@test "the sources call no 'fzf'" {
    run uses_tool fzf
    [ -z "$output" ]
}

@test "the sources call no 'exa'" {
    run uses_tool exa
    [ -z "$output" ]
}

@test "the sources call no 'delta'" {
    run uses_tool delta
    [ -z "$output" ]
}

@test "the sources call no 'dust'" {
    run uses_tool dust
    [ -z "$output" ]
}

@test "the sources call no 'procs'" {
    run uses_tool procs
    [ -z "$output" ]
}

# --- table alignment under a byte-counting locale ---------------------------
#
# ${#x} counts characters only in a UTF-8 locale. Under C or POSIX — a minimal
# Debian with no locale configured, an ssh that does not forward LANG, these
# very containers — it counts bytes, and every "—" in a cell (3 bytes) stole
# two columns of padding from dps, di, dip, dnet, dvol and dprj. Nothing caught
# it because no test ever looked at the alignment of a row holding a dash.

render_in_locale() {
    LC_ALL="$1" "$DA_SHELL" -c "
        source '$INIT'
        _render_container_table t 2 2 '' A B C D E F \
            \$'—\tb\tc\td\te\tf\nxxxxxxxxxxxx\tb\tc\td\te\tf\n3001→3000\tb\tc\td\te\tf' \
            white,white,white,white,white,white" 2>/dev/null | strip_ansi
}

@test "table pads a dash by characters under a byte-counting locale" {
    # Column one is 12 wide, so "—" takes 11 spaces plus the 2-space gap.
    run render_in_locale C
    [[ "$output" == *"—             b  c"* ]]
    [[ "$output" == *"xxxxxxxxxxxx  b  c"* ]]
}

@test "table pads an arrow by characters under a byte-counting locale" {
    # The arrow must NOT be the widest cell: the first version of this test
    # made it the widest, so it was never padded and passed with the bug in.
    run render_in_locale C
    [[ "$output" == *"3001→3000     b  c"* ]]
}

@test "table output is the same under C and UTF-8 locales" {
    local c u
    c=$(render_in_locale C)
    u=$(render_in_locale C.UTF-8)
    [ "$c" = "$u" ]
}
