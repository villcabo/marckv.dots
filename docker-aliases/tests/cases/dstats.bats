#!/usr/bin/env bats
# dstats / dcstats — resource use, against each container's own limits.
#
# The shim's stats world:
#   fx-api     48% under --cpus 0.5, 150MiB/256MiB     at its CPU ceiling
#   fx-db      120% CPU, no memory limit               "∞", over a core
#   other-api  240MiB/256MiB, 95 of 100 pids           near two limits
#   dav2-fixture-basic-{api-1,worker-1,worker-2}       fixtures/basic, scaled

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dstats --help shows usage" {
    run in_dir "$WORK" 'dstats --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dstats --help explains that 100% is one core" {
    run in_dir "$WORK" 'dstats --help'
    [[ "$output" == *"100% is ONE core"* ]]
}

@test "dstats exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dstats -z'
    [ "$output" = "1" ]
}

@test "dstats takes one pattern at a time" {
    run rc_of "$WORK" 'dstats a b'
    [ "$output" = "1" ]
}

# --- numbers against limits -----------------------------------------------------

@test "dstats shows CPU against its limit, in docker's unit" {
    # --cpus 0.5 is a ceiling of 50% where 100% is one core.
    run out_of "$WORK" 'dstats fx-api'
    [[ "$output" == *"48.00% / 50%"* ]]
}

@test "dstats shows CPU alone when there is no CPU limit" {
    run out_of "$WORK" 'dstats fx-db'
    [[ "$output" == *"120.50%  "* ]]
    [[ "$output" != *"120.50% /"* ]]
}

@test "dstats shows infinity for a container with no memory limit" {
    # docker's MEM % would divide by the host's RAM and call it calm.
    run out_of "$WORK" 'dstats fx-db'
    [[ "$output" == *"1.5GiB / ∞"* ]]
    [[ "$output" != *"15.5GiB"* ]]
}

@test "dstats shows memory against a real limit" {
    run out_of "$WORK" 'dstats other-api'
    [[ "$output" == *"240MiB / 256MiB"* ]]
}

@test "dstats shows pids against a limit when there is one" {
    run out_of "$WORK" 'dstats other-api'
    [[ "$output" == *"95 / 100"* ]]
}

@test "dstats shows pids alone when there is no limit" {
    run out_of "$WORK" 'dstats fx-db'
    [[ "$output" == *"∞  40  "* ]]
}

# --- order ----------------------------------------------------------------------

@test "dstats puts rows near a limit first, then by memory" {
    # other-api and fx-api are red (near a limit) and come first, larger
    # memory first; then fx-db's 1.5GiB, then the small fixture containers.
    run out_of "$WORK" 'dstats'
    local order
    order=$(printf '%s\n' "$output" | sed -n '3,$p' | awk '{print $NF}' | tr '\n' ' ')
    [ "$order" = "other-api fx-api fx-db dav2-fixture-basic-worker-2 dav2-fixture-basic-worker-1 dav2-fixture-basic-api-1 " ]
}

# --- colour ---------------------------------------------------------------------

@test "dstats colours a CPU at its ceiling red" {
    run lib_call "$WORK" '_stcpu_color_into "48.00% / 50%"; [[ "$_DA_R" == "$CRE" ]] && echo red'
    [ "$output" = "red" ]
}

@test "dstats colours a CPU at 70% of its ceiling yellow" {
    run lib_call "$WORK" '_stcpu_color_into "36.00% / 50%"; [[ "$_DA_R" == "$CYE" ]] && echo yellow'
    [ "$output" = "yellow" ]
}

@test "dstats colours an unlimited CPU past one core yellow" {
    run lib_call "$WORK" '_stcpu_color_into "120.50%"; [[ "$_DA_R" == "$CYE" ]] && echo yellow'
    [ "$output" = "yellow" ]
}

@test "dstats colours memory near its limit red, across units" {
    # 240MiB of 256MiB is 93.75% — and 1000MiB of 1GiB must parse both units.
    run lib_call "$WORK" '_stmem_color_into "240MiB / 256MiB"; a=$_DA_R; _stmem_color_into "1000MiB / 1GiB"; [[ "$a" == "$CRE" && "$_DA_R" == "$CRE" ]] && echo red'
    [ "$output" = "red" ]
}

@test "dstats colours unbounded memory yellow, never green" {
    run lib_call "$WORK" '_stmem_color_into "384KiB / ∞"; [[ "$_DA_R" == "$CYE" ]] && echo yellow'
    [ "$output" = "yellow" ]
}

@test "dstats reads a percentage with one decimal or none" {
    run lib_call "$WORK" '_dstats_hundredths_into "50.7%"; a=$_DA_R; _dstats_hundredths_into "3%"; echo "$a $_DA_R"'
    [ "$output" = "5070 300" ]
}

# --- alignment ------------------------------------------------------------------
#
# What the first version got wrong, and what was visible at a glance: docker
# prints "33.1MiB", "30.07MiB", "8.184MiB", the cells were its strings, and the
# " / " wandered from row to row.

@test "dstats puts every MEM ' / ' in the same column" {
    run out_of "$WORK" 'dstats'
    local cols
    cols=$(printf '%s\n' "$output" | sed -n '3,$p' | awk '{ i = index($0, "iB / "); print i }' | sort -u | wc -l)
    [ "$cols" = "1" ]
}

