#!/usr/bin/env bats
# dnet — networks, their subnets, and what uses them.
#
# The shim's network world has one network per USE state:
#   fixture-proj_default   2 running containers
#   other-proj_default     none running, but a stopped container points at it
#   orphan-net             nothing points at it (and it is internal)
#   bridge, host, none     built in

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dnet --help shows usage" {
    run in_dir "$WORK" 'dnet --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dnet -h shows usage" {
    run in_dir "$WORK" 'dnet -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dnet exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dnet -z'
    [ "$output" = "1" ]
}

@test "dnet takes one pattern at a time" {
    run rc_of "$WORK" 'dnet a b'
    [ "$output" = "1" ]
}

# --- the four USE states ----------------------------------------------------

@test "dnet counts the containers running on a network" {
    run out_of "$WORK" 'dnet fixture-proj_default'
    [[ "$output" == *"2 running"* ]]
}

@test "dnet calls a network held only by stopped containers 'stopped'" {
    run out_of "$WORK" 'dnet other-proj_default'
    [[ "$output" == *"stopped"* ]]
}

@test "dnet does not call a network held by stopped containers 'unused'" {
    # The reason this command exists. A stopped container still points at its
    # network, so a prune keeps it. Measured on a real host: 23 networks had
    # nothing running and all 23 were held by stopped containers. Calling them
    # unused would promise 23 deletions and deliver zero.
    run out_of "$WORK" 'dnet other-proj_default'
    [[ "$output" != *"unused"* ]]
}

@test "dnet calls a network nothing points at 'unused'" {
    run out_of "$WORK" 'dnet orphan-net'
    [[ "$output" == *"unused"* ]]
}

@test "dnet marks bridge, host and none as built-in" {
    run out_of "$WORK" 'dnet'
    local n
    n=$(printf '%s\n' "$output" | grep -c "built-in")
    [ "$n" -eq 3 ]
}

@test "dnet never calls a built-in network unused" {
    # host and none have no containers and no subnet, and docker will not
    # remove any of the three. They must not look like cleanup candidates.
    run out_of "$WORK" 'dnet -u'
    [[ "$output" != *"bridge "* ]]
    [[ "$output" != *" host"* ]]
    [[ "$output" != *" none"* ]]
}

# --- -u -----------------------------------------------------------------------

@test "dnet -u shows only what a prune would remove" {
    run out_of "$WORK" 'dnet -u'
    [[ "$output" == *"orphan-net"* ]]
    [[ "$output" != *"other-proj_default"* ]]
    [[ "$output" != *"fixture-proj_default"* ]]
}

@test "dnet -u combines with -h in one cluster" {
    run in_dir "$WORK" 'dnet -uh'
    [[ "$output" == *"USAGE"* ]]
}

# --- columns ------------------------------------------------------------------

@test "dnet shows the subnet" {
    run out_of "$WORK" 'dnet fixture-proj_default'
    [[ "$output" == *"172.18.0.0/16"* ]]
}

@test "dnet marks an internal network" {
    run out_of "$WORK" 'dnet orphan-net'
    [[ "$output" == *"internal"* ]]
}

@test "dnet shows the compose project" {
    run out_of "$WORK" 'dnet fixture-proj_default'
    [[ "$output" == *"fixture-proj"* ]]
}

@test "dnet shows a dash for a network with no subnet" {
    run out_of "$WORK" 'dnet ^host$'
    [[ "$output" == *"—"* ]]
}

# --- filtering ----------------------------------------------------------------

@test "dnet filters by subnet" {
    run out_of "$WORK" 'dnet 10.99'
    [[ "$output" == *"orphan-net"* ]]
    [[ "$output" != *"fixture-proj_default"* ]]
}

@test "dnet filters by compose project" {
    run out_of "$WORK" 'dnet other-proj'
    [[ "$output" == *"other-proj_default"* ]]
    [[ "$output" != *"orphan-net"* ]]
}

# --- the tally ----------------------------------------------------------------

@test "dnet tallies every state on stderr" {
    run err_of "$WORK" 'dnet'
    [[ "$output" == *"1 running"* ]]
    [[ "$output" == *"1 held by stopped containers"* ]]
    [[ "$output" == *"1 unused"* ]]
}

@test "dnet's tally counts the whole host even when filtered" {
    # A filter must never make the leftovers look smaller than they are.
    run err_of "$WORK" 'dnet fixture-proj'
    [[ "$output" == *"1 unused"* ]]
}

@test "dnet keeps the tally out of stdout" {
    run out_of "$WORK" 'dnet'
    [[ "$output" != *"held by stopped"* ]]
}

# --- exit codes ---------------------------------------------------------------

@test "dnet exits 1 when a pattern matches nothing" {
    run rc_of "$WORK" 'dnet zzz-nothing'
    [ "$output" = "1" ]
}

@test "dnet exits 0 with no filter" {
    run rc_of "$WORK" 'dnet'
    [ "$output" = "0" ]
}

# --- completion -------------------------------------------------------------

@test "dnet completes network names" {
    run complete_in "$WORK" 1 dnet ''
    [[ "$output" == *"orphan-net"* ]]
}
