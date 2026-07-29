#!/usr/bin/env bats
# dclt — tail compose logs for services matched by regex.

load '../helpers/common'

# --- help -------------------------------------------------------------------

@test "dclt --help shows usage" {
    run in_dir "$F/basic" 'dclt --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dclt --help documents the bare number" {
    run in_dir "$F/basic" 'dclt --help'
    [[ "$output" == *"dclt 500 api"* ]]
}

@test "dclt --help says patterns are regex" {
    run in_dir "$F/basic" 'dclt --help'
    [[ "$output" == *"regular expressions"* ]]
}

# --- matching ---------------------------------------------------------------
#
# The old version matched EXACTLY unless you remembered -r, so `dclt api`
# silently matched nothing when the service was called api-worker.

@test "dclt with no pattern follows every service" {
    run out_of "$F/basic" 'dclt'
    [[ "$output" == *"[api] [db] [worker]"* ]]
}

@test "dclt treats a plain word as a regex" {
    run out_of "$F/basic" 'dclt api'
    [[ "$output" == *"[--follow] [api]"* ]]
}

@test "dclt alternation matches the first branch" {
    run out_of "$F/basic" "dclt 'api|db'"
    [[ "$output" == *"[api]"* ]]
}

@test "dclt alternation matches the second branch" {
    run out_of "$F/basic" "dclt 'api|db'"
    [[ "$output" == *"[db]"* ]]
}

@test "dclt alternation excludes what it does not match" {
    run out_of "$F/basic" "dclt 'api|db'"
    [[ "$output" != *"[worker]"* ]]
}

@test "dclt honours an anchored pattern" {
    run out_of "$F/basic" "dclt '^api\$'"
    [[ "$output" == *"[--follow] [api]"* ]]
}

# Services are iterated on the outside, so a service matched twice is added
# once and no dedupe pass is needed.
@test "dclt overlapping patterns do not duplicate a service" {
    run out_of "$F/basic" "dclt api 'ap'"
    [ "$(printf '%s' "$output" | grep -o '\[api\]' | wc -l | tr -d ' ')" = "1" ]
}

# --- line count -------------------------------------------------------------

@test "dclt tails 100 lines by default" {
    run out_of "$F/basic" 'dclt'
    [[ "$output" == *"[--tail] [100]"* ]]
}

@test "dclt takes a bare number as the line count" {
    run out_of "$F/basic" 'dclt 500 api'
    [[ "$output" == *"[--tail] [500]"* ]]
}

@test "dclt -n sets the line count too" {
    run out_of "$F/basic" 'dclt -n 500 api'
    [[ "$output" == *"[--tail] [500]"* ]]
}

@test "dclt -n all passes 'all' through" {
    run out_of "$F/basic" 'dclt -n all'
    [[ "$output" == *"[--tail] [all]"* ]]
}

# --- flags ------------------------------------------------------------------

@test "dclt follows by default" {
    run out_of "$F/basic" 'dclt api'
    [[ "$output" == *"[--follow]"* ]]
}

@test "dclt -o drops --follow" {
    run out_of "$F/basic" 'dclt -o api'
    [[ "$output" != *"[--follow]"* ]]
}

@test "dclt -ot still applies timestamps" {
    run out_of "$F/basic" 'dclt -ot api'
    [[ "$output" == *"[--timestamps]"* ]]
}

@test "dclt -ot still suppresses follow" {
    run out_of "$F/basic" 'dclt -ot api'
    [[ "$output" != *"[--follow]"* ]]
}

@test "dclt -s emits --since" {
    run out_of "$F/basic" 'dclt -s 10m'
    [[ "$output" == *"[--since] [10m]"* ]]
}

@test "dclt emits --env-file before the logs subcommand" {
    run out_of "$F/envfile" 'dclt -e .env.prod'
    [[ "$output" == *"[--env-file] [.env.prod]"*"[logs]"* ]]
}

@test "dclt -f selects the compose file" {
    run out_of "$F/multifile" 'dclt -f base.yml'
    [[ "$output" == *"[-f] [base.yml]"* ]]
}

# --- output streams ---------------------------------------------------------
#
# The whole point of -o is piping. A preview on stdout would poison it.

@test "dclt keeps the preview off stdout" {
    run out_of "$F/basic" 'dclt -o api'
    [[ "$output" != *"compose logs"* ]]
}

@test "dclt puts the log output on stdout" {
    run out_of "$F/basic" 'dclt -o api'
    [[ "$output" == *"ARGV:"* ]]
}

@test "dclt puts the preview on stderr" {
    run err_of "$F/basic" 'dclt -o api'
    [[ "$output" == *"compose logs"* ]]
}

@test "dclt shows the real command in the preview" {
    run err_of "$F/basic" 'dclt -o api'
    [[ "$output" == *"docker compose"* ]]
}

# --- errors -----------------------------------------------------------------

@test "dclt exits 1 when nothing matches" {
    run rc_of "$F/basic" 'dclt zzz'
    [ "$output" = "1" ]
}

@test "dclt exits 1 on a non-numeric line count" {
    run rc_of "$F/basic" 'dclt -n abc'
    [ "$output" = "1" ]
}

@test "dclt exits 1 when -n has no value" {
    run rc_of "$F/basic" 'dclt -n'
    [ "$output" = "1" ]
}

@test "dclt exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dclt -Z'
    [ "$output" = "1" ]
}

@test "dclt lists what was available when nothing matches" {
    run err_of "$F/basic" 'dclt zzz'
    [[ "$output" == *"available:"* ]]
}

@test "dclt names the available services" {
    run err_of "$F/basic" 'dclt zzz'
    [[ "$output" == *"worker"* ]]
}

# --- read-only --------------------------------------------------------------
#
# dclt must never prompt: it changes nothing. With no stdin, a prompt would
# hang or fail rather than sail through unnoticed.

@test "dclt runs with no stdin at all" {
    run out_of "$F/basic" 'dclt api </dev/null'
    [[ "$output" == *"ARGV:"* ]]
}

@test "dclt never asks for confirmation" {
    run in_dir "$F/basic" 'dclt api </dev/null'
    [[ "$output" != *"[yes/N]"* ]]
}