@test "dstats right-aligns CPU so the percent signs line up" {
    run out_of "$WORK" 'dstats'
    local cols
    cols=$(printf '%s\n' "$output" | sed -n '3,$p' | awk '{ print index($0, "%") }' | sort -u | wc -l)
    [ "$cols" = "1" ]
}

@test "dstats shows memory in one precision, not docker's" {
    # worker-2 comes from docker as "30.07MiB". Right-alignment alone would
    # still line up the " / " — this is what catches the raw string coming back.
    run out_of "$WORK" 'dstats'
    [[ "$output" == *"30.1MiB / 512MiB"* ]]
    [[ "$output" != *"30.07MiB"* ]]
}

@test "dstats re-formats memory instead of echoing docker's precision" {
    run lib_call "$WORK" 'for b in 8581545 1610612736 157286400 512; do _dstats_ibytes_into $b; printf "%s " "$_DA_R"; done'
    [ "$output" = "8.2MiB 1.5GiB 150MiB 512B " ]
}

@test "dstats shows a round limit without a decimal" {
    run lib_call "$WORK" 'for b in 536870912 1073741824 1610612736; do _dstats_ibytes_into $b exact; printf "%s " "$_DA_R"; done'
    [ "$output" = "512MiB 1GiB 1.5GiB " ]
}

@test "dstats measures alignment by display width, not bytes" {
    # "∞" is three bytes; under a C locale ${#x} counts all three.
    run lib_call "$WORK" '_dstats_rjust_into "∞" 4; printf "[%s]" "$_DA_R"'
    [ "$output" = "[   ∞]" ]
}

# --- colour: only what needs a look --------------------------------------------

@test "dstats leaves an ordinary figure uncoloured" {
    # Every colour here is bold. Painting ordinary values bold white made the
    # one near its limit impossible to spot among them.
    run lib_call "$WORK" '_stmem_color_into " 20.0MiB / 512MiB"; a=$_DA_R; _stcpu_color_into " 0.50%"; b=$_DA_R; _stpids_color_into " 3"; [[ -z "$a$b$_DA_R" ]] && echo plain'
    [ "$output" = "plain" ]
}

@test "dstats colours a padded cell the same as a bare one" {
    run lib_call "$WORK" '_stmem_color_into " 240MiB / 256MiB"; [[ "$_DA_R" == "$CRE" ]] && echo red'
    [ "$output" = "red" ]
}

# --- footer ---------------------------------------------------------------------

@test "dstats counts the containers with no memory limit" {
    run err_of "$WORK" 'dstats'
    [[ "$output" == *"2 with no memory limit"* ]]
}

@test "dstats sums memory in the same binary units as the table" {
    # 150 + 1536 + 240 + 20 + 30 + 30.07 ≈ 2006MiB; the host has 16e9 bytes.
    run err_of "$WORK" 'dstats'
    [[ "$output" == *"use 2.0GiB of memory (host: 14.9GiB)"* ]]
}

@test "dstats sums CPU against the host's cores" {
    # 48 + 120.5 + 2 + 0.5 + 0.1 + 0.1 = 171.2, of 8 cores.
    run err_of "$WORK" 'dstats'
    [[ "$output" == *"CPU 171.20% of 800% (8 cores)"* ]]
}

@test "dstats keeps the footer out of stdout" {
    run out_of "$WORK" 'dstats'
    [[ "$output" != *"no memory limit"* ]]
}

@test "dstats filters by name" {
    run out_of "$WORK" 'dstats other'
    [[ "$output" == *"other-api"* ]]
    [[ "$output" != *"fx-db"* ]]
    [[ "$output" == *"1 of 6"* ]]
}

# --- watch ----------------------------------------------------------------------

@test "dstats -w redraws the table each round" {
    run in_dir "$WORK" 'export DOCKER_ALIASES_WATCH_ROUNDS=2; dstats -w fx-api'
    [ "$(printf '%s\n' "$output" | grep -c '48.00% / 50%')" = "2" ]
    [[ "$output" == *"Ctrl-C to stop"* ]]
}

# --- dcstats ----------------------------------------------------------------------

@test "dcstats shows only the current project's containers" {
    run out_of "$F/basic" 'dcstats'
    [[ "$output" != *"fx-api"* ]]
    [[ "$output" == *"3 of 3"* ]]
}

@test "dcstats names rows by service, numbering replicas" {
    run out_of "$F/basic" 'dcstats'
    [[ "$output" == *"SERVICE"* ]]
    [[ "$output" == *"worker #2"* ]]
    [[ "$output" == *"  api"* ]]
    [[ "$output" != *"dav2-fixture-basic-api-1"* ]]
}

@test "dcstats does not number the first replica" {
    run out_of "$F/basic" 'dcstats'
    [[ "$output" != *"worker #1"* ]]
}

@test "dcstats filters by service" {
    run out_of "$F/basic" 'dcstats work'
    [[ "$output" == *"worker"* ]]
    [[ "$output" != *"  api"* ]]
    [[ "$output" == *"2 of 3"* ]]
}

@test "dcstats titles the table with the project" {
    run out_of "$F/basic" 'dcstats'
    [[ "$output" == *"compose stats · dav2-fixture-basic"* ]]
}

@test "dcstats exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dcstats -z'
    [ "$output" = "1" ]
}

# --- completion -------------------------------------------------------------

@test "dstats completes running containers" {
    run complete_in "$WORK" 1 dstats ''
    [[ "$output" == *"fx-api"* ]]
}

@test "dcstats completes services" {
    run complete_in "$F/basic" 1 dcstats ''
    [[ "$output" == *"worker"* ]]
}
