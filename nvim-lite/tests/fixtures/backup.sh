#!/usr/bin/env bash
# The most common file on a server, and the one that had no parser at all.
set -euo pipefail

readonly DEST="${BACKUP_DEST:-/var/backups}"
readonly KEEP_DAYS=${KEEP_DAYS:-14}

log() { printf '[%s] %s\n' "$(date +%FT%T)" "$*" >&2; }

dump_one() {
    local db="$1" out="${DEST}/${db}-$(date +%F).sql.gz"
    log "dumping ${db} -> ${out}"
    pg_dump --no-owner "$db" | gzip -9 > "$out" || {
        log "FAILED: $db"
        return 1
    }
}

main() {
    [[ -d "$DEST" ]] || mkdir -p "$DEST"
    local failed=0 db
    for db in "$@"; do
        dump_one "$db" || failed=$((failed + 1))
    done
    find "$DEST" -name '*.sql.gz' -mtime "+${KEEP_DAYS}" -delete
    case "$failed" in
        0) log "all good" ;;
        *) log "$failed failed"; exit 1 ;;
    esac
}

main "$@"
