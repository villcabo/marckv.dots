#!/usr/bin/env bats
# dprune — delete what docker no longer uses, after showing exactly what.
#
# The shim's world (see shim.bash for the full table):
#   running   fx-api (nginx:alpine), fx-db (runs the DANGLING image dd2, mounts
#             fixture-proj_pgdata and fixture-proj_cache)
#   deleted   other-api (exited)  -> frees other-proj_default, other-proj_data, dd3
#             plain-box (created) -> frees app/worker:1.0
#   unused    orphan-net, orphan-vol, an anonymous volume, dd1, postgres:18,
#             old/tool:2 + old/tool:latest (one image), busy/img:1 (docker refuses it)
#   never     bridge, host, none, docker_gwbridge, ingress, a swarm overlay
# The docker host is called "fixture-host".

load '../helpers/common'

# deleted <dir> <reply> <script…> — answer the prompt, return the argv docker
# received. dprune drops docker's stdout, so the shim logs argv to a file.
deleted() {
    local dir="$1" reply="$2"; shift 2
    local log="$BATS_TEST_TMPDIR/argv.log"
    : > "$log"
    printf '%s\n' "$reply" | "$DA_SHELL" -c "
        cd '$dir' || exit 99
        export DAV2_ARGV_LOG='$log'
        source '$INIT'
        $*
    " >/dev/null 2>&1
    cat "$log"
}

# --- help and parsing -------------------------------------------------------

@test "dprune --help shows usage" {
    run in_dir "$WORK" 'dprune --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "dprune --help explains the cascade" {
    run in_dir "$WORK" 'dprune --help'
    [[ "$output" == *"THE CASCADE"* ]]
}

@test "dprune exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dprune -z'
    [ "$output" = "1" ]
}

@test "dprune refuses a name: it takes only flags" {
    run rc_of "$WORK" 'dprune fx-api'
    [ "$output" = "1" ]
}

@test "dprune has no -y" {
    run rc_of "$WORK" 'dprune -y'
    [ "$output" = "1" ]
}

# --- what goes, and why ---------------------------------------------------------

@test "dprune lists the stopped containers, created ones included" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"STOPPED CONTAINERS  2"* ]]
    [[ "$output" == *"other-api"*"Exited (137) 2 days ago"* ]]
    [[ "$output" == *"plain-box"*"Created"* ]]
}

@test "dprune never lists a running container" {
    run declined "$WORK" 'dprune'
    [ -z "$(printf '%s\n' "$output" | sed -n '/STOPPED CONTAINERS/,/^$/p' | grep -E 'fx-api|fx-db')" ]
}

@test "dprune marks a network freed by the cascade" {
    # Nothing RUNS on other-proj_default, but other-api points at it; it only
    # becomes unused because other-api goes first. That is the case a naive
    # preview gets wrong.
    run declined "$WORK" 'dprune'
    [[ "$(printf '%s\n' "$output" | grep 'other-proj_default')" == *"freed — its stopped containers go first"* ]]
}

@test "dprune marks a network nothing points at as unused" {
    run declined "$WORK" 'dprune'
    [[ "$(printf '%s\n' "$output" | grep 'orphan-net')" == *"unused"* ]]
}

@test "dprune keeps a network a running container uses" {
    run declined "$WORK" 'dprune'
    [[ "$output" != *"fixture-proj_default"* ]]
}

@test "dprune never touches built-in or swarm networks" {
    run declined "$WORK" 'dprune -av'
    [[ "$output" == *"NETWORKS  2"* ]]
    [[ "$output" != *"docker_gwbridge"* ]]
    [[ "$output" != *"ingress"* ]]
    [[ "$output" != *"app-overlay"* ]]
}

@test "dprune finds dangling images through their own filter" {
    # Plain "docker images" hides them on the containerd store.
    run declined "$WORK" 'dprune'
    [[ "$output" == *"DANGLING IMAGES  2"* ]]
}

@test "dprune keeps a dangling image a running container still uses" {
    # fx-db runs dd2 — a re-tag left it dangling. Deleting it is not unused.
    run deleted "$WORK" fixture-host 'dprune'
    [[ "$output" == *"[rmi] [dd1] [dd3]"* ]]
    [[ "$output" != *"dd2"* ]]
}

@test "dprune marks an image freed by the cascade" {
    run declined "$WORK" 'dprune'
    [[ "$(printf '%s\n' "$output" | grep '300MB')" == *"freed — only stopped containers used it"* ]]
}

@test "dprune leaves tagged images alone without -a, and says so" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"tagged images: 5 unused, kept — they go with -a"* ]]
    [[ "$output" != *"postgres:18"* ]]
}

@test "dprune leaves volumes alone without -v, and counts them" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"volumes: not touched — 3 unused would go with -v"* ]]
    [[ "$output" != *"VOLUMES"* ]]
}

@test "dprune leaves the build cache alone without -a, with its size" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"build cache: 2.5GB, kept — it goes with -a"* ]]
}

@test "dprune says what it keeps running" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"2 running container(s), and every network, image and volume they use"* ]]
}

# --- -a and -v --------------------------------------------------------------------

@test "dprune -a adds every image no remaining container uses" {
    run declined "$WORK" 'dprune -a'
    [[ "$output" == *"IMAGES  7"* ]]
    [[ "$output" == *"app/worker:1.0"* ]]
    [[ "$output" != *"nginx:alpine"* ]]
}

@test "dprune -a counts an image with two tags once" {
    # 120 + 300 + 400 + 200 + 1000 (old/tool, once) + 10 = 2030MB.
    run declined "$WORK" 'dprune -a'
    [[ "$output" == *"up to 2.0GB"* ]]
}

