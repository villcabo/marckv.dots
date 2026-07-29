#!/usr/bin/env bats
# File and profile resolution.
#
# These commands must act on exactly the files and profiles `docker compose`
# would act on in the same directory. Diverging by one of either means the
# preview describes something docker is not about to do — which is how three
# separate bugs reached daily use.

load '../helpers/common'

# --- COMPOSE_FILE -----------------------------------------------------------
#
# docker's own variable, holding a SEPARATED LIST. Reading only its first entry
# is how a five-file project acted on one of them.

@test "COMPOSE_FILE contributes its first listed file" {
    run lib_call "$F/composefile" '_resolve_compose_files'
    [[ "$output" == *"docker-compose.yml"* ]]
}

@test "COMPOSE_FILE contributes its second listed file" {
    run lib_call "$F/composefile" '_resolve_compose_files'
    [[ "$output" == *"docker-compose.extra.yml"* ]]
}

@test "COMPOSE_FILE contributes its third listed file" {
    run lib_call "$F/composefile" '_resolve_compose_files'
    [[ "$output" == *"docker-compose.more.yml"* ]]
}

# Setting COMPOSE_FILE disables docker's automatic override merge, so adding
# the sibling back would diverge in the other direction.
@test "COMPOSE_FILE suppresses the override sibling" {
    run lib_call "$F/composefile" '_resolve_compose_files'
    [[ "$output" != *"docker-compose.override.yml"* ]]
}

@test "services come from the whole COMPOSE_FILE list" {
    run lib_call "$F/composefile" '_get_compose_services'
    [[ "$output" == *"extra"* ]]
}

@test "services include the last listed file's" {
    run lib_call "$F/composefile" '_get_compose_services'
    [[ "$output" == *"more"* ]]
}

@test "services exclude the unlisted override" {
    run lib_call "$F/composefile" '_get_compose_services'
    [[ "$output" != *"must_not_appear"* ]]
}

@test "the environment outranks .env, as docker resolves it" {
    run "$DA_SHELL" -c "
        cd '$F/composefile'
        COMPOSE_FILE=docker-compose.yml
        export COMPOSE_FILE
        source '$INIT'
        _resolve_compose_files"
    [[ "$output" != *"extra"* ]]
}

@test "COMPOSE_PATH_SEPARATOR is honoured" {
    run lib_call "$F/composefile-sep" '_resolve_compose_files'
    [[ "$output" == *"docker-compose.extra.yml"* ]]
}

@test "dcup acts on the first file of the list" {
    run argv_of "$F/composefile" 'dcup'
    [[ "$output" == *"[-f] [docker-compose.yml]"* ]]
}

@test "dcup acts on the second" {
    run argv_of "$F/composefile" 'dcup'
    [[ "$output" == *"[-f] [docker-compose.extra.yml]"* ]]
}

@test "dcup acts on the third" {
    run argv_of "$F/composefile" 'dcup'
    [[ "$output" == *"[-f] [docker-compose.more.yml]"* ]]
}

# --- the override sibling ---------------------------------------------------
#
# docker merges docker-compose.override.yml on its own, but ONLY when no -f is
# passed. Every command here passes -f so the preview can name the file, which
# silently dropped the override until this was fixed.

@test "dcup takes the base file" {
    run argv_of "$F/override" 'dcup'
    [[ "$output" == *"[-f] [docker-compose.yml]"* ]]
}

@test "dcup adds the override sibling" {
    run argv_of "$F/override" 'dcup'
    [[ "$output" == *"[-f] [docker-compose.override.yml]"* ]]
}

@test "dclt adds the override sibling too" {
    run out_of "$F/override" 'dclt -o'
    [[ "$output" == *"[-f] [docker-compose.override.yml]"* ]]
}

@test "dcdown adds the override sibling too" {
    run argv_of "$F/override" 'dcdown'
    [[ "$output" == *"[-f] [docker-compose.override.yml]"* ]]
}

# The service that only exists in the override is the real proof.
@test "a service defined only in the override is visible" {
    run declined "$F/override" 'dcup'
    [[ "$output" == *"sidecar"* ]]
}

# An explicitly chosen file is taken at its word, exactly as docker does.
@test "an explicit -f gets no sibling guessed for it" {
    run argv_of "$F/multifile" 'dcup -f base.yml'
    [[ "$output" != *"docker-compose.override.yml"* ]]
}

# --- profiles ---------------------------------------------------------------
#
# Profiles decide WHICH SERVICES EXIST, so a list built without them describes
# a different project. Getting this wrong had the preview name one service
# while the command it printed would start two.

@test "unprofiled services always show" {
    run lib_call "$F/profiles" '_get_compose_services'
    [[ "$output" == *"api"* ]]
}

@test "profiled services stay hidden without their profile" {
    run lib_call "$F/profiles" '_get_compose_services'
    [[ "$output" != *"debugger"* ]]
}

@test "a profile reveals its services" {
    run lib_call "$F/profiles" '_get_compose_services --profiles debug'
    [[ "$output" == *"debugger"* ]]
}

@test "a profile reveals only its own" {
    run lib_call "$F/profiles" '_get_compose_services --profiles debug'
    [[ "$output" != *"seeder"* ]]
}

@test "comma-separated profiles, first" {
    run lib_call "$F/profiles" '_get_compose_services --profiles dev,debug'
    [[ "$output" == *"seeder"* ]]
}

@test "comma-separated profiles, second" {
    run lib_call "$F/profiles" '_get_compose_services --profiles dev,debug'
    [[ "$output" == *"debugger"* ]]
}

# THE RULE: the services the preview names must be the services the printed
# command would act on.
@test "the preview lists the profiled service" {
    run declined "$F/profiles" 'dcup -P debug'
    [[ "$output" == *"debugger"* ]]
}

@test "and the command enables that profile" {
    run declined "$F/profiles" 'dcup -P debug'
    [[ "$output" == *"--profile debug"* ]]
}

@test "with no -P the profiled service stays out of both" {
    run declined "$F/profiles" 'dcup'
    [[ "$output" != *"debugger"* ]]
}

# COMPOSE_PROFILES in .env — docker applies it unprompted, so discovery must
# reflect it without us passing anything.
@test "COMPOSE_PROFILES from .env is honoured" {
    run lib_call "$F/composeprofiles" '_get_compose_services'
    [[ "$output" == *"dev_only"* ]]
}

@test "COMPOSE_PROFILES does not enable other profiles" {
    run lib_call "$F/composeprofiles" '_get_compose_services'
    [[ "$output" != *"debug_only"* ]]
}

# -P REPLACES COMPOSE_PROFILES rather than adding to it. Verified against real
# docker; discovery has to agree or the preview drifts again.
@test "-P brings in its own profile" {
    run lib_call "$F/composeprofiles" '_get_compose_services --profiles debug'
    [[ "$output" == *"debug_only"* ]]
}

@test "-P REPLACES the .env profiles" {
    run lib_call "$F/composeprofiles" '_get_compose_services --profiles debug'
    [[ "$output" != *"dev_only"* ]]
}

# --- discovery helpers ------------------------------------------------------

@test "services are discovered from the compose file" {
    run lib_call "$F/basic" '_get_compose_services'
    [[ "$output" == *"worker"* ]]
}

@test "profiles are discovered from the compose file" {
    run lib_call "$F/profiles" '_get_compose_profiles'
    [[ "$output" == *"debug"* ]]
}
