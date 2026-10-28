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

# --- joining profiles -------------------------------------------------------

@test "_join_commas joins on commas, not spaces" {
    # The counterpart _split_commas needs. Without it callers flattened arrays
    # with "${arr[*]}" — a space-joined string that _split_commas handed back
    # as one item.
    run lib_call "$F/basic" '_join_commas a b c'
    [[ "$output" == "a,b,c" ]]
}

@test "_join_commas on one item adds no separator" {
    run lib_call "$F/basic" '_join_commas only'
    [[ "$output" == "only" ]]
}

@test "_join_commas on nothing is empty" {
    run lib_call "$F/basic" '_join_commas'
    [[ -z "$output" ]]
}

@test "_join_commas round-trips through _split_commas" {
    run lib_call "$F/basic" '_split_commas "$(_join_commas dev full debug)" | tr "\\n" " "'
    [[ "$output" == "dev full debug "* ]]
}

# --- the order of the conventional names ------------------------------------
#
# docker's order, measured on compose v5.6.1 by dropping all four names in one
# directory and asking `config` which it took: compose.yaml, compose.yml,
# docker-compose.yml, docker-compose.yaml. The code used to try
# docker-compose.yml FIRST, so any project that had moved to compose.yaml
# without deleting the legacy file was operated on through a different file
# than docker used — and the preview named the wrong one confidently.
#
# Each file in the fixture declares a different container_name, so the test can
# tell which one was actually read instead of trusting the filename.

@test "compose.yaml wins over every other conventional name" {
    run lib_call "$F/allnames" '_resolve_compose_files | head -1'
    [[ "$output" == *"compose.yaml"* ]]
    [[ "$output" != *"docker-compose"* ]]
}

@test "the file picked is the one docker would pick" {
    run lib_call "$F/allnames" 'docker compose config 2>/dev/null | grep container_name'
    local theirs="$output"
    run lib_call "$F/allnames" 'docker compose -f "$(_resolve_compose_files | head -1)" config 2>/dev/null | grep container_name'
    [ "$output" = "$theirs" ]
}

@test "compose.yml wins once compose.yaml is gone" {
    cp -r "$F/allnames" "$BATS_TEST_TMPDIR/n2" && rm "$BATS_TEST_TMPDIR/n2/compose.yaml"
    run lib_call "$BATS_TEST_TMPDIR/n2" '_resolve_compose_files | head -1'
    [[ "$output" == *"compose.yml"* ]]
    [[ "$output" != *"docker-compose"* ]]
}

@test "docker-compose.yml wins over docker-compose.yaml" {
    # Documents the order inside that family. It does NOT guard the bug this
    # block is about: both the old order and the correct one try .yml before
    # .yaml, so reverting the fix leaves this one green. Verified by doing
    # exactly that. Kept because the relative order is still worth pinning,
    # and labelled so nobody reads it as the regression test.
    cp -r "$F/allnames" "$BATS_TEST_TMPDIR/n3"
    rm "$BATS_TEST_TMPDIR/n3/compose.yaml" "$BATS_TEST_TMPDIR/n3/compose.yml"
    run lib_call "$BATS_TEST_TMPDIR/n3" '_resolve_compose_files | head -1'
    [[ "$output" == *"docker-compose.yml"* ]]
    [[ "$output" != *"docker-compose.yaml"* ]]
}

@test "a legacy docker-compose.yml never shadows a modern compose.yaml" {
    # THIS is the regression test. The old order picked docker-compose.yml in
    # a directory that also had compose.yaml, so these commands and docker
    # operated on different files — and the preview named the wrong one.
    cp -r "$F/allnames" "$BATS_TEST_TMPDIR/n4"
    rm "$BATS_TEST_TMPDIR/n4/compose.yml" "$BATS_TEST_TMPDIR/n4/docker-compose.yaml"
    run lib_call "$BATS_TEST_TMPDIR/n4" '_resolve_compose_files | head -1'
    [[ "$output" == *"compose.yaml"* ]]
    [[ "$output" != *"docker-compose"* ]]
}

# --- the service cache actually caches --------------------------------------
#
# It never did. Every caller wrote `x=$(_get_compose_services …)`, and a
# command substitution is a subshell, so the globals the function set died
# with it — measured at 112/168/145/163/104 ms for five consecutive calls that
# should have cost one. The suite could not see it because common.bash forces
# DOCKER_ALIASES_CACHE_TTL=0, which disables the thing under test.
#
# Hiding the compose file between the two calls is what makes this test unable
# to pass by accident: on a hit the second call answers from memory, and with
# the TTL at 0 the same sequence must fail.

@test "the lookup leaves its cache visible to the caller" {
    run lib_call "$F/basic" \
        'DOCKER_ALIASES_CACHE_TTL=60 _get_compose_services_into; printf "KEY=[%s] VAL=[%s]" "$_DAV2_SVC_KEY" "${_DAV2_SVC_VAL//$'"'"'\n'"'"'/,}"'
    [[ "$output" == *"KEY=["*"basic"* ]]
    [[ "$output" == *"VAL=["*"api"* ]]
}

@test "a second lookup answers from the cache, with the compose file gone" {
    # The file is named explicitly on both calls. Left to be resolved, the
    # second call would fail at resolution — the file is gone by then — before
    # it ever reached the cache, and the test would be measuring the wrong
    # thing. Found exactly that way on the first run.
    cp -r "$F/basic" "$BATS_TEST_TMPDIR/c1"
    run lib_call "$BATS_TEST_TMPDIR/c1" '
        export DOCKER_ALIASES_CACHE_TTL=60
        _get_compose_services_into docker-compose.yml || exit 1
        mv docker-compose.yml hidden.yml
        _get_compose_services_into docker-compose.yml || exit 2
        printf "%s" "${_DA_R//$'"'"'\n'"'"'/,}"'
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"worker"* ]]
}

@test "with the TTL at zero the same sequence cannot answer" {
    # The discriminator for the test above. If it passed with caching off, it
    # would be proving nothing.
    cp -r "$F/basic" "$BATS_TEST_TMPDIR/c2"
    run lib_call "$BATS_TEST_TMPDIR/c2" '
        export DOCKER_ALIASES_CACHE_TTL=0
        _get_compose_services_into docker-compose.yml || exit 1
        mv docker-compose.yml hidden.yml
        _get_compose_services_into docker-compose.yml && printf "STILL=[%s]" "$_DA_R"'
    [[ "$output" != *"api"* ]]
}

@test "the profile list is cached too" {
    # It was not, and it was the whole remaining cost on the wide path: the
    # narrow lookup went 98 to 14 ms once it kept its cache while the wide one
    # stayed at ~150 ms, because this call cost 65-84 ms every time.
    cp -r "$F/profiles" "$BATS_TEST_TMPDIR/p1"
    run lib_call "$BATS_TEST_TMPDIR/p1" '
        export DOCKER_ALIASES_CACHE_TTL=60
        _get_compose_profiles_into docker-compose.yml || exit 1
        mv docker-compose.yml hidden.yml
        _get_compose_profiles_into docker-compose.yml || exit 2
        printf "%s" "${_DA_R//$'"'"'\n'"'"'/,}"'
    [[ "$output" == *"debug"* ]]
}
