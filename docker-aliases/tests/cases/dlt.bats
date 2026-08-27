#!/usr/bin/env bats
# dlt — tail container logs, host-wide.

load '../helpers/common'

# --- help -------------------------------------------------------------------

@test "dlt --help shows usage" {
    run in_dir "$WORK" 'dlt --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dlt --help documents flag clustering" {
    run in_dir "$WORK" 'dlt --help'
    [[ "$output" == *"-ot"* ]]
}

@test "dlt --help explains the one-vs-several split" {
    run in_dir "$WORK" 'dlt --help'
    [[ "$output" == *"ONE CONTAINER vs SEVERAL"* ]]
}

@test "dlt --help points at dclt for compose projects" {
    run in_dir "$WORK" 'dlt --help'
    [[ "$output" == *"dclt"* ]]
}

# --- preview ----------------------------------------------------------------
#
# Reading logs changes nothing, so there is no confirmation — but the preview
# is still mandatory, and still on stderr so a piped dump stays clean.

@test "dlt previews the action" {
    run err_of "$WORK" 'dlt -o fx-api'
    [[ "$output" == *"docker logs"* ]]
}

@test "dlt previews the container it matched" {
    run err_of "$WORK" 'dlt -o fx-api'
    [[ "$output" == *"fx-api"* ]]
}

@test "dlt previews the flags" {
    run err_of "$WORK" 'dlt -o fx-api'
    [[ "$output" == *"--tail 100"* ]]
}

@test "dlt does not ask for confirmation" {
    run in_dir "$WORK" 'dlt -o fx-api'
    [[ "$output" != *"[yes/N]"* ]]
}

@test "dlt keeps the preview off stdout" {
    run out_of "$WORK" 'dlt -o fx-api'
    [[ "$output" != *"docker logs"* ]]
}

# --- flags to argv ----------------------------------------------------------

@test "dlt defaults to 100 lines" {
    run in_dir "$WORK" 'dlt -o fx-api'
    [[ "$output" == *"[--tail] [100]"* ]]
}

@test "dlt follows by default" {
    run in_dir "$WORK" 'dlt fx-api'
    [[ "$output" == *"[--follow]"* ]]
}

@test "dlt -o does not follow" {
    run in_dir "$WORK" 'dlt -o fx-api'
    [[ "$output" != *"[--follow]"* ]]
}

@test "dlt -t adds timestamps" {
    run in_dir "$WORK" 'dlt -ot fx-api'
    [[ "$output" == *"[--timestamps]"* ]]
}

@test "dlt -n sets the line count" {
    run in_dir "$WORK" 'dlt -o -n 500 fx-api'
    [[ "$output" == *"[--tail] [500]"* ]]
}

@test "dlt -n all is accepted" {
    run in_dir "$WORK" 'dlt -o -n all fx-api'
    [[ "$output" == *"[--tail] [all]"* ]]
}

@test "dlt -s passes the since window" {
    run in_dir "$WORK" 'dlt -o -s 10m fx-api'
    [[ "$output" == *"[--since] [10m]"* ]]
}

@test "dlt names the container last" {
    run in_dir "$WORK" 'dlt -o fx-api'
    [[ "$output" == *"[fx-api]"* ]]
}

# A bare integer is the line count — the same rule dclt uses, and what replaces
# the idea of separate dlt100 / dlt500 commands.
@test "dlt takes a bare number as the line count" {
    run in_dir "$WORK" 'dlt -o 500 fx-api'
    [[ "$output" == *"[--tail] [500]"* ]]
}

# A bare number alone must still match everything. If it were taken as a
# pattern it would match no container and exit 1, which is the discriminator —
# asserting on the argv cannot tell the two apart, since "[500]" appears in it
# either way as the value of --tail.
@test "a bare number alone is not treated as a pattern" {
    run rc_of "$WORK" 'dlt -o 500'
    [ "$output" = "0" ]
}

# --- matching ---------------------------------------------------------------

@test "dlt matches on a regular expression" {
    run in_dir "$WORK" "dlt -o 'fx-'"
    [[ "$output" == *"fx-api"* ]]
}

@test "dlt matches every container with no pattern" {
    run err_of "$WORK" 'dlt -o'
    [[ "$output" == *"plain-box"* ]]
}

@test "dlt anchors work" {
    run err_of "$WORK" "dlt -o '^fx-db\$'"
    [[ "$output" != *"fx-api"* ]]
}

@test "dlt exits 1 when nothing matches" {
    run rc_of "$WORK" 'dlt -o nosuchcontainer'
    [ "$output" = "1" ]
}

@test "dlt lists what was available when nothing matches" {
    run in_dir "$WORK" 'dlt -o nosuchcontainer'
    [[ "$output" == *"available:"* ]]
}

# --- one container vs several -----------------------------------------------
#
# `docker logs` takes exactly one container. One match is handed straight to
# docker and streams raw; several are prefixed here so the interleaving can be
# read. These two are the load-bearing behaviour of the command.

@test "a single match is not prefixed" {
    run out_of "$WORK" 'dlt -o fx-db'
    [[ "$output" != *"fx-db |"* ]]
}

@test "several matches are prefixed with the container name" {
    run out_of "$WORK" "dlt -o 'fx-'"
    [[ "$output" == *"fx-api"*"|"* ]]
}

@test "several matches prefix every container, not just the first" {
    run out_of "$WORK" "dlt -o 'fx-'"
    [[ "$output" == *"fx-db"*"|"* ]]
}

# The names are padded into a column so the separator lines up. Asserting that
# the escapes come out resolved would have been the obvious test here and it
# CANNOT FAIL: `awk -v` performs escape processing on the value it assigns, so
# "\033[" becomes a real ESC whether or not printf got there first. Alignment
# can break; that escape handling cannot.
@test "the prefix is padded so the separator lines up" {
    run out_of "$WORK" "dlt -o 'fx-'"
    local first rest col
    col=""
    while IFS= read -r line; do
        case "$line" in
            *"|"*) ;;
            *) continue ;;
        esac
        rest="${line%%|*}"
        if [ -z "$col" ]; then col=${#rest}
        elif [ "${#rest}" != "$col" ]; then
            printf 'misaligned: %s\n' "$line" >&2
            return 1
        fi
    done <<< "$output"
    [ -n "$col" ]
}

# --- errors -----------------------------------------------------------------

@test "dlt exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dlt --bogus'
    [ "$output" = "1" ]
}

@test "dlt explains an unknown flag" {
    run in_dir "$WORK" 'dlt --bogus'
    [[ "$output" == *"unknown flag"* ]]
}

@test "dlt exits 1 when -n has no value" {
    run rc_of "$WORK" 'dlt -n'
    [ "$output" = "1" ]
}

@test "dlt exits 1 when -s has no value" {
    run rc_of "$WORK" 'dlt -s'
    [ "$output" = "1" ]
}

@test "dlt rejects a non-numeric line count" {
    run rc_of "$WORK" 'dlt -n lots fx-api'
    [ "$output" = "1" ]
}

# --- completion -------------------------------------------------------------

@test "dlt completes container names" {
    run complete_in "$WORK" 1 dlt ''
    [[ "$output" == *"fx-api"* ]]
}

@test "dlt offers -a" {
    run complete_in "$WORK" 1 dlt '-'
    [[ "$output" == *"-a"* ]]
}

@test "dlt completes line counts after -n" {
    run complete_in "$WORK" 2 dlt '-n' ''
    [[ "$output" == *"all"* ]]
}

@test "dlt completes time windows after -s" {
    run complete_in "$WORK" 2 dlt '-s' ''
    [[ "$output" == *"10m"* ]]
}
