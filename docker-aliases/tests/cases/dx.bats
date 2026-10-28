#!/usr/bin/env bats
# dx — run a command or open a shell inside any running container.
#
# The shim invents four containers: fx-api, fx-db, other-api, plain-box. Two of
# them share the "api" substring on purpose, so "several matches is an error"
# has something to bite on.

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

# --- help and parsing -------------------------------------------------------

@test "dx --help shows usage" {
    run in_dir "$WORK" 'dx --help'
    [[ "$output" == *"USAGE"* ]]
    [[ "$output" == *"dx"* ]]
}

@test "dx -h shows usage" {
    run in_dir "$WORK" 'dx -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dx with no pattern is an error" {
    run rc_of "$WORK" 'dx'
    [ "$output" = "1" ]
}

@test "dx exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dx -z fx-api'
    [ "$output" = "1" ]
}

@test "dx -u without a value is an error" {
    run rc_of "$WORK" 'dx -u'
    [ "$output" = "1" ]
}

# --- matching ---------------------------------------------------------------

@test "dx runs in the one container the pattern matches" {
    run argv_of "$WORK" "dx fx-db ls"
    [[ "$output" == *"[exec]"* ]]
    [[ "$output" == *"[fx-db]"* ]]
}

@test "dx refuses a pattern that matches several containers" {
    run rc_of "$WORK" "dx api ls"
    [ "$output" = "1" ]
}

@test "dx names every container the ambiguous pattern matched" {
    run err_of "$WORK" "dx api ls"
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"other-api"* ]]
}

@test "dx runs nothing when the pattern is ambiguous" {
    # The error alone is not the guarantee — not executing anything is.
    run argv_of "$WORK" "dx api ls"
    [ -z "$output" ]
}

@test "dx anchors narrow an ambiguous pattern to one" {
    run argv_of "$WORK" "dx '^fx-api\$' ls"
    [[ "$output" == *"[fx-api]"* ]]
    [[ "$output" != *"[other-api]"* ]]
}

@test "dx says so when nothing matched" {
    run err_of "$WORK" "dx zzz-nothing"
    [[ "$output" == *"no running container matched"* ]]
}

@test "dx lists the running containers when nothing matched" {
    run err_of "$WORK" "dx zzz-nothing"
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"fx-db"* ]]
}

# --- parsing stops at the pattern -------------------------------------------

@test "dx hands flags after the pattern to the command" {
    run argv_of "$WORK" "dx fx-db ls -la /app"
    [[ "$output" == *"[ls] [-la] [/app]"* ]]
}

@test "dx does not read -u after the pattern as its own flag" {
    run argv_of "$WORK" "dx fx-db id -u"
    [[ "$output" == *"[id] [-u]"* ]]
    [[ "$output" != *"[--user]"* ]]
}

# --- the shell probe --------------------------------------------------------

@test "dx with no command opens bash when the image has it" {
    run with_bash "$WORK" "dx fx-db"
    [[ "$output" == *"[fx-db] [bash]"* ]]
}

@test "dx with no command falls back to sh without bash" {
    run argv_of "$WORK" "dx fx-db"
    [[ "$output" == *"[fx-db] [sh]"* ]]
}

# --- user, workdir, stdin and the TTY ---------------------------------------

@test "dx -u passes --user" {
    run argv_of "$WORK" "dx -u root fx-db ls"
    [[ "$output" == *"[--user] [root]"* ]]
}

@test "dx -w passes --workdir" {
    run argv_of "$WORK" "dx -w /srv fx-db ls"
    [[ "$output" == *"[--workdir] [/srv]"* ]]
}

@test "dx keeps stdin open when it is a pipe" {
    # The bug this pins: -i used to be given only when stdin was a TERMINAL,
    # so `cat dump.sql | dx postgres psql` delivered an empty stdin and nothing
    # ran. Measured before the fix. Plain `docker exec`, unlike compose exec,
    # keeps no stdin unless asked.
    run argv_of "$WORK" "printf 'x\n' | dx fx-db wc -l"
    [[ "$output" == *"[exec] [-i]"* ]]
}

@test "dx allocates no TTY when there is no terminal" {
    # There is no terminal in the suite at all, so -t must never appear. A TTY
    # into a pipe is what makes `dx api ls | grep` misbehave.
    run argv_of "$WORK" "dx fx-db ls"
    [[ "$output" != *"[-it]"* ]]
    [[ "$output" != *"[-t]"* ]]
}

# --- the preview ------------------------------------------------------------

@test "dx previews on stderr" {
    run err_of "$WORK" "dx fx-db ls"
    [[ "$output" == *"docker exec"* ]]
}

@test "dx keeps the preview out of stdout" {
    # stdout belongs to the command's own output, which is what gets piped.
    run out_of "$WORK" "dx fx-db ls"
    [[ "$output" != *"docker exec"* ]]
}

@test "dx asks for no confirmation" {
    # Opening a shell changes nothing by itself. Answering "no" must not stop
    # it — if it did, dx would have grown a prompt it should not have.
    run declined "$WORK" "dx fx-db ls"
    [[ "$output" == *"ARGV:"* ]]
}

# --- completion -------------------------------------------------------------

@test "dx completes running container names" {
    run complete_in "$WORK" 1 dx ''
    [[ "$output" == *"fx-api"* ]]
}

@test "dx does not offer its own flags after the pattern" {
    # dcx gets this wrong: it offers -u/-w after the pattern, where they are
    # argv for the command inside the container.
    run complete_in "$WORK" 2 dx fx-db '-'
    [[ "$output" != *"--help"* ]]
}
