#!/usr/bin/env bats
# dcdown — stop and remove compose services.
#
# The command this suite guards hardest: `dcdown -v` is the only thing here
# that destroys data.

load '../helpers/common'

# --- help -------------------------------------------------------------------

@test "dcdown --help shows usage" {
    run in_dir "$F/volumes" 'dcdown --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dcdown --help flags -v as destroying data" {
    run in_dir "$F/volumes" 'dcdown --help'
    [[ "$output" == *"destroys data"* ]]
}

@test "dcdown --help explains the project-name prompt" {
    run in_dir "$F/volumes" 'dcdown --help'
    [[ "$output" == *"project name"* ]]
}

# --- command ----------------------------------------------------------------

@test "dcdown with no flags runs a plain down" {
    run argv_of "$F/volumes" 'dcdown'
    [[ "$output" == *"[down]"* ]]
}

@test "dcdown -v emits --volumes" {
    run argv_of "$F/volumes" 'dcdown -v'
    [[ "$output" == *"[--volumes]"* ]]
}

@test "dcdown -O emits --remove-orphans" {
    run argv_of "$F/volumes" 'dcdown -O'
    [[ "$output" == *"[--remove-orphans]"* ]]
}

@test "dcdown -vO still removes volumes" {
    run argv_of "$F/volumes" 'dcdown -vO'
    [[ "$output" == *"[--volumes]"* ]]
}

@test "dcdown -vO still clears orphans" {
    run argv_of "$F/volumes" 'dcdown -vO'
    [[ "$output" == *"[--remove-orphans]"* ]]
}

@test "dcdown narrows to a matched service" {
    run argv_of "$F/volumes" 'dcdown db'
    [[ "$output" == *"[db]"* ]]
}

@test "dcdown excludes services the pattern missed" {
    run argv_of "$F/volumes" 'dcdown db'
    [[ "$output" != *"[cache]"* ]]
}

# --- the volume warning -----------------------------------------------------

@test "dcdown -v names the first volume it would delete" {
    run declined "$F/volumes" 'dcdown -v'
    [[ "$output" == *"pgdata"* ]]
}

@test "dcdown -v names the second volume" {
    run declined "$F/volumes" 'dcdown -v'
    [[ "$output" == *"redis_data"* ]]
}

@test "dcdown -v says it cannot be undone" {
    run declined "$F/volumes" 'dcdown -v'
    [[ "$output" == *"cannot be undone"* ]]
}

@test "dcdown -v asks for the project name" {
    run declined "$F/volumes" 'dcdown -v'
    [[ "$output" == *"dav2-fixture-volumes"* ]]
}

@test "dcdown without -v shows no volume line" {
    run declined "$F/volumes" 'dcdown'
    [[ "$output" != *"cannot be undone"* ]]
}

@test "dcdown without -v asks the ordinary way" {
    run declined "$F/volumes" 'dcdown'
    [[ "$output" == *"[yes/N]"* ]]
}

# --- confirmation strength --------------------------------------------------
#
# The point of the typed prompt: the answer that works everywhere else must NOT
# work here. "yes" is the answer to every other prompt, and one you repeat
# without reading has stopped being a prompt.

@test "dcdown -v rejects 'yes'" {
    run answer "$F/volumes" yes 'dcdown -v'
    [ "$output" = "REJECT" ]
}

@test "dcdown -v rejects a wrong project name" {
    run answer "$F/volumes" not-the-project 'dcdown -v'
    [ "$output" = "REJECT" ]
}

@test "dcdown -v accepts the project name" {
    run answer "$F/volumes" dav2-fixture-volumes 'dcdown -v'
    [ "$output" = "ACCEPT" ]
}

@test "dcdown without -v accepts 'yes'" {
    run answer "$F/volumes" yes 'dcdown'
    [ "$output" = "ACCEPT" ]
}

@test "dcdown without -v still rejects a bare 'y'" {
    run answer "$F/volumes" y 'dcdown'
    [ "$output" = "REJECT" ]
}

# --- daemon awareness -------------------------------------------------------
#
# Asserted without assuming a daemon: this runs both on a workstation that has
# one and inside containers that do not. What must hold either way is that
# dcdown SAYS which picture it is showing — presenting declared services as if
# they were running is the failure mode.

@test "dcdown states whether the list is running or declared" {
    run declined "$F/volumes" 'dcdown'
    [[ "$output" == *"could not reach"* || "$output" == *"nothing is running"* ]]
}

@test "dcdown still lists the services" {
    run declined "$F/volumes" 'dcdown'
    [[ "$output" == *"cache"* ]]
}

# --- errors -----------------------------------------------------------------

@test "dcdown exits 1 when nothing matches" {
    run rc_of "$F/volumes" 'dcdown zzz'
    [ "$output" = "1" ]
}

@test "dcdown exits 1 on an unknown flag" {
    run rc_of "$F/volumes" 'dcdown -Z'
    [ "$output" = "1" ]
}

@test "dcdown exits 1 when -f has no value" {
    run rc_of "$F/volumes" 'dcdown -f'
    [ "$output" = "1" ]
}

@test "dcdown exits 1 when the compose file is missing" {
    run rc_of "$F/volumes" 'dcdown -f nope.yml'
    [ "$output" = "1" ]
}

@test "dcdown exits 1 when declined" {
    run rc_of "$F/volumes" 'dcdown'
    [ "$output" = "1" ]
}

@test "dcdown lists what was available when nothing matches" {
    run err_of "$F/volumes" 'dcdown zzz'
    [[ "$output" == *"available:"* ]]
}
