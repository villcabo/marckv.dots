#!/usr/bin/env bats
# dcd — jump to a container's compose project directory.

load '../helpers/common'

# dcd runs against the whole host, so its tests work out of the workspace root
# rather than any fixture.

# where_after <args…> — the directory the shell ends up in
where_after() {
    "$DA_SHELL" -c "
        cd '$WORK' || exit 99
        source '$INIT'
        dcd $* >/dev/null 2>&1
        pwd
    " 2>/dev/null
}

# --- help -------------------------------------------------------------------

@test "dcd --help shows usage" {
    run in_dir "$WORK" 'dcd --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dcd --help documents -p for scripting" {
    run in_dir "$WORK" 'dcd --help'
    [[ "$output" == *"scripting"* ]]
}

@test "dcd --help states env vars are never shown" {
    run in_dir "$WORK" 'dcd --help'
    [[ "$output" == *"never shown"* ]]
}

# --- jumping ----------------------------------------------------------------
#
# Several containers of ONE project is the normal case, not an ambiguity: they
# all lead to the same directory.

@test "dcd jumps when many containers share one project" {
    run where_after fx
    [ "$output" = "${WORK}/fake-project" ]
}

@test "dcd -p prints the path on stdout" {
    run out_of "$WORK" 'dcd -p fx'
    [ "$output" = "${WORK}/fake-project" ]
}

@test "dcd -p leaves the shell where it was" {
    run where_after -p fx
    [ "$output" = "$WORK" ]
}

@test "dcd -i does not move either" {
    run where_after -i fx
    [ "$output" = "$WORK" ]
}

@test "dcd honours an anchored pattern" {
    run where_after "'^fx-api\$'"
    [ "$output" = "${WORK}/fake-project" ]
}

# --- details ----------------------------------------------------------------

@test "dcd names the project" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"fixture-proj"* ]]
}

@test "dcd counts what is running" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"1/2 running"* ]]
}

@test "dcd lists the services" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"db"* ]]
}

@test "dcd shows the compose file" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"docker-compose.yml"* ]]
}

@test "dcd shows the override file too" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"docker-compose.override.yml"* ]]
}

@test "dcd shows the directory" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" == *"fake-project"* ]]
}

# Compose files are absolute in the labels; showing them relative to the
# project keeps the block readable.
@test "dcd does not repeat the project path on every file" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" != *"${WORK}/fake-project/docker-compose.yml"* ]]
}

# --- privacy ----------------------------------------------------------------
#
# docker inspect hands over environment variables freely, and in a real project
# those are database passwords and API tokens.

@test "dcd shows no environment section" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" != *"Env"* ]]
}

@test "dcd shows no variable assignments" {
    run err_of "$WORK" 'dcd -i fx'
    [[ "$output" != *"PASSWORD"* ]]
}

# --- refusing to guess ------------------------------------------------------
#
# The ambiguity that matters is the DESTINATION, not the container.

@test "dcd says how many projects a pattern spans" {
    run err_of "$WORK" 'dcd api'
    [[ "$output" == *"spans 2 projects"* ]]
}

@test "dcd names the first project" {
    run err_of "$WORK" 'dcd api'
    [[ "$output" == *"fixture-proj"* ]]
}

@test "dcd names the second project" {
    run err_of "$WORK" 'dcd api'
    [[ "$output" == *"other-proj"* ]]
}

@test "dcd exits 1 when a pattern spans two projects" {
    run rc_of "$WORK" 'dcd api'
    [ "$output" = "1" ]
}

@test "dcd does not move the shell when ambiguous" {
    run where_after api
    [ "$output" = "$WORK" ]
}

# --- errors -----------------------------------------------------------------

@test "dcd exits 1 when nothing matches" {
    run rc_of "$WORK" 'dcd zzz'
    [ "$output" = "1" ]
}

@test "dcd exits 1 with no pattern" {
    run rc_of "$WORK" 'dcd'
    [ "$output" = "1" ]
}

@test "dcd exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dcd -Z fx'
    [ "$output" = "1" ]
}

@test "dcd exits 1 on two patterns" {
    run rc_of "$WORK" 'dcd fx other'
    [ "$output" = "1" ]
}

@test "dcd explains a container that compose did not create" {
    run err_of "$WORK" 'dcd plain-box'
    [[ "$output" == *"docker compose"* ]]
}

@test "dcd exits 1 for a non-compose container" {
    run rc_of "$WORK" 'dcd plain-box'
    [ "$output" = "1" ]
}
