#!/usr/bin/env bats
# dcup — bring compose services up.

load '../helpers/common'

# --- help -------------------------------------------------------------------

@test "dcup --help shows usage" {
    run in_dir "$F/basic" 'dcup --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dcup --help documents flag clustering" {
    run in_dir "$F/basic" 'dcup --help'
    [[ "$output" == *"-rpl"* ]]
}

@test "dcup --help states the full-word yes rule" {
    run in_dir "$F/basic" 'dcup --help'
    [[ "$output" == *"full word"* ]]
}

@test "dcup --help advertises no -y escape" {
    run in_dir "$F/basic" 'dcup --help'
    [[ "$output" != *" -y "* ]]
}

# --- preview ----------------------------------------------------------------

@test "dcup previews the action" {
    run declined "$F/basic" 'dcup'
    [[ "$output" == *"compose up"* ]]
}

@test "dcup previews the compose file" {
    run declined "$F/basic" 'dcup'
    [[ "$output" == *"docker-compose.yml"* ]]
}

@test "dcup previews the resolved services" {
    run declined "$F/basic" 'dcup'
    [[ "$output" == *"api"* ]]
}

@test "dcup previews the command it will run" {
    run declined "$F/basic" 'dcup'
    [[ "$output" == *"docker compose"* ]]
}

@test "dcup asks with [yes/N]" {
    run declined "$F/basic" 'dcup'
    [[ "$output" == *"[yes/N]"* ]]
}

# --- flags to argv ----------------------------------------------------------

@test "dcup with no flags runs a plain up -d" {
    run argv_of "$F/basic" 'dcup'
    [[ "$output" == *"[up] [-d]"* ]]
}

@test "dcup -r maps to --force-recreate" {
    run argv_of "$F/basic" 'dcup -r'
    [[ "$output" == *"[--force-recreate]"* ]]
}

@test "dcup -b maps to --build" {
    run argv_of "$F/basic" 'dcup -b'
    [[ "$output" == *"[--build]"* ]]
}

@test "dcup -rpl expands to recreate" {
    run argv_of "$F/basic" 'dcup -rpl api'
    [[ "$output" == *"[--force-recreate]"* ]]
}

@test "dcup -rpl expands to pull" {
    run argv_of "$F/basic" 'dcup -rpl api'
    [[ "$output" == *"[--pull] [always]"* ]]
}

@test "dcup -rpl targets the named service" {
    run argv_of "$F/basic" 'dcup -rpl api'
    [[ "$output" == *"[api]"* ]]
}

@test "dcup -l follows logs afterwards" {
    run argv_of "$F/basic" 'dcup -rpl api'
    [[ "$output" == *"[logs] [-f]"* ]]
}

# --- env files --------------------------------------------------------------

@test "dcup -e emits --env-file" {
    run argv_of "$F/envfile" 'dcup -e .env.prod'
    [[ "$output" == *"[--env-file] [.env.prod]"* ]]
}

# --env-file is an option of `docker compose`, not of `up`. The old
# implementation emitted it after `up`, where docker rejects the command
# outright — so -e never worked at all.
@test "dcup emits --env-file BEFORE the up subcommand" {
    run argv_of "$F/envfile" 'dcup -e .env.prod'
    [[ "$output" == *"[--env-file] [.env.prod]"*"[up]"* ]]
}

# --- multiple compose files -------------------------------------------------

@test "dcup keeps the first -f" {
    run argv_of "$F/multifile" 'dcup -f base.yml -f override.yml'
    [[ "$output" == *"[-f] [base.yml]"* ]]
}

@test "dcup keeps the second -f" {
    run argv_of "$F/multifile" 'dcup -f base.yml -f override.yml'
    [[ "$output" == *"[-f] [override.yml]"* ]]
}

@test "dcup merges services from every -f" {
    run declined "$F/multifile" 'dcup -f base.yml -f override.yml'
    [[ "$output" == *"sidecar"* ]]
}

