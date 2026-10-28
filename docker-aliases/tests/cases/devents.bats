#!/usr/bin/env bats
# devents — what happened to a container, and why.
#
# The shim's world, with times relative to now:
#   fx-api     running for 2h, healthy                         "started"
#   fx-db      exited 137, OOMKilled, 5 min ago                "out of memory"
#   other-api  exited 3, on-failure:3 all used, 10 min ago     "gave up"
#   plain-box  exited 137, not OOM, unless-stopped, 3 days ago, still carrying
#              the "unhealthy" it had while it ran
#
# The event buffer wraps fx-db's kill/oom/die in noise: a healthcheck exec, a
# network event, another container.

load '../helpers/common'

# --- help and parsing -------------------------------------------------------

@test "devents --help shows usage" {
    run in_dir "$WORK" 'devents --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "devents --help explains why it does not trust docker events" {
    run in_dir "$WORK" 'devents --help'
    [[ "$output" == *"256 events"* ]]
}

@test "devents exits 1 on an unknown flag" {
    run rc_of "$WORK" 'devents -z'
    [ "$output" = "1" ]
}

@test "devents takes one pattern at a time" {
    run rc_of "$WORK" 'devents a b'
    [ "$output" = "1" ]
}

@test "devents exits 1 when no container matches" {
    run rc_of "$WORK" 'devents zzz-nothing'
    [ "$output" = "1" ]
}

# --- the table ----------------------------------------------------------------

@test "devents lists what happened in the last 24 hours" {
    run out_of "$WORK" 'devents'
    [[ "$output" == *"fx-api"* ]]
    [[ "$output" == *"fx-db"* ]]
    [[ "$output" == *"other-api"* ]]
}

@test "devents leaves out a container untouched for days" {
    run out_of "$WORK" 'devents'
    [[ "$output" != *"plain-box"* ]]
}

@test "devents ignores the stale health of a stopped container" {
    # plain-box stopped three days ago and still reports "unhealthy" — docker
    # keeps the last health a container had. It must not drag it into today.
    run out_of "$WORK" 'devents'
    [[ "$output" != *"plain-box"* ]]
    [[ "$output" != *"unhealthy"* ]]
}

@test "devents -a shows every container" {
    run out_of "$WORK" 'devents -a'
    [[ "$output" == *"plain-box"* ]]
    [[ "$output" == *"4 of 4"* ]]
}

@test "devents puts the newest first" {
    run out_of "$WORK" 'devents'
    local order
    order=$(printf '%s\n' "$output" | sed -n '3,$p' | awk '{print $NF}' | tr '\n' ' ')
    [ "$order" = "fx-db other-api fx-api " ]
}

@test "devents says how long ago each thing happened" {
    run out_of "$WORK" 'devents'
    [[ "$output" == *"5m    exited"*"fx-db"* ]]
    [[ "$output" == *"2h    running"*"fx-api"* ]]
}

@test "devents names an OOM kill as such" {
    run out_of "$WORK" 'devents'
    [[ "$output" == *"out of memory"*"fx-db"* ]]
}

@test "devents says when docker gave up restarting" {
    run out_of "$WORK" 'devents'
    [[ "$output" == *"gave up after 3 restarts"*"other-api"* ]]
}

@test "devents shows no exit code for a running container" {
    run out_of "$WORK" 'devents'
    [[ "$output" == *"running  —"*"fx-api"* ]]
}

@test "devents counts what it left out" {
    run err_of "$WORK" 'devents'
    [[ "$output" == *"1 untouched in 24h"* ]]
}

@test "devents with a pattern matching several shows them all, however old" {
    # The window tames the whole host; a pattern already did the taming.
    # "a" matches fx-api, other-api and plain-box: several, so the table.
    run out_of "$WORK" 'devents a'
    [[ "$output" == *"plain-box"* ]]
}

@test "devents keeps the footer out of stdout" {
    run out_of "$WORK" 'devents'
    [[ "$output" != *"devents <name>"* ]]
}

# --- choosing one -------------------------------------------------------------

@test "devents picks a container whose name IS the pattern" {
    # fx-api-worker also matches "fx-api"; the exact name still wins, so the
    # answer is a story and not a two-row table.
    run in_dir "$WORK" 'export DAV2_EXTRA_CONTAINER=fx-api-worker; devents fx-api'
    [[ "$output" == *"story"* ]]
    [[ "$output" != *"what happened"* ]]
}

# --- the story ----------------------------------------------------------------

@test "devents story explains an OOM kill" {
    run out_of "$WORK" 'devents fx-db'
    [[ "$output" == *"why       out of memory — the OOM killer"* ]]
}

@test "devents story explains a 137 that was not the OOM killer" {
    run out_of "$WORK" 'devents plain-box'
    [[ "$output" == *"killed (SIGKILL)"* ]]
    [[ "$output" == *"not the OOM killer"* ]]
}

@test "devents story does not say 'not the OOM killer' when it was" {
    run out_of "$WORK" 'devents fx-db'
    [[ "$output" != *"not the OOM killer"* ]]
}

@test "devents story reads a stopped always-restart container as stopped on purpose" {
    # unless-stopped would have restarted a crash, so a stopped one was stopped.
    run out_of "$WORK" 'devents plain-box'
    [[ "$output" == *"stopped on purpose"* ]]
}

