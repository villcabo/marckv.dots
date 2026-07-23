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
