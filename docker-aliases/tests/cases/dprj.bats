#!/usr/bin/env bats
# dprj — compose projects on this host.
#
# The shim's project world:
#   fixture-proj  api x2 + db up, two compose files  running   "+1"
#                 3 containers, 2 services — so the two counts differ
#   other-proj    api up, worker exited              partial
#   old-proj      web exited                         stopped
#   tmp-proj      lives under /tmp                   the reboot warning
#   plus one container with no compose labels, which is not a project

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dprj --help shows usage" {
    run in_dir "$WORK" 'dprj --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dprj -h shows usage" {
    run in_dir "$WORK" 'dprj -h'
    [[ "$output" == *"USAGE"* ]]
}

@test "dprj exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dprj -z'
    [ "$output" = "1" ]
}

@test "dprj takes one pattern at a time" {
    run rc_of "$WORK" 'dprj a b'
    [ "$output" = "1" ]
}

# --- the three states ---------------------------------------------------------

@test "dprj calls a project with everything up 'running'" {
    run out_of "$WORK" 'dprj fixture-proj'
    [[ "$output" == *"running"* ]]
    [[ "$output" == *"3/3"* ]]
}

@test "dprj calls a project with some containers down 'partial'" {
    run out_of "$WORK" 'dprj other-proj'
    [[ "$output" == *"partial"* ]]
    [[ "$output" == *"1/2"* ]]
}

@test "dprj hides a fully stopped project by default" {
    # As `docker compose ls` does.
    run out_of "$WORK" 'dprj'
    [[ "$output" != *"old-proj"* ]]
}

@test "dprj -a shows a fully stopped project as 'stopped'" {
    run out_of "$WORK" 'dprj -a old-proj'
    [[ "$output" == *"stopped"* ]]
    [[ "$output" == *"0/1"* ]]
}

@test "dprj says how many stopped projects it hid" {
    run err_of "$WORK" 'dprj'
    [[ "$output" == *"1 stopped, see"* ]]
}

# --- the columns ----------------------------------------------------------------

@test "dprj counts distinct services, not containers" {
    # fixture-proj runs api as two replicas: 3 containers, 2 services. The
    # first fixture had as many services as containers, so this test passed
    # whichever one the code counted — found by trying to make it fail.
    run out_of "$WORK" 'dprj fixture-proj'
    [[ "$output" == *"3/3  running  2"* ]]
}

@test "dprj shows how many compose files came with the first" {
    # "+1" is the override, and seeing it explains why a project does not
    # behave the way its main file says.
    run out_of "$WORK" 'dprj fixture-proj'
    [[ "$output" == *"docker-compose.yml +1"* ]]
}

@test "dprj shows no count for a single compose file" {
    run out_of "$WORK" 'dprj other-proj'
    [[ "$output" == *"compose.yaml "* ]]
    [[ "$output" != *"compose.yaml +"* ]]
}

@test "dprj shows the project directory" {
    run out_of "$WORK" 'dprj other-proj'
    [[ "$output" == *"/srv/other-proj"* ]]
}

@test "dprj ignores containers compose did not create" {
    # The fixture's unlabelled container must not become an empty project.
    run out_of "$WORK" 'dprj -a'
    [[ "$output" == *"4 of 4"* ]]
}

# --- /tmp ---------------------------------------------------------------------

@test "dprj warns about a project living under /tmp" {
    run err_of "$WORK" 'dprj'
    [[ "$output" == *"1 run from /tmp"* ]]
}

@test "dprj counts /tmp projects even when filtered out" {
    # The warning is about the host. A filter that hides the project must not
    # hide the risk.
    run err_of "$WORK" 'dprj fixture-proj'
    [[ "$output" == *"1 run from /tmp"* ]]
}

# --- filtering, output and exit -----------------------------------------------

@test "dprj filters by project name" {
    run out_of "$WORK" 'dprj fixture'
    [[ "$output" == *"fixture-proj"* ]]
    [[ "$output" != *"other-proj"* ]]
}

@test "dprj filters by directory" {
    run out_of "$WORK" 'dprj scratch'
    [[ "$output" == *"tmp-proj"* ]]
}

@test "dprj keeps the footer out of stdout" {
    run out_of "$WORK" 'dprj'
    [[ "$output" != *"containers up"* ]]
    [[ "$output" != *"dcd <name>"* ]]
}

@test "dprj exits 1 when a pattern matches nothing" {
    run rc_of "$WORK" 'dprj zzz-nothing'
    [ "$output" = "1" ]
}

# --- completion -------------------------------------------------------------

@test "dprj completes project names" {
    run complete_in "$WORK" 1 dprj ''
    [[ "$output" == *"fixture-proj"* ]]
}

@test "dprj completion offers no empty project" {
    run complete_in "$WORK" 1 dprj ''
    [[ "$output" != *$'\n\n'* ]]
}
