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

# --- the preview does not rewrite the user's argv ---------------------------
#
# The design rule says the preview shows the real command, and the reason given
# is that nothing here uses `eval`. That was the wrong hazard. The command line
# was printed with `printf %b`, which runs escape processing over the argv the
# USER typed:
#
#   sed 's/a/\n/'     →  preview showed a real line break
#   printf 'a\tb'     →  preview showed a real tab
#   echo 'a\cb'       →  `\c` means "stop output here", so the preview TRUNCATED
#                         itself and the rest of the command vanished silently
#
# Fixed by making the colour constants real escape bytes and the command line
# a plain %s. Quoting is still not round-tripped — an argv array cannot survive
# as one string — but the preview no longer shows something the user did not
# type.

@test "the preview shows a backslash-n literally" {
    run err_of "$F/basic" "dcx api sed 's/a/\\n/'"
    [[ "$output" == *'s/a/\n/'* ]]
}

@test "the preview does not turn backslash-n into a line break" {
    run err_of "$F/basic" "dcx api sed 's/a/\\n/'"
    # The command line is one line. If %b resolved the escape, the argument
    # splits across two and `s/a/` ends a line on its own.
    [[ "$output" != *'s/a/'$'\n'* ]]
}

@test "the preview shows a backslash-t literally" {
    run err_of "$F/basic" "dcx api printf 'uno\\tdos'"
    [[ "$output" == *'uno\tdos'* ]]
}

@test "a backslash-c in an argument does not truncate the preview" {
    # The severe one: \c told printf to stop, so everything after it — including
    # any further argument — was dropped without a trace.
    run err_of "$F/basic" "dcx api echo 'antes\\cdespues'"
    [[ "$output" == *'antes\cdespues'* ]]
}

# Raw stderr, deliberately not through strip_ansi: this is the one assertion
# that has to see the escape bytes.
raw_err() {
    local dir="$1"; shift
    "$DA_SHELL" -c "
        cd '$dir' || exit 99
        source '$INIT'
        $*
    " 2>&1 >/dev/null
}

@test "the preview still renders colour" {
    # The fix moved the colour constants from literal backslash sequences to
    # real escape bytes. If that had gone wrong the four tests above would pass
    # while every preview came out full of visible \033[1;37m.
    run raw_err "$F/basic" "dcx api echo hi"
    printf '%s' "$output" | grep -q $'\033\[' || { echo "no escape bytes at all" >&2; return 1; }
    printf '%s' "$output" | grep -qF '\033[' && { echo "escapes came out literal" >&2; return 1; }
    return 0
}
