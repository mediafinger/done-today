# Run done as a background service on macOS

These steps keep the app at <http://127.0.0.1:3333> whenever you are logged in.
launchd starts it at login and restarts it if it crashes. An optional second job
checks `origin/main` every five minutes, moves the app to the newest commit and
restarts it.

The service runs in the `development` environment against `done_development`,
which holds the real data. It is the same database `bin/dev` uses.

## 1. Prerequisites

* **PostgreSQL starts at login.** In Postgres.app, open *Settings* and turn on
  *Automatically start at login* for the server that holds `done_development`.
* **chruby** is installed via Homebrew, and the Ruby named in `.ruby-version` is
  installed (`ruby-install ruby 4.0.9`).

## 2. Create a separate checkout for the service

The service gets its own worktree on a detached `origin/main`. Don't run it from
the checkout you develop in:

* The development checkout switches branches, and the service would then serve
  whatever branch is checked out there.
* `main` can only be checked out in one worktree at a time.
* The service checkout stays outside Dropbox, so the churn in `log/` and `tmp/`
  isn't synced.

```bash
cd ~/Dropbox/www/2025/done_today
git fetch origin
git worktree add --detach ~/Services/done_today origin/main

# the gitignored files the app needs to boot
cp config/master.key ~/Services/done_today/config/
cp config/app_conf.local.rb ~/Services/done_today/config/  # only if you use one

cd ~/Services/done_today
chruby "$(cat .ruby-version)"
bundle install

mkdir -p ~/Library/Logs/done_today
```

## 3. The server script

launchd starts jobs with an almost empty environment, so this script loads the
Ruby from `.ruby-version` itself. It runs the server in the foreground, because
launchd has to own the process to restart it.

```bash
cat > ~/Services/done_today-server.sh <<'EOF'
#!/usr/bin/env bash
# Runs Done Today in the foreground for launchd, which restarts it when it exits.
set -eo pipefail

cd "$HOME/Services/done_today"

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
chruby "$(cat .ruby-version)"

# launchd only ever runs one instance, so a pid file left behind by a crash is stale
rm -f tmp/pids/server.pid

exec bin/rails server -b 127.0.0.1 -p 3333
EOF
chmod +x ~/Services/done_today-server.sh
```

## 4. The launch agent

```bash
cat > ~/Library/LaunchAgents/com.mediafinger.done-today.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mediafinger.done-today</string>

  <key>ProgramArguments</key>
  <array>
    <string>$HOME/Services/done_today-server.sh</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>

  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/done_today/server.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/done_today/server.error.log</string>
</dict>
</plist>
EOF

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mediafinger.done-today.plist
```

What the keys do:

* `RunAtLoad` starts the app as soon as the agent is loaded, which is at every
  login.
* `KeepAlive` restarts it whenever it exits.
* `ThrottleInterval` waits 10 seconds between restarts, so a broken boot doesn't
  spin.

The app now answers at <http://127.0.0.1:3333>.

A launch agent starts when you log in, not while the Mac sits at the login
window. Postgres.app has the same limit, so it would not help to start the app
any earlier. If the app should be up right after a reboot, turn on automatic
login (*System Settings → Users & Groups*).

## 5. Optional: restart when `main` changes

The update script does nothing while `origin/main` is where the service checkout
already is. When `origin/main` has moved, it:

1. checks out the new commit;
2. runs `bundle install`;
3. backs up the database before running any pending migration;
4. restarts the server.

```bash
cat > ~/Services/done_today-update.sh <<'EOF'
#!/usr/bin/env bash
# Moves the service checkout to the newest origin/main and restarts the app.
set -eo pipefail

cd "$HOME/Services/done_today"

git fetch --quiet origin main
target="$(git rev-parse origin/main)"
[ "$(git rev-parse HEAD)" = "$target" ] && exit 0

echo "$(date '+%F %T') updating $(git rev-parse --short HEAD) -> ${target:0:7}"

# --force: this checkout is never edited by hand; a schema.rb rewritten by
#   db:migrate must not block the next update
git checkout --quiet --force --detach "$target"

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
chruby "$(cat .ruby-version)"
bundle install --quiet

# migrations touch the real data, so they only run after a fresh backup
if bin/rails db:migrate:status | grep -q '^ *down '; then
  bin/rails db:backup
  bin/rails db:migrate
fi

launchctl kickstart -k "gui/$(id -u)/com.mediafinger.done-today"
EOF
chmod +x ~/Services/done_today-update.sh

cat > ~/Library/LaunchAgents/com.mediafinger.done-today-update.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mediafinger.done-today-update</string>

  <key>ProgramArguments</key>
  <array>
    <string>$HOME/Services/done_today-update.sh</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/opt/libpq/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>

  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/done_today/update.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/done_today/update.error.log</string>
</dict>
</plist>
EOF

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mediafinger.done-today-update.plist
```

Notes on the update job:

* The `PATH` includes `libpq/bin`, because `db:backup` needs `pg_dump`.
* `git fetch` runs over SSH without a prompt, using the key's passphrase from the
  macOS keychain (`UseKeychain yes` in `~/.ssh/config`). If fetching fails,
  `update.error.log` says so.
* If `.ruby-version` names a Ruby that isn't installed yet, the update stops at
  `chruby`. Install that Ruby and the next run picks it up.

## Day to day

```bash
launchctl print gui/$(id -u)/com.mediafinger.done-today | head -20     # state, pid, last exit code
launchctl kickstart -k gui/$(id -u)/com.mediafinger.done-today         # restart the app
launchctl kickstart gui/$(id -u)/com.mediafinger.done-today-update     # check for a new main right now
tail -f ~/Library/Logs/done_today/*.log ~/Services/done_today/log/development.log
```

The service holds port 3333. To run `bin/dev` in your development checkout at the
same time, give it another port: `DONE_PORT=3335 bin/dev`.

To remove the service:

```bash
launchctl bootout gui/$(id -u)/com.mediafinger.done-today-update
launchctl bootout gui/$(id -u)/com.mediafinger.done-today
rm ~/Library/LaunchAgents/com.mediafinger.done-today*.plist ~/Services/done_today-*.sh
git -C ~/Dropbox/www/2025/done_today worktree remove --force ~/Services/done_today
```
