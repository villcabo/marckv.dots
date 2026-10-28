#!/usr/bin/env bats
# dvol — volumes, who holds them, and what a cleanup would free.
#
# The shim's volume world has one volume per USE state:
#   fixture-proj_pgdata   mounted by fx-db                  1 running   404MB
#   fixture-proj_cache    mounted by fx-api and fx-db       2 running   12.5MB
#   other-proj_data       only other-api, which has exited  stopped     1.2GB
#   orphan-vol            nothing                           unused      800MB
#   a1b2…(64 hex)         nothing, anonymous                unused      1.5GB
# So a cleanup frees 800MB + 1.5GB = 2.3GB, and must NOT count the 1.2GB held
# by the stopped container.

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dvol --help shows usage" {
    run in_dir "$WORK" 'dvol --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dvol -h shows usage" {
    run in_dir "$WORK" 'dvol -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dvol exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dvol -z'
    [ "$output" = "1" ]
}

@test "dvol takes one pattern at a time" {
    run rc_of "$WORK" 'dvol a b'
    [ "$output" = "1" ]
}

# --- the three USE states ---------------------------------------------------

@test "dvol counts the running containers mounting a volume" {
    run out_of "$WORK" 'dvol fixture-proj_cache'
    [[ "$output" == *"2 running"* ]]
}

@test "dvol calls a volume held only by a stopped container 'stopped'" {
    run out_of "$WORK" 'dvol other-proj_data'
    [[ "$output" == *"stopped"* ]]
}

@test "dvol does not call a volume held by a stopped container 'unused'" {
    # A stopped container still mounts its volume, so a prune keeps it.
    # Calling it unused would promise data a prune will not free.
    run out_of "$WORK" 'dvol other-proj_data'
    [[ "$output" != *"unused"* ]]
}

@test "dvol calls a volume nothing mounts 'unused'" {
    run out_of "$WORK" 'dvol orphan-vol'
    [[ "$output" == *"unused"* ]]
}

@test "dvol names the container holding a volume" {
    run out_of "$WORK" 'dvol fixture-proj_pgdata'
    [[ "$output" == *"fx-db"* ]]
}

@test "dvol names the stopped container holding a volume" {
    # The useful half: it tells you what to remove before the volume can go.
    run out_of "$WORK" 'dvol other-proj_data'
    [[ "$output" == *"other-api"* ]]
}

# --- anonymous volumes --------------------------------------------------------

@test "dvol cuts an anonymous volume's name visibly" {
    run out_of "$WORK" 'dvol anonymous'
    [[ "$output" == *"a1b2c3d4e5f6…"* ]]
}

@test "dvol does not print an anonymous volume's full 64 characters" {
    run out_of "$WORK" 'dvol anonymous'
    [[ "$output" != *"a1b2c3d4e5f6a1b2c3d4e5f6"* ]]
}

@test "dvol labels an anonymous volume in the project column" {
    run out_of "$WORK" 'dvol anonymous'
    [[ "$output" == *"anonymous"* ]]
}

@test "dvol leaves a named volume's name whole" {
    run out_of "$WORK" 'dvol fixture-proj_pgdata'
    [[ "$output" == *"fixture-proj_pgdata"* ]]
    [[ "$output" != *"…"* ]]
}

# --- -u -----------------------------------------------------------------------

@test "dvol -u shows only what a prune would remove" {
    run out_of "$WORK" 'dvol -u'
    [[ "$output" == *"orphan-vol"* ]]
    [[ "$output" != *"other-proj_data"* ]]
    [[ "$output" != *"fixture-proj"* ]]
}

# --- sizes --------------------------------------------------------------------

@test "dvol without -s shows the driver, not a size" {
    run out_of "$WORK" 'dvol'
    [[ "$output" == *"DRIVER"* ]]
    [[ "$output" != *"SIZE"* ]]
}

@test "dvol without -s shows USED BY once, not twice" {
    # The first draft put the holder in column 5 as well as column 4.
    run out_of "$WORK" 'dvol'
    local n
    n=$(printf '%s\n' "$output" | grep -o "USED BY" | wc -l)
    [ "$n" -eq 1 ]
}

@test "dvol -s shows each volume's size" {
    run out_of "$WORK" 'dvol -s orphan-vol'
    [[ "$output" == *"SIZE"* ]]
    [[ "$output" == *"800MB"* ]]
}

@test "dvol -s totals exactly what a prune would free" {
    # 800MB + 1.5GB. The 1.2GB held by the stopped container is NOT in it.
    run err_of "$WORK" 'dvol -s'
    [[ "$output" == *"2.3GB reclaimable"* ]]
}

@test "dvol -s does not count a stopped container's volume as reclaimable" {
    run err_of "$WORK" 'dvol -s'
    [[ "$output" != *"3.5GB"* ]]
}

@test "dvol without -s points at -s instead of a total" {
    run err_of "$WORK" 'dvol'
    [[ "$output" == *"add -s"* ]]
}

@test "dvol -us combines in one cluster" {
    run out_of "$WORK" 'dvol -us'
    [[ "$output" == *"SIZE"* ]]
    [[ "$output" != *"fixture-proj"* ]]
}

@test "dvol -s does not land in di's system df answer" {
    # The shim answers dvol's sized call from its own arm, placed BEFORE the
    # plain "system df" arm di uses — and that arm COUNTS its calls, in
    # system-df-calls. If dvol fell through to it, the counter would move.
    # An earlier version of this test just ran di and looked for output,
    # which proved di worked and nothing about where dvol's call went.
    rm -f "$WORK/system-df-calls"
    out_of "$WORK" 'dvol -s' >/dev/null
    [ ! -s "$WORK/system-df-calls" ]
}

# --- the tally and the exit code ----------------------------------------------

@test "dvol tallies every state on stderr" {
    run err_of "$WORK" 'dvol'
    [[ "$output" == *"2 running"* ]]
    [[ "$output" == *"1 held by stopped containers"* ]]
    [[ "$output" == *"2 unused"* ]]
}

@test "dvol keeps the tally out of stdout" {
    run out_of "$WORK" 'dvol'
    [[ "$output" != *"held by stopped"* ]]
}

@test "dvol exits 1 when a pattern matches nothing" {
    run rc_of "$WORK" 'dvol zzz-nothing'
    [ "$output" = "1" ]
}

@test "dvol filters by the holding container" {
    run out_of "$WORK" 'dvol other-api'
    [[ "$output" == *"other-proj_data"* ]]
}

# --- completion -------------------------------------------------------------

@test "dvol completes volume names" {
    run complete_in "$WORK" 1 dvol ''
    [[ "$output" == *"orphan-vol"* ]]
}
