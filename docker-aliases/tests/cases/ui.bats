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
# dcver and only the distro matrix caught it — this catches the next one first.

uses_tool() {
    grep -rnE "(^|[;&|(\`]|\\\$\\()[[:space:]]*${1}[[:space:]]" \
        "$DA_DIR/commands" "$DA_DIR/lib" "$DA_DIR/completions" "$DA_DIR/init.sh" \
        2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true
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
