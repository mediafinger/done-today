#!/usr/bin/env bash
#
# Install (or remove) the nightly backup as a launchd user agent.
#
# launchd rather than cron, and rather than a SolidQueue recurring task:
#
#   * cron skips a run outright if the laptop was asleep at the scheduled time.
#     launchd's StartCalendarInterval fires the missed run once the machine wakes,
#     which is the behaviour you want on a machine that is not up at 03:00.
#   * a SolidQueue recurring task only fires while `bin/jobs` is running, and the
#     jobs line is commented out in Procfile.dev. A backup must not depend on the
#     app being up -- especially since the times you most want a backup are the
#     times the app is broken.
#
# Usage:
#   script/install_backup_schedule.sh           # install and start
#   script/install_backup_schedule.sh --at 04:30
#   script/install_backup_schedule.sh --status
#   script/install_backup_schedule.sh --uninstall
#
set -euo pipefail

LABEL="com.mediafinger.done-today-backup"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${DONE_BACKUP_LOG_DIR:-$HOME/db_backups/done_today/logs}"
AT="03:00"
action="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --at) AT="${2:-}"; shift 2 ;;
    --uninstall) action="uninstall"; shift ;;
    --status) action="status"; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

uid="$(id -u)"

case "$action" in
  uninstall)
    launchctl bootout "gui/$uid/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "removed $LABEL"
    exit 0
    ;;
  status)
    launchctl print "gui/$uid/$LABEL" 2>/dev/null | sed -n '1,12p' || echo "$LABEL is not loaded"
    exit 0
    ;;
esac

hour="${AT%%:*}"
minute="${AT##*:}"
[[ "$hour" =~ ^[0-9]{1,2}$ && "$minute" =~ ^[0-9]{1,2}$ ]] || { echo "bad --at time: $AT (expected HH:MM)" >&2; exit 1; }

mkdir -p "$LOG_DIR" "$(dirname "$PLIST")"

# launchd starts agents with a minimal PATH that does not include Homebrew, so the
#   directory holding pg_dump has to be passed in explicitly.
pg_bin_dir="$(dirname "$(command -v pg_dump)")"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$REPO_DIR/script/db_backup.sh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$REPO_DIR</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$pg_bin_dir:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>DONE_DB_NAME</key>
    <string>${DONE_DB_NAME:-done_development}</string>
    <key>DONE_BACKUP_DIR</key>
    <string>${DONE_BACKUP_DIR:-$HOME/db_backups/done_today}</string>
  </dict>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$((10#$hour))</integer>
    <key>Minute</key>
    <integer>$((10#$minute))</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/backup.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/backup.error.log</string>

  <key>RunAtLoad</key>
  <false/>
  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$uid/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$uid" "$PLIST"

echo "installed $LABEL"
echo "  runs:    $REPO_DIR/script/db_backup.sh, daily at $AT"
echo "  logs:    $LOG_DIR/backup.log"
echo "  plist:   $PLIST"
echo
echo "Run it once now to check:  launchctl kickstart -p gui/$uid/$LABEL"
echo "Verify the newest dump:    script/db_restore.sh"
