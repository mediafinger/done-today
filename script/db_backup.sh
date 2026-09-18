#!/usr/bin/env bash
#
# Dump the Done Today database to a timestamped file outside the repo.
#
# Deliberately plain bash and plain pg_dump: a backup has to keep working on the
#   day the app does not boot, so it does not load Rails and does not read
#   config/database.yml. It takes the same env vars AppConf does, with the same
#   defaults, so `DONE_DB_NAME=... script/db_backup.sh` matches the app.
#
# The dump is written to a .part file, verified with `pg_restore --list`, and only
#   then moved into place. An unverified dump is not a backup, and a half-written
#   file that looks like one is worse than no file at all.
#
# Usage:
#   script/db_backup.sh                 # back up the development database
#   DONE_DB_NAME=done_production script/db_backup.sh
#   DONE_BACKUP_DIR=/Volumes/ext script/db_backup.sh
#
# Exit codes: 0 ok, 1 usage/config error, 2 dump failed, 3 verification failed.
#
set -euo pipefail

DB_NAME="${DONE_DB_NAME:-done_development}"
DB_HOST="${DONE_DB_HOST:-localhost}"
DB_PORT="${DONE_DB_PORT:-5432}"
DB_USERNAME="${DONE_DB_USERNAME:-}"
BACKUP_DIR="${DONE_BACKUP_DIR:-$HOME/db_backups/done_today}"
KEEP_DAYS="${DONE_BACKUP_KEEP_DAYS:-}"

timestamp="$(date +%Y%m%d-%H%M%S)"
target="$BACKUP_DIR/${DB_NAME}-${timestamp}.dump"
partial="$target.part"

log() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '%s  ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit "${2:-1}"; }

# An empty username means "let libpq pick the OS user", which is how a default
#   Homebrew Postgres is set up. Only pass -U when one was asked for.
psql_args=(--host "$DB_HOST" --port "$DB_PORT")
[ -n "$DB_USERNAME" ] && psql_args+=(--username "$DB_USERNAME")

command -v pg_dump >/dev/null || fail "pg_dump is not on PATH"
command -v pg_restore >/dev/null || fail "pg_restore is not on PATH"

mkdir -p "$BACKUP_DIR" || fail "cannot create $BACKUP_DIR"

psql "${psql_args[@]}" --dbname "$DB_NAME" --quiet --no-align --tuples-only \
  --command 'select 1' >/dev/null 2>&1 || fail "cannot connect to database '$DB_NAME'"

log "dumping $DB_NAME -> $target"

# -Fc is the custom format: compressed, and pg_restore can read a table list out of
#   it, which is what makes the verification step below possible.
if ! pg_dump "${psql_args[@]}" --dbname "$DB_NAME" --format=custom --compress=9 \
     --file "$partial" 2>/tmp/done_backup_err.$$; then
  rm -f "$partial"
  fail "pg_dump failed: $(cat /tmp/done_backup_err.$$; rm -f /tmp/done_backup_err.$$)" 2
fi
rm -f /tmp/done_backup_err.$$

# Verify before publishing: a dump pg_restore cannot read is not a backup.
if ! pg_restore --list "$partial" >/dev/null 2>&1; then
  rm -f "$partial"
  fail "dump is unreadable, discarded" 3
fi

table_count="$(pg_restore --list "$partial" | grep -c ' TABLE DATA ' || true)"
[ "$table_count" -gt 0 ] || log "WARNING: the dump contains no table data"

mv "$partial" "$target"

size="$(du -h "$target" | cut -f1)"
log "ok: $size, $table_count tables with data"

# Retention is opt-in. The folder is expected to handle its own pruning; set
#   DONE_BACKUP_KEEP_DAYS to have this script do it instead.
if [ -n "$KEEP_DAYS" ]; then
  log "pruning dumps older than $KEEP_DAYS days"
  find "$BACKUP_DIR" -name "${DB_NAME}-*.dump" -type f -mtime "+$KEEP_DAYS" -print -delete
fi

printf '%s\n' "$target"
