#!/usr/bin/env bash
# docker-aliases v2 — compose discovery layer.
#
# Answers two questions for every command: which compose file are we acting on,
# and which services live in it.
#
# Configuration env vars:
#   COMPOSE_FILE              docker's own: a SEPARATED LIST of compose files
#   COMPOSE_PATH_SEPARATOR    what separates them (default ":")
#   DOCKER_COMPOSE_FILE       a v1 invention, one file, kept for compatibility
#   DOCKER_ALIASES_CACHE_TTL  Service-list cache TTL in seconds (default 5,
#                             0 disables caching)

# ---------------------------------------------------------------------------
# Compose file detection
#
# The goal is simple to state and easy to get wrong: in any directory, these
# commands must act on the SAME files `docker compose` would act on. Anything
# else means the preview says one thing and docker does another.
#
# Resolution order, mirroring docker's own:
#   1. $COMPOSE_FILE          — docker's native variable, a LIST
#   2. COMPOSE_FILE= in .env  — same, and docker reads it from there too
#   3. $DOCKER_COMPOSE_FILE   — a v1 invention, kept so old setups keep working
#   4. DOCKER_COMPOSE_FILE= in .env
#   5. ./docker-compose.yml (or .yaml), plus its override sibling
#
# COMPOSE_FILE holds a SEPARATED LIST, not one path — ":" by default, or
# whatever COMPOSE_PATH_SEPARATOR says. Reading only the first entry is how a
# project with five compose files ends up starting one of them.
#
# Whenever an explicit list is given (1-4), the override sibling is NOT added.
# That is not our choice: setting COMPOSE_FILE disables docker's automatic
# docker-compose.override.yml merge exactly the way passing -f does, so adding
# it back would make us diverge from docker in the other direction.
# ---------------------------------------------------------------------------

# _env_value <KEY> → the value of KEY in ./.env, empty if unset
#
# Parsed in pure shell: a minimal server has no guarantee of grep or cut, and
# this runs on every completion keystroke.
_env_value() {
    [[ -f .env ]] || return 1

    local key="$1" line value=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            "$key"=*)
                value="${line#"$key"=}"
                value="${value%\"}"; value="${value#\"}"
                value="${value%\'}"; value="${value#\'}"
                ;;
        esac
    done < .env

    [[ -z "$value" ]] && return 1
    printf '%s' "$value"
}

# _profiles_from_words <word>... → the -P values on a command line, comma-joined
#
# Completion needs to know which profiles the half-typed command already names,
# so the services it offers match the ones that command would actually act on.
# Takes the words as arguments because the array holding them is COMP_WORDS in
# bash and words in zsh.
_profiles_from_words() {
    local out="" expect=0 w
    for w in "$@"; do
        if (( expect )); then
            out+="${out:+,}${w}"
            expect=0
            continue
        fi
        [[ "$w" == "-P" ]] && expect=1
    done
    printf '%s' "$out"
}

# _split_on <separator> <string> → one item per line
_split_on() {
    local sep="$1" rest="$2"
    while [[ "$rest" == *"$sep"* ]]; do
        printf '%s\n' "${rest%%"$sep"*}"
        rest="${rest#*"$sep"}"
    done
    [[ -n "$rest" ]] && printf '%s\n' "$rest"
    return 0
}

# _resolve_compose_files → every compose file in play, one per line
#
# This is the single source of truth. _get_compose_file is a thin wrapper that
# returns the first line, for the few places that only need one.
_resolve_compose_files() {
    local sep item found=""
    # A literal newline in a plain variable: zsh does not expand $'\n' inside
    # a ${var:+...} substitution, so building a list with it silently produces
    # one run-on line. Documented in the README, and worth re-reading before
    # every list you assemble.
    local nl='
' 

    # The separator can be redefined, and is read the same way docker reads it.
    sep="${COMPOSE_PATH_SEPARATOR:-}"
    [[ -z "$sep" ]] && sep=$(_env_value COMPOSE_PATH_SEPARATOR)
    [[ -z "$sep" ]] && sep=":"

    # --- 1 & 2: COMPOSE_FILE, environment first, then .env -----------------
    local list="${COMPOSE_FILE:-}"
    [[ -z "$list" ]] && list=$(_env_value COMPOSE_FILE)

    if [[ -n "$list" ]]; then
        while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            # A listed file that does not exist is docker's error to report,
            # not ours to hide — pass it through and let docker say so.
            found+="${found:+$nl}${item}"
        done <<< "$(_split_on "$sep" "$list")"
        [[ -n "$found" ]] && { printf '%s\n' "$found"; return 0; }
    fi

    # --- 3 & 4: DOCKER_COMPOSE_FILE, the v1 variable ------------------------
    local single="${DOCKER_COMPOSE_FILE:-}"
    [[ -z "$single" ]] && single=$(_env_value DOCKER_COMPOSE_FILE)
    if [[ -n "$single" && -f "$single" ]]; then
        printf '%s\n' "$single"
        return 0
    fi

    # --- 5: the conventional names, plus the override sibling ---------------
    local base=""
    if   [[ -f docker-compose.yml ]];  then base="docker-compose.yml"
    elif [[ -f docker-compose.yaml ]]; then base="docker-compose.yaml"
    elif [[ -f compose.yml ]];         then base="compose.yml"
    elif [[ -f compose.yaml ]];        then base="compose.yaml"
    else return 1
    fi

    printf '%s\n' "$base"

    local candidate=""
    case "$base" in
        docker-compose.yml)  candidate="docker-compose.override.yml" ;;
        docker-compose.yaml) candidate="docker-compose.override.yaml" ;;
        compose.yml)         candidate="compose.override.yml" ;;
        compose.yaml)        candidate="compose.override.yaml" ;;
    esac
    [[ -n "$candidate" && -f "$candidate" ]] && printf '%s\n' "$candidate"

    return 0
}