@test "devents story says docker gave up on an exhausted on-failure policy" {
    run out_of "$WORK" 'devents other-api'
    [[ "$output" == *"docker gave up: 3 restarts used of 3"* ]]
    [[ "$output" == *"policy on-failure:3"* ]]
}

@test "devents story shows how long it lived" {
    # other-api started 620 s before now and ended 600 s before: up 20 s.
    run out_of "$WORK" 'devents other-api'
    [[ "$output" == *"up 20s"* ]]
    [[ "$output" == *"(10m ago)"* ]]
}

@test "devents story shows the image it ran" {
    run out_of "$WORK" 'devents other-api'
    [[ "$output" == *"from quay.io/example/api:1.2.3"* ]]
}

@test "devents story shows a dead container's last log lines" {
    run out_of "$WORK" 'devents other-api'
    [[ "$output" == *"last log lines"* ]]
    [[ "$output" == *"cannot connect to db:5432"* ]]
}

@test "devents story gives each log line its own time" {
    # Every timestamp on screen comes back from ONE date call, read as a queue.
    # Miscount anything before the logs and these clocks shift onto the wrong
    # lines — this is the test that would see it.
    #
    # Checked on the line itself. A glob over the whole output passed with the
    # queue broken: the shifted "22:57" landed on an EVENT line above the log,
    # and *22:57*cannot connect* matched across the two.
    run out_of "$WORK" 'devents other-api'
    [[ "$(printf '%s\n' "$output" | grep 'cannot connect')" == *"22:57"* ]]
    [[ "$(printf '%s\n' "$output" | grep 'giving up')" == *"22:58"* ]]
}

@test "devents story shows no logs for a container running fine" {
    run out_of "$WORK" 'devents fx-api'
    [[ "$output" != *"last log lines"* ]]
}

@test "devents story shows the health of a running container" {
    run out_of "$WORK" 'devents fx-api'
    [[ "$output" == *"health    healthy"* ]]
}

@test "devents story hides the stale health of a stopped container" {
    run out_of "$WORK" 'devents plain-box'
    [[ "$output" != *"health"* ]]
}

@test "devents story shows the container's recent events" {
    run out_of "$WORK" 'devents fx-db'
    [[ "$output" == *"kill     SIGKILL"* ]]
    [[ "$output" == *"oom      out of memory"* ]]
    [[ "$output" == *"die      exit 137"* ]]
}

@test "devents story drops healthcheck probes and other containers' events" {
    run out_of "$WORK" 'devents fx-db'
    [[ "$output" != *"exec_"* ]]
    [[ "$output" != *"pg_isready"* ]]
    [[ "$output" != *"connect"* ]]
    # other-api's start, as an event line. Not a bare "start ": that string
    # lives inside "restart   policy" on every story.
    # Asserted on the grep's output, not with `! grep`: bats' errexit ignores
    # a negated command anywhere but the last line.
    [ -z "$(printf '%s\n' "$output" | grep -E '[0-9]{2}:[0-9]{2}(:[0-9]{2})?  start')" ]
}

@test "devents story says how far back the event buffer reaches" {
    # The oldest event in the buffer is 30 s old — of ANY container. That is
    # the honest reach, and the reason the story does not rest on events.
    run out_of "$WORK" 'devents fx-db'
    [[ "$output" == *"reaches back 30s"* ]]
}

@test "devents story says plainly when no event reaches back far enough" {
    run out_of "$WORK" 'devents plain-box'
    [[ "$output" == *"none in that window"* ]]
}

@test "devents story exits 1 for a container that is down" {
    run rc_of "$WORK" 'devents fx-db'
    [ "$output" = "1" ]
}

@test "devents story exits 0 for a container that is up" {
    run rc_of "$WORK" 'devents fx-api'
    [ "$output" = "0" ]
}

# --- -f -------------------------------------------------------------------

@test "devents -f follows one container without repeating its name" {
    run out_of "$WORK" 'devents -f fx-db'
    [[ "$output" == *"kill     SIGTERM"* ]]
    [[ "$output" == *"die      exit 143 — stopped (SIGTERM)"* ]]
}

@test "devents -f hides healthcheck probes" {
    run out_of "$WORK" 'devents -f fx-db'
    [[ "$output" != *"exec_"* ]]
    [[ "$output" != *"pg_isready"* ]]
}

@test "devents -f with no pattern follows the host and names each container" {
    run out_of "$WORK" 'devents -f'
    [[ "$output" == *"fx-db"*"kill"* ]]
    [[ "$output" == *"other-api"*"start"* ]]
}

@test "devents -f refuses a pattern matching several" {
    run rc_of "$WORK" 'devents -f api'
    [ "$output" = "1" ]
}

# --- completion -------------------------------------------------------------

@test "devents completes stopped containers too" {
    # A post-mortem is about the dead.
    run complete_in "$WORK" 1 devents ''
    [[ "$output" == *"plain-box"* ]]
}

@test "devents completes its flags" {
    run complete_in "$WORK" 1 devents '-'
    [[ "$output" == *"-f"* ]]
}
