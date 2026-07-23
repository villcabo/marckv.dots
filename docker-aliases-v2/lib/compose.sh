#!/usr/bin/env bash
# docker-aliases v2 — compose discovery layer.
#
# Answers two questions for every command: which compose file are we acting on,
# and which services live in it.
#
# Configuration env vars:
#   DOCKER_COMPOSE_FILE       Explicit compose file, wins over everything else
#   DOCKER_ALIASES_CACHE_TTL  Service-list cache TTL in seconds (default 5,
#                             0 disables caching)

# ---------------------------------------------------------------------------
# Compose file detection
#
# Priority:
#   1. $DOCKER_COMPOSE_FILE
#   2. DOCKER_COMPOSE_FILE= inside ./.env
#   3. ./docker-compose.yml
#   4. ./docker-compose.yaml
#
# Prints the path on stdout, returns 1 when nothing is found.
# ---------------------------------------------------------------------------

_get_compose_file() {
    if [[ -n "$DOCKER_COMPOSE_FILE" && -f "$DOCKER_COMPOSE_FILE" ]]; then
        printf '%s\n' "$DOCKER_COMPOSE_FILE"
        return 0
    fi

    # Parsed in pure bash so the lookup works on a box without grep/cut.
    if [[ -f .env ]]; then
        local line value=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                DOCKER_COMPOSE_FILE=*)
                    value="${line#DOCKER_COMPOSE_FILE=}"
                    value="${value%\"}"; value="${value#\"}"
                    value="${value%\'}"; value="${value#\'}"
                    ;;
            esac
        done < .env
        if [[ -n "$value" && -f "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    if [[ -f docker-compose.yml ]]; then
        printf '%s\n' "docker-compose.yml"
        return 0
    elif [[ -f docker-compose.yaml ]]; then
        printf '%s\n' "docker-compose.yaml"
        return 0
    fi

    return 1
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

# _resolve_compose_files → one compose file per line
#
# The base file, plus its override sibling when there is one.
#
# This exists because of a trap worth stating plainly: `docker compose` merges
# docker-compose.override.yml automatically, but ONLY when no -f is passed. The
# moment you pass `-f docker-compose.yml`, the override is silently dropped —
# and since every command here passes -f so the preview can name the file, the
# override has to be added back explicitly or it disappears.
#
# The sibling is only added for the two standard base names. A file chosen by
# hand (prod.yml, or DOCKER_COMPOSE_FILE pointing somewhere specific) is taken
# at its word, exactly as docker would.
_resolve_compose_files() {
    local base
    base=$(_get_compose_file) || return 1
    printf '%s\n' "$base"

    local dir="${base%/*}"
    [[ "$dir" == "$base" ]] && dir="."
    local stem="${base##*/}"
    local candidate=""

    case "$stem" in
        docker-compose.yml)  candidate="$dir/docker-compose.override.yml" ;;
        docker-compose.yaml) candidate="$dir/docker-compose.override.yaml" ;;
        compose.yml)         candidate="$dir/compose.override.yml" ;;
        compose.yaml)        candidate="$dir/compose.override.yaml" ;;
    esac

    if [[ -n "$candidate" && -f "$candidate" ]]; then
        # Keep it relative when the base was relative, so the preview stays
        # readable instead of printing an absolute path out of nowhere.
        printf '%s\n' "${candidate#./}"
    fi

    return 0
}

# _get_compose_services [file...] → one service name per line
#
# Takes every compose file, not just the first: with layered files the merged
# service list is what actually gets started, and the preview must not show
# anything but the truth.
_get_compose_services() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        local detected
        detected=$(_get_compose_file) || return 1
        files=("$detected")
    fi

    local ttl="${DOCKER_ALIASES_CACHE_TTL:-5}"
    local key="${PWD}:${files[*]}"
    local now
    now=$(date +%s 2>/dev/null || printf '0')

    if [[ "$key" == "$_DAV2_SVC_KEY" ]] && (( ttl > 0 )) && (( now - _DAV2_SVC_TS < ttl )); then
        printf '%s\n' "$_DAV2_SVC_VAL"
        return 0
    fi

    local args=() file
    for file in "${files[@]}"; do
        args+=(-f "$file")
    done

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
        local detected
        detected=$(_get_compose_file) || return 1
        files=("$detected")
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
        local detected
        detected=$(_get_compose_file) || return 1
        files=("$detected")
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
        local detected
        detected=$(_get_compose_file) || return 1
        files=("$detected")
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
        local detected
        detected=$(_get_compose_file) || return 1
        files=("$detected")
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
