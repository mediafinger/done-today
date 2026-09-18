#!/usr/bin/env bash
#
# Restore a Done Today dump produced by script/db_backup.sh.
#
# Safe by default: with no --into, the dump is restored into a *scratch* database
#   (done_restore_check) and then dropped again. That is the "does this backup
#   actually load?" path, and it cannot touch anything real. Run it often -- an
#   untested backup is a guess.
#
# Restoring over a database that already has rows needs --force AND typing the
#   database name when prompted. That is on purpose: this script exists because a
#   database got wiped once already, and a restore tool is the obvious way to do it
#   again by accident.
#
# Usage:
#   script/db_restore.sh                          # verify the newest dump in a scratch DB
#   script/db_restore.sh --file path/to.dump      # verify a specific dump
#   script/db_restore.sh --list                   # list available dumps
#   script/db_restore.sh --into done_development --force   # real restore, prompts
#   script/db_restore.sh --into done_scratch      # into an empty/absent DB, no prompt
#
# Exit codes: 0 ok, 1 usage/config error, 2 restore failed, 3 refused by the user.
#
set -euo pipefail

DB_HOST="${DONE_DB_HOST:-localhost}"
DB_PORT="${DONE_DB_PORT:-5432}"
DB_USERNAME="${DONE_DB_USERNAME:-}"
BACKUP_DIR="${DONE_BACKUP_DIR:-$HOME/db_backups/done_today}"
SCRATCH_DB="done_restore_check"

dump_file=""
into=""
force="no"
do_list="no"

log() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '%s  ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit "${2:-1}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --file) dump_file="${2:-}"; shift 2 ;;
    --into) into="${2:-}"; shift 2 ;;
    --force) force="yes"; shift ;;
    --list) do_list="yes"; shift ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

psql_args=(--host "$DB_HOST" --port "$DB_PORT")
[ -n "$DB_USERNAME" ] && psql_args+=(--username "$DB_USERNAME")

command -v pg_restore >/dev/null || fail "pg_restore is not on PATH"

if [ "$do_list" = "yes" ]; then
  ls -lht "$BACKUP_DIR"/*.dump 2>/dev/null || fail "no dumps in $BACKUP_DIR"
  exit 0
fi

if [ -z "$dump_file" ]; then
  # shellcheck disable=SC2012 -- names are timestamped, so lexical order is chronological
  dump_file="$(ls -1 "$BACKUP_DIR"/*.dump 2>/dev/null | tail -1 || true)"
  [ -n "$dump_file" ] || fail "no dumps found in $BACKUP_DIR"
  log "using newest dump: $dump_file"
fi

[ -f "$dump_file" ] || fail "no such dump: $dump_file"
pg_restore --list "$dump_file" >/dev/null 2>&1 || fail "dump is unreadable: $dump_file" 2

db_exists() {
  psql "${psql_args[@]}" --dbname postgres --quiet --no-align --tuples-only \
    --command "select 1 from pg_database where datname = '$1'" 2>/dev/null | grep -q 1
}

# Exact, not pg_stat_user_tables.n_live_tup: that column is an estimate maintained by
#   ANALYZE and reads 0 on a freshly restored or never-analyzed database. A guard that
#   can under-report to zero is a guard that waves a clobber through.
row_count() {
  psql "${psql_args[@]}" --dbname "$1" --quiet --no-align --tuples-only --command "
    select coalesce(sum(cnt), 0) from (
      select (xpath(
        '/row/cnt/text()',
        query_to_xml(format('select count(*) as cnt from %I.%I', schemaname, relname), false, true, '')
      ))[1]::text::bigint as cnt
      from pg_stat_user_tables
    ) counts" 2>/dev/null || echo 0
}

verify_only="no"
if [ -z "$into" ]; then
  into="$SCRATCH_DB"
  verify_only="yes"
  log "no --into given: verifying into scratch database '$into'"
fi

# The guard, in two independent layers.
#
#   1. --force is required for ANY named target, whether or not it holds data. This
#      does not depend on counting anything, so no query result can wave it through.
#   2. If the target also holds rows, the name has to be typed out as well.
#
if [ "$verify_only" = "no" ] && [ "$force" != "yes" ]; then
  fail "restoring into '$into' needs --force (omit --into to verify in a scratch database)" 3
fi

if db_exists "$into"; then
  existing_rows="$(row_count "$into")"

  if [ "$existing_rows" -gt 0 ] && [ "$verify_only" = "no" ]; then
    printf "\n  About to DROP and recreate '%s', which holds %s rows.\n" "$into" "$existing_rows"
    printf "  This cannot be undone. Type the database name to continue: "
    read -r confirmation
    [ "$confirmation" = "$into" ] || fail "confirmation did not match, nothing was changed" 3
  fi

  log "dropping $into"
  dropdb "${psql_args[@]}" --if-exists "$into"
fi

log "creating $into"
createdb "${psql_args[@]}" "$into"

log "restoring $(basename "$dump_file") into $into"
if ! pg_restore "${psql_args[@]}" --dbname "$into" --no-owner --no-privileges \
     --exit-on-error "$dump_file" 2>/tmp/done_restore_err.$$; then
  printf '%s\n' "$(cat /tmp/done_restore_err.$$)" >&2
  rm -f /tmp/done_restore_err.$$
  fail "pg_restore failed" 2
fi
rm -f /tmp/done_restore_err.$$

# Prove the restore produced something usable, not just an empty schema.
summary="$(psql "${psql_args[@]}" --dbname "$into" --quiet --no-align --tuples-only --command "
  select string_agg(t.rel || '=' || t.n, ', ' order by t.rel)
  from (
    select 'orgs' as rel, count(*) as n from orgs
    union all select 'users', count(*) from users
    union all select 'projects', count(*) from projects
    union all select 'days', count(*) from days
    union all select 'entries', count(*) from entries
  ) t" 2>/dev/null || true)"

[ -n "$summary" ] || fail "restored database has no readable application tables" 2

log "restored ok: $summary"

if [ "$verify_only" = "yes" ]; then
  log "dropping scratch database $into"
  dropdb "${psql_args[@]}" --if-exists "$into"
  log "BACKUP VERIFIED: $dump_file"
fi