# --- profiles ---------------------------------------------------------------

@test "dcup -P splits on commas, first profile" {
    run argv_of "$F/profiles" "dcup -P dev,debug"
    [[ "$output" == *"[--profile] [dev]"* ]]
}

@test "dcup -P splits on commas, second profile" {
    run argv_of "$F/profiles" "dcup -P dev,debug"
    [[ "$output" == *"[--profile] [debug]"* ]]
}

@test "dcup accepts -P repeated, first profile" {
    run argv_of "$F/profiles" 'dcup -P dev -P debug'
    [[ "$output" == *"[--profile] [dev]"* ]]
}

@test "dcup accepts -P repeated, second profile" {
    run argv_of "$F/profiles" 'dcup -P dev -P debug'
    [[ "$output" == *"[--profile] [debug]"* ]]
}

# --- quoting ----------------------------------------------------------------

# Building the command as an array rather than a string is what makes this
# hold: with eval, a filename containing a space becomes two arguments.
@test "dcup keeps a filename with a space as one argument" {
    run argv_of "$F/spaces" "dcup -f 'my stack.yml'"
    [[ "$output" == *"[my stack.yml]"* ]]
}

# --- compose file detection -------------------------------------------------

@test "dcup honours DOCKER_COMPOSE_FILE from .env" {
    run declined "$F/detect-env" 'dcup'
    [[ "$output" == *"custom.yml"* ]]
}

# --- errors -----------------------------------------------------------------

@test "dcup exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dcup --bogus'
    [ "$output" = "1" ]
}

@test "dcup exits 1 when -f has no value" {
    run rc_of "$F/basic" 'dcup -f'
    [ "$output" = "1" ]
}

@test "dcup exits 1 when the compose file is missing" {
    run rc_of "$F/basic" 'dcup -f nope.yml'
    [ "$output" = "1" ]
}

@test "dcup exits 1 when declined" {
    run rc_of "$F/basic" 'dcup'
    [ "$output" = "1" ]
}

@test "dcup explains an unknown flag" {
    run declined "$F/basic" 'dcup --bogus'
    [[ "$output" == *"unknown flag"* ]]
}

# --- confirmation -----------------------------------------------------------
#
# The full word is deliberate: dcup recreates and restarts running services,
# and a single keystroke is too easy to hit by accident.

@test "dcup accepts 'yes'" {
    run answer "$F/basic" yes 'dcup'
    [ "$output" = "ACCEPT" ]
}

@test "dcup accepts 'YES'" {
    run answer "$F/basic" YES 'dcup'
    [ "$output" = "ACCEPT" ]
}

@test "dcup accepts 'Yes'" {
    run answer "$F/basic" Yes 'dcup'
    [ "$output" = "ACCEPT" ]
}

@test "dcup rejects a bare 'y'" {
    run answer "$F/basic" y 'dcup'
    [ "$output" = "REJECT" ]
}

@test "dcup rejects 'Y'" {
    run answer "$F/basic" Y 'dcup'
    [ "$output" = "REJECT" ]
}

@test "dcup rejects 'n'" {
    run answer "$F/basic" n 'dcup'
    [ "$output" = "REJECT" ]
}

@test "dcup rejects 'no'" {
    run answer "$F/basic" no 'dcup'
    [ "$output" = "REJECT" ]
}

@test "dcup rejects a plain Enter" {
    run answer "$F/basic" "" 'dcup'
    [ "$output" = "REJECT" ]
}

@test "DOCKER_ALIASES_AUTO_YES bypasses the prompt for tests and CI" {
    run lib_call "$F/basic" \
        'DOCKER_ALIASES_AUTO_YES=1 _confirm_operation x </dev/null >/dev/null 2>&1 && echo ACCEPT || echo REJECT'
    [ "$output" = "ACCEPT" ]
}
