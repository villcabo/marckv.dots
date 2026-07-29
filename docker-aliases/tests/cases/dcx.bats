#!/usr/bin/env bats
# dcx — run a command or open a shell inside a service.

load '../helpers/common'

# with_bash <dir> <script…> — pretend the image ships bash
with_bash() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        export DAV2_FAKE_BASH=1
        source '$INIT'
        $*
    " 2>/dev/null | strip_ansi | grep '^ARGV:'
}

# --- help -------------------------------------------------------------------

@test "dcx --help shows usage" {
    run in_dir "$F/multimatch" 'dcx --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dcx --help explains the shell fallback" {
    run in_dir "$F/multimatch" 'dcx --help'
    [[ "$output" == *"falling back"* ]]
}

@test "dcx --help warns that flags precede the pattern" {
    run in_dir "$F/multimatch" 'dcx --help'
    [[ "$output" == *"BEFORE"* ]]
}

# --- shell selection --------------------------------------------------------
#
# The daily tax this command exists to remove: alpine images have no bash, so
# `dcx api bash` failed, and you retyped `dcx api sh`.

@test "dcx falls back to sh when the image has no bash" {
    run argv_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"[api] [sh]"* ]]
}

@test "dcx opens bash when the image has it" {
    run with_bash "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"[api] [bash]"* ]]
}

@test "dcx skips the probe when given an explicit command" {
    run argv_of "$F/multimatch" "dcx '^api\$' ls"
    [[ "$output" != *"[sh]"* ]]
}

# --- argument handling ------------------------------------------------------
#
# Flag parsing stops at the pattern, or -la is read as two dcx options.

@test "dcx passes the command through intact" {
    run argv_of "$F/multimatch" "dcx '^api\$' ls -la /app"
    [[ "$output" == *"[ls] [-la] [/app]"* ]]
}

@test "dcx does not eat the command's own flags" {
    run argv_of "$F/multimatch" "dcx '^api\$' ls -la /app"
    [[ "$output" != *"unknown flag"* ]]
}

@test "dcx -u maps to --user" {
    run argv_of "$F/multimatch" "dcx -u root '^api\$'"
    [[ "$output" == *"[--user] [root]"* ]]
}

@test "dcx -w maps to --workdir" {
    run argv_of "$F/multimatch" "dcx -w /app '^api\$' npm test"
    [[ "$output" == *"[--workdir] [/app]"* ]]
}

@test "dcx drops the TTY when there is no terminal" {
    run argv_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"[--no-tty]"* ]]
}

# --- refusing to guess ------------------------------------------------------
#
# You can only be inside one container, and silently picking the first is how
# you type into the wrong shell without noticing.

@test "dcx says how many services matched" {
    run err_of "$F/multimatch" 'dcx api'
    [[ "$output" == *"matched 2 services"* ]]
}

@test "dcx lists the ambiguous services" {
    run err_of "$F/multimatch" 'dcx api'
    [[ "$output" == *"api-worker"* ]]
}

@test "dcx suggests an anchored pattern" {
    run err_of "$F/multimatch" 'dcx api'
    [[ "$output" == *"^api"* ]]
}

@test "dcx exits 1 on an ambiguous pattern" {
    run rc_of "$F/multimatch" 'dcx api'
    [ "$output" = "1" ]
}

@test "dcx resolves once the pattern is anchored" {
    run argv_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"[api] [sh]"* ]]
}

# --- errors -----------------------------------------------------------------

@test "dcx exits 1 when nothing matches" {
    run rc_of "$F/multimatch" 'dcx zzz'
    [ "$output" = "1" ]
}

@test "dcx exits 1 with no pattern" {
    run rc_of "$F/multimatch" 'dcx'
    [ "$output" = "1" ]
}

@test "dcx exits 1 on an unknown flag" {
    run rc_of "$F/multimatch" 'dcx -Z api'
    [ "$output" = "1" ]
}

@test "dcx exits 1 when -u has no value" {
    run rc_of "$F/multimatch" 'dcx -u'
    [ "$output" = "1" ]
}

@test "dcx explains that a pattern is required" {
    run err_of "$F/multimatch" 'dcx'
    [[ "$output" == *"pattern is required"* ]]
}

# --- preview ----------------------------------------------------------------

@test "dcx previews the action" {
    run err_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"compose exec"* ]]
}

@test "dcx previews the target service" {
    run err_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" == *"api"* ]]
}

@test "dcx never asks to confirm" {
    run err_of "$F/multimatch" "dcx '^api\$'"
    [[ "$output" != *"[yes/N]"* ]]
}
