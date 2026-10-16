# Developer README - Done Today

Welcome to the **Done Today** codebase! This document serves as an introduction to the project's architecture, design decisions, and conventions for new developers.

---

## 🚀 Technology Stack Overview

- **Ruby 4.0.7**: Managed via `chruby` (see [chruby](https://github.com/postmodern/chruby)).
- **Rails 8.1**: Leveraging modern defaults.
- **PostgreSQL**: Serving as the relational database engine.
- **Solid Stack**: Using PostgreSQL-backed engines for caching, background jobs, and WebSockets (replaces Redis/Memcached).
- **Pico CSS**: A minimalist, semantic CSS framework for styling.
- **Propshaft & Importmaps**: Modern, buildless Rails asset pipeline and JavaScript management.
- **Kamal v2**: Docker-based deployment orchestration.

---

## 📂 Core Architecture & Design Choices

### 1. Database Architecture & the "Solid" Stack
Instead of using Redis or Memcached, **Done Today** embraces the Rails 8 "Solid" stack. The application uses **four separate PostgreSQL databases** to isolate database load and simplify scaling:
- **Primary**: The main application data (schema: [schema.rb](file:///Users/andy/Dropbox/www/2025/done_today/db/schema.rb)).
- **Cable**: ActionCable WebSocket subscription adapter backed by PostgreSQL (schema: [cable_schema.rb](file:///Users/andy/Dropbox/www/2025/done_today/db/cable_schema.rb)).
- **Cache**: Solid Cache stores fragment caches in PostgreSQL (schema: [cache_schema.rb](file:///Users/andy/Dropbox/www/2025/done_today/db/cache_schema.rb)).
- **Queue**: Solid Queue handles background processing via ActiveJob in PostgreSQL (schema: [queue_schema.rb](file:///Users/andy/Dropbox/www/2025/done_today/db/queue_schema.rb)).

The database connections are defined in [database.yml](file:///Users/andy/Dropbox/www/2025/done_today/config/database.yml).

### 2. Configuration Management via `AppConf`
To prevent the ad-hoc reading of environment variables across the codebase, we use a custom configuration manager in [app_conf.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/app_conf.rb):
- All environment variables are registered at boot time with type-safety, default values, and required validation.
- Missing required configuration values raise `KeyError` on boot to prevent runtime errors.
- You can perform type-agnostic comparisons using `AppConf.is?(var, value)`.
- Local secrets/overrides should be added to [app_conf.local.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/app_conf.local.rb), which is gitignored.

### 3. Authentication & Sessions
The project utilizes custom cookie-based signed session handling modeled after standard Rails 8 conventions:
- The [Session](file:///Users/andy/Dropbox/www/2025/done_today/app/models/session.rb) model is backed by the database and only links the cookie to its `User`. Org and project are part of the path, see below.
- Authentication logic is encapsulated in the [Authentication](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/authentication.rb) controller concern.
- The [User](file:///Users/andy/Dropbox/www/2025/done_today/app/models/user.rb) model uses `has_secure_password` for password digestion.
- Changing the email stores `users.unconfirmed_email`; the email only changes through the link mailed to the new address. The old address gets a link to cancel the change, or to undo it within 7 days, which also ends every session ([Users::EmailChangesMailer](file:///Users/andy/Dropbox/www/2025/done_today/app/mailers/users/email_changes_mailer.rb)).
- Each user has a `time_zone` (IANA identifier, default `Europe/Berlin`). `ApplicationController` wraps every request in `Time.use_zone(current_user.time_zone)`, so `Time.zone.today` (the date navigation, the lock on past days, `/` landing on today) is the user's date. Entry dates stay plain dates; signed-out pages and jobs use `AppConf.timezone`.
- Password safety is verified against compromised credentials database using HIBP (Have I Been Pwned) via the `not_pwned` validator.

### 4. Multi-Tenancy & Context Scoping
The app supports multi-tenant organization boundaries and project selection:
- Thread-safe globals are stored using ActiveSupport's `CurrentAttributes` in the [Current](file:///Users/andy/Dropbox/www/2025/done_today/app/models/current.rb) model.
- Org and project are part of the path, nothing is selected in the session: `/:org_slug` (the org's projects),
  `/:org_slug/settings`, `/:org_slug/members`, `/:org_slug/:project_slug` (the project page) and below it
  `days/2026-10-15(/edit)`, `weeks/2026-W42`, `tags/:tag`, `members/:id/entries`, `entries`.
  `Sluggable::RESERVED_SLUGS` keeps org and project slugs clear of the app's paths, one list for both levels.
- Scoping concerns load the context from the path on each request:
  - [RequestContext](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/request_context.rb) (IP, request ID, user agent).
  - [OrgScope](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/org_scope.rb) (`set_current_org`: `Current.org` and `Current.member`, through the user's active memberships, else 404).
  - [ProjectScope](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/project_scope.rb) (`set_current_project`: `Current.project`, among the projects the member may read, else 404).
- Build links with both slugs, e.g. `day_path(org, project, date)` (`Org#to_param` and `Project#to_param` are the slugs).
- Both scopes remember what was opened on the user (`last_org_id`, `last_project_id`). `/` sends the user to today in that
  project, or in their only one ([LandingService](file:///Users/andy/Dropbox/www/2025/done_today/app/services/landing_service.rb)), else lists their orgs and projects.
- Authorization uses [ActionPolicy](https://actionpolicy.evilmartians.io), policies in `app/policies`. The subject is `current_member`
  (roles depend on the org), nil outside of an org. `ApplicationPolicy` denies a nil or archived member and records of another org
  in pre-checks, `ProjectPolicy` lets org managers and owners through (except `create_entry?`).
  - Org roles: `member`, `manager` and `owner` are internals, they list every project of the org (`ProjectPolicy` scope `:listable`) and
    the members (`/:org/members`, read-only for members). A `manager` does what an owner does, except giving or taking the owner role
    (`MemberPolicy#grant_owner?`, also for invitations, and inviting a deactivated owner back) and changing, deactivating or reactivating an owner. A `guest` is an external: they only see the projects they participate in,
    never lead a project, and are deactivated when their last participation is removed. Project leads only add the guests
    of the projects they manage (`MemberPolicy` scope `:addable`), and invite new guests to them (`ProjectPolicy#invite_guest?`,
    `Orgs::GuestInvitationsController`). A guest invitation carries the project and the project role.
  - A record the member may not read is a 404: look it up through a scope, `authorized_scope(current_org.projects).find_by!(...)`.
  - A record they may read but not change is a 403: `authorize! record` (rule from the action name, see the `alias_rule`s),
    `ActionPolicy::Unauthorized` renders `application/error_403`. In views: `allowed_to?(:manage?, project)`.
  - A change decided by its new value (a member's or invitation's role) is authorized with the change assigned, before saving:
    `member.assign_attributes(...)`, `authorize! member`. The policy reads `role` and `role_in_database`, the controller
    checks no roles itself. `InvitationPolicy` decides who sends, resends and revokes an invitation.
  - Outside of controllers include `ActionPolicy::Behaviour` with `authorize :member` and call `authorized_scope` / `allowed_to?`
    (see `LandingService`). `ProjectPolicy.new(...)` only where the memoized policy answered before a change in the same request.
  - `verify_authorized` and `verify_authorized_scoped` are on for every controller: an action calls `authorize!` and
    `authorized_scope` (the project lookup counts), or declares `skip_verify_authorized(_scoped)` with a comment why.
  - `spec/requests/authorization_matrix_spec.rb` checks every endpoint against every persona, `spec/policies` the rules and scopes,
    `spec/requests/authorization_verified_spec.rb` sends a request to every route so a forgotten `authorize!` fails.

### 5. Domain Model & PostgreSQL-specific Features
- **Where classes live**:
  - `app/models`: Active Record models (`ApplicationRecord` subclasses), plus `Current` (`ActiveSupport::CurrentAttributes`).
  - `app/services`: classes with a `.call(...)`, not instantiated by their callers (`RecordHistoryService`, `LandingService`, `OrgSetup`).
  - `app/values`: read-only objects built from their input, then read (`EntryLog`, `TimeSummary`, `PeriodSummary`, `TimeValidation`, `DaysExport`, `MonthExport`, and the `SyntaxGuide` examples). No persistence, no `.call`. Specs live in `spec/values`.
- **UUIDs**: The primary database uses `gen_random_uuid()` from PostgreSQL's `pgcrypto` extension for all primary/foreign keys (except the auto-incrementing `sessions` table).
- **PostgreSQL Enums**: The task status utilizes a custom PostgreSQL enum type `entry_status` (`["todo", "doing", "done"]`), the user's display preference `display_mode` (`["system", "light", "dark"]`), the org role of members and invitations `org_role` (`["guest", "member", "manager", "owner"]`), the project role of participants `project_role` (`["observer", "participant", "lead"]`). Both are ranked weakest first.

### 6. Auditing & Record History
For auditing operations within organizations, we implement a lightweight event-logging system:
- Modifying actions invoke `RecordHistoryService` via [ApplicationRecord](file:///Users/andy/Dropbox/www/2025/done_today/app/models/application_record.rb) helpers: `create_with_history`, `update_with_history`, and `destroy_with_history`.
- Logged changes are saved to the [RecordHistory](file:///Users/andy/Dropbox/www/2025/done_today/app/models/record_history.rb) model, which stores metadata and diffs using a PostgreSQL `JSONB` column.
- Saved history records are marked as read-only.

### 7. UI / Styling Decisions
- **Classless CSS**: The codebase styles semantic HTML elements by default using **Pico CSS** ([pico.amber.css](file:///Users/andy/Dropbox/www/2025/done_today/app/assets/stylesheets/pico.amber.css)). This allows us to write standard semantic HTML (e.g. `<main>`, `<details>`, `<article>`) without bloating class attributes.
- **Dark Mode**: Supports light, dark, and system color preferences, stored in `users.display_mode` (PostgreSQL enum `display_mode`, default `system`) and set on the account page via [DisplayModesController](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/users/display_modes_controller.rb). The layout renders `light`/`dark` as `data-theme` on `<html>`; `system` omits it so Pico follows the OS setting. Signed-out pages always follow the OS setting.
- **No Node.js build step**: JavaScript is managed using [importmap.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/importmap.rb) and executed using native ES modules.

---

## 🛠️ Development & Deployment

### Local Development Setup
1. **Ruby**: Ensure you have selected Ruby 4.0.7:
   ```bash
   chruby ruby-4.0.7
   ```
2. **Database Setup**: Start your local PostgreSQL server and configure [app_conf.local.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/app_conf.local.rb) with credentials if they differ from the defaults. Then run:
   ```bash
   bin/rails db:setup
   ```
3. **Start Server**:
   ```bash
   bin/rails server
   ```

### Admin and Dev Areas
- **`/admin`** (admins only): links to **`/admin/mission_control_jobs`** (Mission Control, the Solid Queue dashboard).
  [AdminConstraint](file:///Users/andy/Dropbox/www/2025/done_today/app/route_constraints/admin_constraint.rb) routes only an admin's
  session there, everyone else gets what an unknown path answers (404, the sign-in page when signed out).
  [AdminController](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/admin_controller.rb) checks again through
  `AdminPolicy` (asked for the user, not a member) and is the base controller of Mission Control
  ([config/initializers/mission_control.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/initializers/mission_control.rb)).
  New admin pages go below `Admins::` and inherit from `AdminController`.
- **Admins are the developers of the app**, unrelated to the org roles (owner, manager) and project leads.
  Admins see the list of admins on `/settings`.
- **Make a user admin** only in the console or a data migration, never through the UI (`admin` is not a permitted param):
  ```bash
  bin/rails runner 'User.find_by!(email: "you@example.com").update!(admin: true)'
  ```
- **`/dev`** (development only): links to **`/dev/letter_opener`** (letter_opener_web), where development mail is delivered
  instead of being sent.

### Database Backups

`bin/rails db:seed` truncates every table, and the development database is where the
real logging happens -- so backups are not optional here. Seeding now refuses to run
against a non-empty database unless `SEED_FORCE=1` is set.

```bash
rake db:backup          # dump to ~/db_backups/done_today (override with DONE_BACKUP_DIR)
rake db:backup:verify   # restore the newest dump into a scratch DB, then drop it
rake db:backup:list     # what is on disk
```

The scripts behind those tasks are plain bash and plain `pg_dump`, on purpose: a
backup has to keep working on the day the app does not boot.

- [script/db_backup.sh](script/db_backup.sh) writes a compressed custom-format dump to
  a `.part` file, checks it with `pg_restore --list`, and only then moves it into
  place. An unverified dump is not a backup.
- [script/db_restore.sh](script/db_restore.sh) defaults to restoring into a throwaway
  database and dropping it again, which is the "does this actually load?" path.
  Restoring over a real database needs `--force` **and** typing the database name.
- [script/install_backup_schedule.sh](script/install_backup_schedule.sh) installs a
  launchd agent that runs the backup nightly:

  ```bash
  script/install_backup_schedule.sh --at 03:00
  script/install_backup_schedule.sh --status
  script/install_backup_schedule.sh --uninstall
  ```

  launchd rather than cron, because cron silently skips a run if the machine was
  asleep while launchd fires it on wake. Not a SolidQueue recurring task either: that
  only runs while `bin/jobs` is up, and a backup must not depend on the app being up.

Retention is left to the backup folder. Set `DONE_BACKUP_KEEP_DAYS` if you would
rather the script prune old dumps itself.

---

### Deployment
Deployments are managed via **Kamal v2** (configured in [deploy.yml](file:///Users/andy/Dropbox/www/2025/done_today/config/deploy.yml)):
- Solid Queue is configured to run inside the Puma process in production (`SOLID_QUEUE_IN_PUMA: true`) to minimize host resource consumption and simplify container setups.
- Active Storage and database volume persistence are backed by Docker host volumes.
