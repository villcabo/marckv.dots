#!/usr/bin/env bats
# dip — which container has this IP.
#
# The shim's world carries the three traps dip exists to get right:
#   fx-api 172.18.0.5   and   fx-db 172.18.0.50      a substring match lies
#   other-api 172.180.0.7                            172.18 must not catch it
#   plain-box on the host network                    docker says "invalid IP"
# Every trap is tested from both sides: what must be found, and what must not.

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dip --help shows usage" {
    run in_dir "$WORK" 'dip --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dip -h shows usage" {
    run in_dir "$WORK" 'dip -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dip exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dip -z'
    [ "$output" = "1" ]
}

@test "dip takes one query at a time" {
    run rc_of "$WORK" 'dip 172.18.0.5 172.18.0.50'
    [ "$output" = "1" ]
}

# --- a full address matches exactly -----------------------------------------

@test "dip finds the container behind a full address" {
    run out_of "$WORK" 'dip 172.18.0.5'
    [[ "$output" == *"fx-api"* ]]
}

@test "dip does not let 172.18.0.5 match 172.18.0.50" {
    # The reason this command matches full addresses exactly. As a substring,
    # .5 is a prefix of .50, and a log line about one would blame the other.
    run out_of "$WORK" 'dip 172.18.0.5'
    [[ "$output" != *"fx-db"* ]]
    [[ "$output" != *"172.18.0.50"* ]]
}

@test "dip finds 172.18.0.50 on its own" {
    run out_of "$WORK" 'dip 172.18.0.50'
    [[ "$output" == *"fx-db"* ]]
    [[ "$output" != *"fx-api"* ]]
}

# --- a partial address is a subnet, on an octet boundary --------------------

@test "dip treats a partial address as a subnet" {
    run out_of "$WORK" 'dip 172.18.0'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"fx-db"* ]]
}

@test "dip does not let 172.18 match 172.180" {
    run out_of "$WORK" 'dip 172.18'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" != *"other-api"* ]]
}

@test "dip accepts a partial address with a trailing dot" {
    run out_of "$WORK" 'dip 172.18.0.'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"fx-db"* ]]
}

# --- the host network ---------------------------------------------------------

@test "dip shows the host network's address as a dash" {
    run out_of "$WORK" 'dip plain-box'
    [[ "$output" == *"plain-box"* ]]
    [[ "$output" == *"host"* ]]
}

@test "dip never prints docker's 'invalid IP' as an address" {
    # docker 29 reports a host-network container's IPAddress as the literal
    # text "invalid IP". Measured. Printed raw, it reads as an address.
    run out_of "$WORK" 'dip'
    [[ "$output" != *"invalid IP"* ]]
}

# --- one row per network ----------------------------------------------------

@test "dip shows one row per network a container is on" {
    run out_of "$WORK" 'dip fx-api'
    [[ "$output" == *"172.18.0.5"* ]]
    [[ "$output" == *"10.10.0.5"* ]]
}

@test "dip matches text against the network name" {
    run out_of "$WORK" 'dip shared'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" != *"fx-db"* ]]
}

# --- the table and the exit code --------------------------------------------

@test "dip with no query lists every address" {
    run out_of "$WORK" 'dip'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"other-api"* ]]
    [[ "$output" == *"plain-box"* ]]
}

@test "dip counts the rows honestly" {
    # Five rows in the world: fx-api has two networks, the other three one.
    run out_of "$WORK" 'dip 172.18.0.5'
    [[ "$output" == *"1 of 5"* ]]
}

@test "dip exits 1 when the address belongs to nobody" {
    # So a script can ask: dip 10.0.0.9 || echo "address is free"
    run rc_of "$WORK" 'dip 192.0.2.99'
    [ "$output" = "1" ]
}

@test "dip exits 0 when it found something" {
    run rc_of "$WORK" 'dip 172.18.0.5'
    [ "$output" = "0" ]
}

@test "dip prints its table on stdout, so it can be piped" {
    run out_of "$WORK" 'dip 172.18.0.5'
    [[ "$output" == *"fx-api"* ]]
}

# --- completion -------------------------------------------------------------

@test "dip completes container names" {
    run complete_in "$WORK" 1 dip ''
    [[ "$output" == *"fx-api"* ]]
}
