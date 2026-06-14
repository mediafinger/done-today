# Developer README - Done Today

Welcome to the **Done Today** codebase! This document serves as an introduction to the project's architecture, design decisions, and conventions for new developers.

---

## 🚀 Technology Stack Overview

- **Ruby 4.0.2**: Managed via `chruby` (see [chruby](https://github.com/postmodern/chruby)).
- **Rails 8.0**: Leveraging modern defaults.
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
- The [Session](file:///Users/andy/Dropbox/www/2025/done_today/app/models/session.rb) model is backed by the database and stores the association to the current `User`, selected `Org`, and selected `Project`.
- Authentication logic is encapsulated in the [Authentication](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/authentication.rb) controller concern.
- The [User](file:///Users/andy/Dropbox/www/2025/done_today/app/models/user.rb) model uses `has_secure_password` for password digestion.
- Password safety is verified against compromised credentials database using HIBP (Have I Been Pwned) via the `not_pwned` validator.

### 4. Multi-Tenancy & Context Scoping
The app supports multi-tenant organization boundaries and project selection:
- Thread-safe globals are stored using ActiveSupport's `CurrentAttributes` in the [Current](file:///Users/andy/Dropbox/www/2025/done_today/app/models/current.rb) model.
- Scoping concerns dynamically load context on each request:
  - [RequestContext](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/request_context.rb) (IP, request ID, user agent, display modes).
  - [OrgScope](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/org_scope.rb) (populates `Current.org` and `Current.member`).
  - [ProjectScope](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/project_scope.rb) (populates `Current.project`).
- Switching context is routed by organization and project slug paths (e.g. `/open/:slug_org(/:slug_project)`) handled by [SwitchOrgsController](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/switch_orgs_controller.rb).

### 5. Domain Model & PostgreSQL-specific Features
- **UUIDs**: The primary database uses `gen_random_uuid()` from PostgreSQL's `pgcrypto` extension for all primary/foreign keys (except the auto-incrementing `sessions` table).
- **PostgreSQL Arrays**: Membership and participation roles are stored as array columns (`text[]`). Role querying utilizes specialized Postgres operators (e.g., `&&` for intersection, `@>` for containment).
- **PostgreSQL Enums**: The task status utilizes a custom PostgreSQL enum type `entry_status` (`["todo", "doing", "done"]`).
- **Array Validation**: To validate postgres array columns, we use a custom [ArrayInclusionValidator](file:///Users/andy/Dropbox/www/2025/done_today/app/validators/array_inclusion_validator.rb).

### 6. Auditing & Record History
For auditing operations within organizations, we implement a lightweight event-logging system:
- Modifying actions invoke `RecordHistoryService` via [ApplicationRecord](file:///Users/andy/Dropbox/www/2025/done_today/app/models/application_record.rb) helpers: `create_with_history`, `update_with_history`, and `destroy_with_history`.
- Logged changes are saved to the [RecordHistory](file:///Users/andy/Dropbox/www/2025/done_today/app/models/record_history.rb) model, which stores metadata and diffs using a PostgreSQL `JSONB` column.
- Saved history records are marked as read-only.

### 7. UI / Styling Decisions
- **Classless CSS**: The codebase styles semantic HTML elements by default using **Pico CSS** ([pico.amber.css](file:///Users/andy/Dropbox/www/2025/done_today/app/assets/stylesheets/pico.amber.css)). This allows us to write standard semantic HTML (e.g. `<main>`, `<details>`, `<article>`) without bloating class attributes.
- **Dark Mode**: Supports light, dark, and system color preferences. The theme is applied dynamically using a `data-theme` attribute on the `<html>` tag, populated from the user's preference cookies in [DisplayModesController](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/users/display_modes_controller.rb).
- **No Node.js build step**: JavaScript is managed using [importmap.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/importmap.rb) and executed using native ES modules.

---

## 🛠️ Development & Deployment

### Local Development Setup
1. **Ruby**: Ensure you have selected Ruby 4.0.2:
   ```bash
   chruby ruby-4.0.2
   ```
2. **Database Setup**: Start your local PostgreSQL server and configure [app_conf.local.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/app_conf.local.rb) with credentials if they differ from the defaults. Then run:
   ```bash
   bin/rails db:setup
   ```
3. **Start Server**:
   ```bash
   bin/rails server
   ```

### Deployment
Deployments are managed via **Kamal v2** (configured in [deploy.yml](file:///Users/andy/Dropbox/www/2025/done_today/config/deploy.yml)):
- Solid Queue is configured to run inside the Puma process in production (`SOLID_QUEUE_IN_PUMA: true`) to minimize host resource consumption and simplify container setups.
- Active Storage and database volume persistence are backed by Docker host volumes.
