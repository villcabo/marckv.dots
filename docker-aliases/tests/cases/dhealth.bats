#!/usr/bin/env bats
# dhealth — why a container is (un)healthy.
#
# The shim's health world:
#   fx-api     healthy
#   fx-db      unhealthy, 4 failures in a row, last probe printed TWO lines
#   other-api  starting, no probe yet
#   plain-box  no healthcheck at all
#
# One match gives the diagnosis; none or several give the table.

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dhealth --help shows usage" {
    run in_dir "$WORK" 'dhealth --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dhealth -h shows usage" {
    run in_dir "$WORK" 'dhealth -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dhealth exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dhealth -z'
    [ "$output" = "1" ]
}

@test "dhealth takes one pattern at a time" {
    run rc_of "$WORK" 'dhealth a b'
    [ "$output" = "1" ]
}

@test "dhealth exits 1 when no container matches" {
    run rc_of "$WORK" 'dhealth zzz-nothing'
    [ "$output" = "1" ]
}

# --- the table ----------------------------------------------------------------

@test "dhealth lists only containers that have a healthcheck" {
    run out_of "$WORK" 'dhealth'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"fx-db"* ]]
    [[ "$output" == *"other-api"* ]]
    [[ "$output" != *"plain-box"* ]]
}

@test "dhealth says how many containers have no healthcheck" {
    run err_of "$WORK" 'dhealth'
    [[ "$output" == *"1 running container(s) have no healthcheck"* ]]
}

@test "dhealth puts the unhealthy one first, then starting, then healthy" {
    # docker lists fx-api first. On a host with forty healthchecks, the one
    # that is failing must not be row 23.
    run out_of "$WORK" 'dhealth'
    local body
    body=$(printf '%s\n' "$output" | sed -n '3,$p' | awk '{print $NF}' | tr '\n' ' ')
    [ "$body" = "fx-db other-api fx-api " ]
}

@test "dhealth shows the failure streak and the last exit code" {
    run out_of "$WORK" 'dhealth'
    [[ "$output" == *"unhealthy  4      22:57:28  1"* ]]
}

@test "dhealth shows a dash for a probe that has not run yet" {
    run out_of "$WORK" 'dhealth'
    [[ "$output" == *"starting   —      —         —     30s"* ]]
}

@test "dhealth exits 1 when something shown is unhealthy" {
    # So `dhealth || alert` works.
    run rc_of "$WORK" 'dhealth'
    [ "$output" = "1" ]
}

@test "dhealth exits 0 when everything shown is fine" {
    # "api" matches fx-api and other-api: several, so the table — and neither
    # of them is unhealthy.
    run rc_of "$WORK" 'dhealth api'
    [ "$output" = "0" ]
}

@test "dhealth points at the diagnosis when something is unhealthy" {
    run err_of "$WORK" 'dhealth'
    [[ "$output" == *"1 unhealthy"* ]]
    [[ "$output" == *"dhealth <name>"* ]]
}

@test "dhealth keeps the footer out of stdout" {
    run out_of "$WORK" 'dhealth'
    [[ "$output" != *"no healthcheck"* ]]
    [[ "$output" != *"dhealth <name>"* ]]
}

# --- the diagnosis --------------------------------------------------------------

@test "dhealth on one match shows the probe command" {
    # The first question when a check fails: what is it actually checking?
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" == *"pg_isready -U app"* ]]
}

@test "dhealth on one match shows the streak" {
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" == *"(4 failed in a row)"* ]]
}

@test "dhealth calls an unset option 'default', not 0s" {
    # fx-db never set a start period; docker's typed zero value is "0s",
    # which reads like a start period of zero seconds.
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" == *"start period default"* ]]
    [[ "$output" != *"0s"* ]]
}

@test "dhealth calls retries 0 'default'" {
    run out_of "$WORK" 'dhealth other-api'
    [[ "$output" == *"retries default"* ]]
}

@test "dhealth lists probes newest first" {
    run out_of "$WORK" 'dhealth fx-db'
    local first
    first=$(printf '%s\n' "$output" | grep -m1 'exit ')
    [[ "$first" == *"exit 1"* ]]
}

@test "dhealth shows the first line of a multi-line probe output" {
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" == *"exit 1  no response"* ]]
}

@test "dhealth does not turn a multi-line output into extra probes" {
    # Two probes recorded; a split on newline would invent a third out of
    # "second line of the error".
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" != *"second line"* ]]
    [ "$(printf '%s\n' "$output" | grep -c 'exit ')" = "2" ]
}

@test "dhealth reads the clock out of docker's typed time format" {
    run out_of "$WORK" 'dhealth fx-db'
    [[ "$output" == *"22:57:28  exit 1"* ]]
    [[ "$output" == *"22:57:20  exit 0"* ]]
}

@test "dhealth on one healthy match exits 0" {
    run rc_of "$WORK" 'dhealth fx-api'
    [ "$output" = "0" ]
}

@test "dhealth on one unhealthy match exits 1" {
    run rc_of "$WORK" 'dhealth fx-db'
    [ "$output" = "1" ]
}

@test "dhealth says when no probe has run yet" {
    run out_of "$WORK" 'dhealth other-api'
    [[ "$output" == *"no probes recorded yet"* ]]
}

@test "dhealth says a container has no healthcheck instead of showing nothing" {
    run out_of "$WORK" 'dhealth plain-box'
    [[ "$output" == *"has no healthcheck"* ]]
}

@test "dhealth exits 1 for a container with no healthcheck" {
    run rc_of "$WORK" 'dhealth plain-box'
    [ "$output" = "1" ]
}

# --- completion -------------------------------------------------------------

@test "dhealth completes running container names" {
    run complete_in "$WORK" 1 dhealth ''
    [[ "$output" == *"fx-api"* ]]
}

@test "dhealth offers nothing after the pattern" {
    run complete_in "$WORK" 2 dhealth fx-api ''
    [ -z "$output" ]
}