@test "dprune -a adds the build cache, with its exact size" {
    run declined "$WORK" 'dprune -a'
    [[ "$output" == *"BUILD CACHE  2.5GB"* ]]
}

@test "dprune -v lists every volume it destroys, uncapped, with sizes" {
    run declined "$WORK" 'dprune -v'
    [[ "$output" == *"VOLUMES  3"* ]]
    [[ "$output" == *"other-proj_data"*"1.2GB"*"freed"* ]]
    [[ "$output" == *"orphan-vol"*"800MB"*"unused"* ]]
}

@test "dprune -v shows an anonymous volume short, and as anonymous" {
    run declined "$WORK" 'dprune -v'
    [[ "$output" == *"a1b2c3d4e5f6…  anonymous"* ]]
}

@test "dprune -v keeps volumes a running container mounts" {
    run declined "$WORK" 'dprune -v'
    [[ "$output" != *"fixture-proj_pgdata"* ]]
    [[ "$output" != *"fixture-proj_cache"* ]]
}

@test "dprune -v names the volumes in the confirmation" {
    run declined "$WORK" 'dprune -v'
    [[ "$output" == *"3 VOLUME(S)"* ]]
}

# --- the confirmation -------------------------------------------------------------

@test "dprune asks for the docker host's name" {
    run declined "$WORK" 'dprune'
    [[ "$output" == *"[fixture-host]"* ]]
}

@test "dprune deletes nothing on 'yes'" {
    # yes is the answer to every other prompt; here it is not the answer.
    run deleted "$WORK" yes 'dprune'
    [ -z "$output" ]
}

@test "dprune deletes nothing on Enter" {
    run deleted "$WORK" '' 'dprune'
    [ -z "$output" ]
}

@test "dprune deletes nothing on a wrong host name" {
    run deleted "$WORK" prod-host 'dprune'
    [ -z "$output" ]
}

@test "dprune exits 1 when declined" {
    run rc_of "$WORK" 'dprune'
    [ "$output" = "1" ]
}

# --- what runs ----------------------------------------------------------------------

@test "dprune deletes exactly the previewed items, by ID, in cascade order" {
    run deleted "$WORK" fixture-host 'dprune'
    [ "$output" = "ARGV: [rm] [id-other-api] [id-plain-box]
ARGV: [network] [rm] [n-other] [n-orphan]
ARGV: [rmi] [dd1] [dd3]" ]
}

@test "dprune never passes -f to a deletion" {
    run deleted "$WORK" fixture-host 'dprune -av'
    [ -z "$(printf '%s\n' "$output" | grep -E '\[rm\]|\[rmi\]' | grep -- '-f')" ]
}

@test "dprune -av runs volumes before images, and the cache last" {
    run deleted "$WORK" fixture-host 'dprune -av'
    local verbs
    verbs=$(printf '%s\n' "$output" | sed -E 's/^ARGV: \[([a-z]+)\]( \[(rm|prune)\])?.*/\1\2/' | tr '\n' ' ')
    [ "$verbs" = "rm network [rm] volume [rm] rmi builder [prune] " ]
}

@test "dprune -v deletes the volumes by name" {
    run deleted "$WORK" fixture-host 'dprune -v'
    [[ "$output" == *"[volume] [rm] [other-proj_data] [orphan-vol] [a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2]"* ]]
}

@test "dprune -a deletes tagged images by reference, not by ID" {
    # One ID with two tags makes "docker rmi <id>" refuse without -f.
    run deleted "$WORK" fixture-host 'dprune -a'
    [[ "$output" == *"[old/tool:2] [old/tool:latest]"* ]]
}

@test "dprune reports what docker refused" {
    run in_dir "$WORK" 'export DOCKER_ALIASES_AUTO_YES=1; dprune -a'
    [[ "$output" == *"images"*"6 deleted, 1 refused"* ]]
    [[ "$output" == *"busy/img:1"* ]]
}

# --- dry run and the cap ------------------------------------------------------------

@test "dprune -n deletes nothing and asks nothing" {
    run deleted "$WORK" fixture-host 'dprune -n'
    [ -z "$output" ]
}

@test "dprune -n writes the preview to stdout" {
    run out_of "$WORK" 'dprune -n'
    [[ "$output" == *"dry run"* ]]
    [[ "$output" == *"STOPPED CONTAINERS"* ]]
}

@test "dprune keeps the preview out of stdout when it is for real" {
    run out_of "$WORK" 'dprune </dev/null'
    [[ "$output" != *"STOPPED CONTAINERS"* ]]
}

@test "dprune caps long lists and points at -n" {
    run lib_call "$WORK" '_dprune_items "$(for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf "c%s\ta\tb\tc\n" $i; done)" 10'
    [[ "$output" == *"c10"* ]]
    [[ "$output" != *"c11"* ]]
    [[ "$output" == *"and 2 more"*"dprune -n"* ]]
}

@test "dprune -n does not cap" {
    run lib_call "$WORK" '_dprune_items "$(for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf "c%s\ta\tb\tc\n" $i; done)" 0'
    [[ "$output" == *"c12"* ]]
    [[ "$output" != *"more"* ]]
}

# --- completion -------------------------------------------------------------

@test "dprune completes its flags" {
    run complete_in "$WORK" 1 dprune '-'
    [[ "$output" == *"-v"* ]]
}

@test "dprune offers no names" {
    run complete_in "$WORK" 1 dprune ''
    [ -z "$output" ]
}
