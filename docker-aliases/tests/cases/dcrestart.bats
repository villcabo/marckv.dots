#!/usr/bin/env bats
# dcrestart — docker compose restart, with a preview that says what a restart
# will not do.
#
# Against fixtures/basic (api, worker, db), the shim reports:
#   api     running, created from today's config     -> nothing to warn about
#   worker  exited, created from an OLDER config     -> starts it AND drifted
#   db      no container                             -> restart skips it

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "dcrestart --help shows usage" {
    run in_dir "$F/basic" 'dcrestart --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dcrestart --help lists what a restart does not do" {
    run in_dir "$F/basic" 'dcrestart --help'
    [[ "$output" == *"does not apply a changed compose file"* ]]
}

@test "dcrestart exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dcrestart -z'
    [ "$output" = "1" ]
}

@test "dcrestart -t requires a number" {
    run rc_of "$F/basic" 'dcrestart -t soon'
    [ "$output" = "1" ]
}

@test "dcrestart exits 1 when no service matches" {
    run rc_of "$F/basic" 'dcrestart zzz'
    [ "$output" = "1" ]
}

@test "dcrestart lists the services when none matches" {
    run in_dir "$F/basic" 'dcrestart zzz'
    [[ "$output" == *"available:"*"api"* ]]
}

# --- the command --------------------------------------------------------------

@test "dcrestart with no pattern restarts the whole project" {
    run argv_of "$F/basic" 'dcrestart'
    [[ "$output" == *"[restart]" ]]
}

@test "dcrestart passes matched services to compose" {
    run argv_of "$F/basic" 'dcrestart api'
    [[ "$output" == *"[restart] [api]" ]]
}

@test "dcrestart passes -t through" {
    run argv_of "$F/basic" 'dcrestart -t 30 api'
    [[ "$output" == *"[restart] [-t] [30] [api]" ]]
}

@test "dcrestart uses the resolved compose file" {
    run argv_of "$F/basic" 'dcrestart api'
    [[ "$output" == *"[-f] [docker-compose.yml]"* ]]
}

# --- what a restart will not do -------------------------------------------------

@test "dcrestart warns when a service changed since it was created" {
    run declined "$F/basic" 'dcrestart worker'
    [[ "$output" == *"worker changed in the compose file"* ]]
    [[ "$output" == *"dcup worker"* ]]
}

@test "dcrestart does not warn about a service built from today's config" {
    # api's creation hash IS today's: no drift to report.
    run declined "$F/basic" 'dcrestart api'
    [[ "$output" != *"changed in the compose file"* ]]
}

@test "dcrestart warns that a stopped service will be started" {
    run declined "$F/basic" 'dcrestart worker'
    [[ "$output" == *"worker is stopped — a restart starts it too"* ]]
}

@test "dcrestart does not call a running service stopped" {
    run declined "$F/basic" 'dcrestart api'
    [[ "$output" != *"is stopped"* ]]
}

@test "dcrestart warns about a service with no container" {
    run declined "$F/basic" 'dcrestart'
    [[ "$output" == *"db has no container"* ]]
}

@test "dcrestart refuses when none of the services has a container" {
    # compose would skip db silently and exit 0; this says so instead.
    run in_dir "$F/basic" 'export DOCKER_ALIASES_AUTO_YES=1; dcrestart db'
    [[ "$output" == *"no container exists for: db"* ]]
    [[ "$output" != *"ARGV:"* ]]
}

@test "dcrestart exits 1 when none of the services has a container" {
    run rc_of "$F/basic" 'dcrestart db'
    [ "$output" = "1" ]
}

# --- preview and confirmation ---------------------------------------------------

@test "dcrestart previews the services it affects" {
    run declined "$F/basic" 'dcrestart'
    [[ "$output" == *"compose restart"* ]]
    # Sorted, as compose discovery returns them — not declaration order.
    [[ "$output" == *"api db worker"* ]]
}

@test "dcrestart runs on yes" {
    run answer "$F/basic" yes 'dcrestart api'
    [ "$output" = "ACCEPT" ]
}

@test "dcrestart does not run on y" {
    run answer "$F/basic" y 'dcrestart api'
    [ "$output" = "REJECT" ]
}

@test "dcrestart keeps the preview out of stdout" {
    # </dev/null: out_of gives no stdin, and the prompt would wait forever on
    # an open one — it hung a background run until it was killed.
    run out_of "$F/basic" 'dcrestart api </dev/null'
    [[ "$output" != *"compose restart"* ]]
}

# --- completion -------------------------------------------------------------

@test "dcrestart completes services" {
    run complete_in "$F/basic" 1 dcrestart ''
    [[ "$output" == *"worker"* ]]
}

@test "dcrestart completes its flags" {
    run complete_in "$F/basic" 1 dcrestart '-'
    [[ "$output" == *"-t"* ]]
}