# _get_compose_file → the FIRST resolved compose file
#
# Kept because several callers only need something to point at. Anything that
# acts on the project should use _resolve_compose_files instead: this one
# cannot represent a multi-file project, which is precisely the bug it caused.
_get_compose_file() {
    local first
    first=$(_resolve_compose_files) || return 1
    printf '%s\n' "${first%%$'\n'*}"
}

# ---------------------------------------------------------------------------
# Service discovery
#
# `docker compose config --services` costs a few hundred milliseconds, which is
# painful on every TAB press. A single-slot cache keyed by cwd + compose file
# covers the real usage pattern: hammering TAB in one directory.
# ---------------------------------------------------------------------------

_DAV2_SVC_KEY=""
_DAV2_SVC_VAL=""
_DAV2_SVC_TS=0

# _get_compose_services [file...] → one service name per line
#
# Takes every compose file, not just the first: with layered files the merged
# service list is what actually gets started, and the preview must not show
# anything but the truth.
_get_compose_services() {
    # Profiles change WHICH services exist, so a list built without them is a
    # different list. Passed explicitly rather than read from the environment:
    # `--profile` REPLACES $COMPOSE_PROFILES rather than adding to it, so once a
    # command names one, that is the whole set.
    local profiles=""
    if [[ "${1:-}" == "--profiles" ]]; then
        profiles="$2"; shift 2
    fi

    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        # EVERY resolved file, not just the first. Falling back to one is what
        # made completion in a COMPOSE_FILE project offer a single service.
        local detected_item
        while IFS= read -r detected_item; do
            [[ -n "$detected_item" ]] && files+=("$detected_item")
        done <<< "$(_resolve_compose_files)"
        [[ ${#files[@]} -eq 0 ]] && return 1
    fi

    local ttl="${DOCKER_ALIASES_CACHE_TTL:-5}"
    # The profiles belong in the cache key: the same directory answers
    # differently depending on them.
    local key="${PWD}:${files[*]}:${profiles}"
    local now
    now=$(date +%s 2>/dev/null || printf '0')

    if [[ "$key" == "$_DAV2_SVC_KEY" ]] && (( ttl > 0 )) && (( now - _DAV2_SVC_TS < ttl )); then
        printf '%s\n' "$_DAV2_SVC_VAL"
        return 0
    fi

    local args=() file prof
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done
    if [[ -n "$profiles" ]]; then
        while IFS= read -r prof; do
            [[ -n "$prof" ]] && args+=(--profile "$prof")
        done <<< "$(_split_commas "$profiles")"
    fi

    # Sorted because `config --services` does NOT guarantee an order — the same
    # file can come back as "api db worker" or "worker api db" on consecutive
    # runs. Docker does not care about the order we pass services in, but a
    # preview that reshuffles itself every run is one you stop trusting.
    local result
    result=$(docker compose "${args[@]}" config --services 2>/dev/null | LC_ALL=C sort) || return 1
    [[ -z "$result" ]] && return 1

    _DAV2_SVC_KEY="$key"
    _DAV2_SVC_VAL="$result"
    _DAV2_SVC_TS="$now"

    printf '%s\n' "$result"
}

# _get_compose_profiles [file...] → one profile name per line
#
# Uncached: profiles are only ever asked for during TAB completion of -P, which
# is rare enough that a stale answer would cost more than the lookup.
_get_compose_profiles() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        # EVERY resolved file, not just the first. Falling back to one is what
        # made completion in a COMPOSE_FILE project offer a single service.
        local detected_item
        while IFS= read -r detected_item; do
            [[ -n "$detected_item" ]] && files+=("$detected_item")
        done <<< "$(_resolve_compose_files)"
        [[ ${#files[@]} -eq 0 ]] && return 1
    fi

    local args=() file
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done

    docker compose "${args[@]}" config --profiles 2>/dev/null
}

# _get_compose_project [file...] → the resolved project name
#
# Read from `config` rather than guessed: compose resolves it from `name:`, then
# COMPOSE_PROJECT_NAME, then the directory. Only `config` knows the answer.
#
# Parsed in pure shell because jq is not installed on a minimal server, and this
# runs on Debian/Ubuntu boxes with nothing extra.
_get_compose_project() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        # EVERY resolved file, not just the first. Falling back to one is what
        # made completion in a COMPOSE_FILE project offer a single service.
        local detected_item
        while IFS= read -r detected_item; do
            [[ -n "$detected_item" ]] && files+=("$detected_item")
        done <<< "$(_resolve_compose_files)"
        [[ ${#files[@]} -eq 0 ]] && return 1
    fi

    local args=() file
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done

    local line value
    while IFS= read -r line; do
        # Only a top-level `name:` — a nested one is some service's key.
        case "$line" in
            name:*)
                value="${line#name:}"
                while [[ "$value" == " "* ]]; do value="${value# }"; done
                value="${value%\"}"; value="${value#\"}"
                value="${value%\'}"; value="${value#\'}"
                if [[ -n "$value" ]]; then
                    printf '%s\n' "$value"
                    return 0
                fi
                ;;
        esac
    done <<< "$(docker compose "${args[@]}" config 2>/dev/null)"

    return 1
}

# _get_compose_volumes [file...] → one NAMED volume per line
#
# These are exactly what `docker compose down -v` destroys.
_get_compose_volumes() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        # EVERY resolved file, not just the first. Falling back to one is what
        # made completion in a COMPOSE_FILE project offer a single service.
        local detected_item
        while IFS= read -r detected_item; do
            [[ -n "$detected_item" ]] && files+=("$detected_item")
        done <<< "$(_resolve_compose_files)"
        [[ ${#files[@]} -eq 0 ]] && return 1
    fi

    local args=() file
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done

    local result
    result=$(docker compose "${args[@]}" config --volumes 2>/dev/null | LC_ALL=C sort) || return 1
    [[ -z "$result" ]] && return 1
    printf '%s\n' "$result"
}

# _get_running_services [file...] → one RUNNING service per line
#
# Unlike every other lookup here, this one needs a live daemon. It returns
# non-zero when it cannot ask, which callers must treat as "unknown" rather
# than "nothing is running" — those two mean very different things right
# before a destructive command.
_get_running_services() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        # EVERY resolved file, not just the first. Falling back to one is what
        # made completion in a COMPOSE_FILE project offer a single service.
        local detected_item
        while IFS= read -r detected_item; do
            [[ -n "$detected_item" ]] && files+=("$detected_item")
        done <<< "$(_resolve_compose_files)"
        [[ ${#files[@]} -eq 0 ]] && return 1
    fi

    local args=() file
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done

    # Not piped straight into sort: a pipeline reports the LAST command's
    # status, so `docker | sort` would return 0 even when docker failed, making
    # "cannot reach the daemon" indistinguishable from "nothing is running".
    local result
    result=$(docker compose "${args[@]}" ps --filter status=running --services 2>/dev/null) || return 1

    [[ -z "$result" ]] && return 0      # daemon answered: nothing is running
    printf '%s\n' "$result" | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# Portable helpers
# ---------------------------------------------------------------------------

# _split_commas <string> → one item per line.
# Written as a loop because `IFS=, read -ra` is bash-only and breaks in zsh.
_split_commas() {
    local rest="$1"
    while [[ "$rest" == *,* ]]; do
        printf '%s\n' "${rest%%,*}"
        rest="${rest#*,}"
    done
    [[ -n "$rest" ]] && printf '%s\n' "$rest"
    return 0
}

# ---------------------------------------------------------------------------
# Container lookups
#
# These reach across the whole host, not just the project in the current
# directory — the point of dcd is jumping to a project you are NOT standing in.
# ---------------------------------------------------------------------------

# _list_containers → one container name per line, running AND stopped
#
# Stopped ones are included on purpose: `docker inspect` reads them fine, and a
# project you want to jump to is quite often one that is currently down.
_list_containers() {
    local result
    result=$(docker ps -a --format '{{.Names}}' 2>/dev/null) || return 1
    [[ -z "$result" ]] && return 1
    printf '%s\n' "$result" | LC_ALL=C sort
}

# _container_compose_info <name>... → five lines PER container, in this order:
#   status, project, service, working_dir, config_files
#
# Takes every name in one call. docker inspect accepts a list and emits the
# format once per container, in order, so N containers cost one round trip
# instead of N.
_container_compose_info() {
    docker inspect "$@" --format '{{.State.Status}}
{{index .Config.Labels "com.docker.compose.project"}}
{{index .Config.Labels "com.docker.compose.service"}}
{{index .Config.Labels "com.docker.compose.project.working_dir"}}
{{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Java .properties helpers
# ---------------------------------------------------------------------------

# _unescape_prop <value> → the value with .properties escaping undone
#
# Java escapes ":", "=", "#" and "!" on write, so a timestamp reaches us as
# 2024-04-18T16\:56\:45-0400 and reads like a typo if passed through raw.
# The backslash pair is handled last so an escaped backslash is not mistaken
# for the start of another escape.
_unescape_prop() {
    local v="$1"
    v="${v//\\:/:}"
    v="${v//\\=/=}"
    v="${v//\\#/#}"
    v="${v//\\!/!}"
    v="${v//\\\\/\\}"
    printf '%s' "$v"
}

# _prop_value <key> <properties text> → the value of key
_prop_value() {
    local key="$1" text="$2" line
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            "$key"=*) _unescape_prop "${line#"$key"=}"; return 0 ;;
        esac
    done <<< "$text"
    return 1
}

# _age_of <ISO-8601 timestamp> → 3d, 2w, 5mo …
#
# Falls back to the raw string rather than guessing when date cannot parse it:
# a wrong age is worse than an unformatted one.
_age_of() {
    local ts="$1"
    [[ -z "$ts" ]] && { printf '—'; return 0; }

    local then now diff
    then=$(date -d "$ts" +%s 2>/dev/null) || { printf '%s' "${ts%%T*}"; return 0; }
    now=$(date +%s 2>/dev/null) || { printf '%s' "${ts%%T*}"; return 0; }

    diff=$(( now - then ))
    (( diff < 0 )) && diff=0

    if   (( diff < 3600 ));    then printf '%dm'  $(( diff / 60 ))
    elif (( diff < 86400 ));   then printf '%dh'  $(( diff / 3600 ))
    elif (( diff < 604800 ));  then printf '%dd'  $(( diff / 86400 ))
    elif (( diff < 2592000 )); then printf '%dw'  $(( diff / 604800 ))
    elif (( diff < 31536000 ));then printf '%dmo' $(( diff / 2592000 ))
    else                            printf '%dy'  $(( diff / 31536000 ))
    fi
}

# ---------------------------------------------------------------------------
# git.properties — shared by dcver (compose services) and dver (containers)
#
# The file the git-commit-id plugin bakes into a Spring Boot / JHipster
# artifact. Both commands ask the same question of different populations, so
# the probe and the parsing live here rather than in either one.
# ---------------------------------------------------------------------------

# Where it usually is, ordered by how often it is the right answer.
_DAV2_PROP_PATHS='/app/resources/git.properties
/app/BOOT-INF/classes/git.properties
/app/classes/git.properties
/app/git.properties
/deployments/git.properties
/usr/share/nginx/html/git.properties
/usr/share/nginx/html/assets/git.properties'

# _git_props_probe → an sh -c script that prints the first git.properties found
#
# The hit is prefixed with @@PATH@@<path> so the caller can say WHERE it came
# from — which is the quick way to learn where your image actually puts it.
# DOCKER_ALIASES_GIT_PROPS entries are searched first.
_git_props_probe() {
    local paths="$_DAV2_PROP_PATHS"
    [[ -n "${DOCKER_ALIASES_GIT_PROPS:-}" ]] && \
        paths="$(_split_on ':' "$DOCKER_ALIASES_GIT_PROPS")
$paths"

    local probe='for f in' item
    while IFS= read -r item; do
        [[ -n "$item" ]] && probe+=" '$item'"
    done <<< "$paths"
    probe+='; do [ -f "$f" ] && { echo "@@PATH@@$f"; cat "$f"; exit 0; }; done; exit 1'

    printf '%s' "$probe"
}

# _git_props_row <properties text> → version, commit, branch, age, dirty
#                                    as five TAB-separated fields
#
# app.version answers the question in one string, which is why it leads. The
# 40-character hash and the full commit message that v1 printed are left out:
# on a merge commit that message is a paragraph.
_git_props_row() {
    local props="$1"
    local version commit branch dirty when

    version=$(_prop_value app.version "$props") || version=""
    [[ -z "$version" ]] && version=$(_prop_value git.build.version "$props")

    commit=$(_prop_value git.commit.id.abbrev "$props") || commit=""
    if [[ -z "$commit" ]]; then
        commit=$(_prop_value git.commit.id "$props")
        commit="${commit:0:7}"
    fi

    branch=$(_prop_value git.branch "$props") || branch=""
    dirty=$(_prop_value git.dirty "$props") || dirty=""
    when=$(_age_of "$(_prop_value git.commit.time "$props")")

    printf '%s\t%s\t%s\t%s\t%s' \
        "${version:-—}" "${commit:-—}" "${branch:-—}" "${when:-—}" "$dirty"
}
