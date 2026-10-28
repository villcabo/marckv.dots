#!/usr/bin/env bats
# drestart — restart running containers by name, host-wide.
#
# The shim's running containers: fx-api and fx-db (fixture-proj), other-api
# (other-proj). plain-box exists but is EXITED, so it is only found by the
# "is it stopped?" lookup on the error path.

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "drestart --help shows usage" {
    run in_dir "$WORK" 'drestart --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "drestart exits 1 on an unknown flag" {
    run rc_of "$WORK" 'drestart -z fx-api'
    [ "$output" = "1" ]
}

@test "drestart takes one pattern at a time" {
    run rc_of "$WORK" 'drestart fx-api fx-db'
    [ "$output" = "1" ]
}

@test "drestart -t requires a number" {
    run rc_of "$WORK" 'drestart -t soon fx-api'
    [ "$output" = "1" ]
}

# --- the pattern ----------------------------------------------------------------

@test "drestart without a pattern restarts nothing" {
    # There is no restart-everything default.
    run in_dir "$WORK" 'export DOCKER_ALIASES_AUTO_YES=1; drestart'
    [[ "$output" != *"ARGV:"* ]]
    [[ "$output" == *"a pattern is required"* ]]
}

@test "drestart without a pattern exits 1" {
    run rc_of "$WORK" 'drestart'
    [ "$output" = "1" ]
}

@test "drestart restarts every running container the pattern matches" {
    run argv_of "$WORK" 'drestart api'
    [ "$output" = "ARGV: [restart] [fx-api] [other-api]" ]
}

@test "drestart with a name that IS a container restarts only that one" {
    # fx-api-worker also matches "fx-api" — and must be left running.
    run argv_of "$WORK" 'export DAV2_EXTRA_CONTAINER=fx-api-worker; drestart fx-api'
    [ "$output" = "ARGV: [restart] [fx-api]" ]
}

@test "drestart passes -t through to docker" {
    run argv_of "$WORK" 'drestart -t 30 fx-db'
    [ "$output" = "ARGV: [restart] [-t] [30] [fx-db]" ]
}

@test "drestart accepts -t glued to its value" {
    run argv_of "$WORK" 'drestart -t5 fx-db'
    [ "$output" = "ARGV: [restart] [-t] [5] [fx-db]" ]
}

@test "drestart exits 1 when nothing running matches" {
    run rc_of "$WORK" 'drestart zzz-nothing'
    [ "$output" = "1" ]
}

@test "drestart names a stopped match and how to start it" {
    run in_dir "$WORK" 'drestart plain-box'
    [[ "$output" == *"matches stopped container(s)"* ]]
    [[ "$output" == *"docker start plain-box"* ]]
    [[ "$output" != *"ARGV:"* ]]
}

# --- preview and confirmation ---------------------------------------------------

@test "drestart previews every container it will restart" {
    run declined "$WORK" 'drestart api'
    [[ "$output" == *"2 container(s)"* ]]
    [[ "$output" == *"fx-api  fixture-proj/api"* ]]
    [[ "$output" == *"other-api  other-proj/api"* ]]
}

@test "drestart shows the real command in the preview" {
    run declined "$WORK" 'drestart -t 3 fx-db'
    [[ "$output" == *"docker restart -t 3 fx-db"* ]]
}

@test "drestart warns that compose containers keep their old config" {
    run declined "$WORK" 'drestart api'
    [[ "$output" == *"2 from compose"* ]]
    [[ "$output" == *"dcup applies a changed compose file"* ]]
}

@test "drestart says nothing about compose for a container compose did not make" {
    run declined "$WORK" 'export DAV2_EXTRA_CONTAINER=lone-box; drestart lone-box'
    [[ "$output" != *"from compose"* ]]
}

@test "drestart asks how many it will restart" {
    run declined "$WORK" 'drestart api'
    [[ "$output" == *"Restart 2 container(s)?"* ]]
}

@test "drestart runs on yes" {
    run answer "$WORK" yes 'drestart fx-db'
    [ "$output" = "ACCEPT" ]
}

@test "drestart does not run on y" {
    run answer "$WORK" y 'drestart fx-db'
    [ "$output" = "REJECT" ]
}

@test "drestart does not run on Enter" {
    run answer "$WORK" '' 'drestart fx-db'
    [ "$output" = "REJECT" ]
}

@test "drestart keeps the preview out of stdout" {
    # </dev/null: out_of gives no stdin, and the prompt would wait forever on
    # an open one — it hung a background run until it was killed.
    run out_of "$WORK" 'drestart api </dev/null'
    [[ "$output" != *"container(s)"* ]]
}

# --- completion -------------------------------------------------------------

@test "drestart completes running containers" {
    run complete_in "$WORK" 1 drestart ''
    [[ "$output" == *"fx-api"* ]]
}

@test "drestart offers nothing after -t" {
    run complete_in "$WORK" 2 drestart -t ''
    [ -z "$output" ]
}
