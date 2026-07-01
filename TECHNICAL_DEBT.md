# Technical Debt & Issues

Analysis of bugs, security concerns, code smells, and incomplete features in the **Done Today** codebase.

---

## 🔒 Security Concerns

### 8. Content Security Policy is entirely disabled
**File:** [content_security_policy.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/initializers/content_security_policy.rb)

The entire CSP initializer is commented out. Without a CSP header, the application is more vulnerable to XSS attacks. This should at minimum be enabled in `report-only` mode to gather data.

### 9. DNS rebinding protection is disabled
**File:** [production.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/environments/production.rb#L82-L89)

`config.hosts` is commented out. Without host authorization, the app is vulnerable to DNS rebinding attacks and `Host` header injection. This should be configured with the actual production hostname.

### 10. No authorization layer — only authentication
**Files:** All controllers under [app/controllers/orgs/](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs)

The application authenticates users but has **no authorization framework** (e.g., Pundit, Action Policy). Several controllers directly query data without verifying the user has permission:

- [EntriesController#update](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L78-L87): Any authenticated user in the org can update **any** entry in the project, not just their own.
- [ProjectsController#show](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/projects_controller.rb#L3-L33): Any member can view any project, regardless of participation (the TODO at line 4 acknowledges this).
- [MembersController#update](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/members_controller.rb#L15): Any member can update roles of other members — the `before_action :authenticate_owner!` is commented out.

### 11. `SwitchOrgsController#switch_to` lacks membership validation before project access
**File:** [switch_orgs_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/switch_orgs_controller.rb#L45-L63)

The `Org.find_by!(slug:)` lookup is not scoped to the current user's organizations. Any authenticated user can attempt to look up any org by slug. While `current_user.memberships.find_by(org:)` guards the redirect, the Org record is still fetched (information leakage via timing/exceptions).

### 12. Inline JavaScript in `_new_entry.html.erb` is an XSS vector
**File:** [_new_entry.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/orgs/entries/_new_entry.html.erb#L19-L23)

```erb
document.location.hash="#<%= @scoll_to %>";
```

The `@scroll_to` value (from `params[:scroll_to]`) is interpolated directly into a `<script>` tag without escaping. An attacker could craft a URL with a malicious `scroll_to` parameter to inject JavaScript. This should use `j()` / `escape_javascript()` or, better, a Stimulus controller.

### 13. Production mailer URL host is placeholder
**File:** [production.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/environments/production.rb#L61)

```ruby
config.action_mailer.default_url_options = { host: "example.com" }
```

Password reset emails in production will contain links pointing to `example.com`.

### 14. Active Storage uses local disk in production
**File:** [production.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/environments/production.rb#L25)

```ruby
config.active_storage.service = :local
```

User-uploaded profile pictures are stored on the container's filesystem. With Kamal deployments, files will be **lost on every deploy** unless the Docker volume mount covers the storage directory (partially mitigated by the `done_today_storage` volume in `deploy.yml`, but fragile).

### 15. `PasswordsController` skips authentication entirely
**File:** [passwords_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/users/passwords_controller.rb#L3)

`skip_before_action :require_authentication` applies to **all** actions, including `edit` and `update`. While the token provides security, there is no rate limiting on the `edit`/`update` actions, potentially allowing brute-force token guessing.

### 16. Session cookie not scoped to domain
**File:** [authentication.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/concerns/authentication.rb#L52)

The session cookie is set without a `domain:` or `secure:` option. While Rails' `force_ssl` handles the secure flag in production, explicitly setting it is safer.

---

## 🧹 Code Smells & Design Issues

### 17. `Orgs::EntriesController#index` is doing too much
**File:** [entries_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L20-L48)

The `index` action handles two modes (`read`/`edit`), three grouping strategies (`date`/`member`/`project`), optional member filtering, and day initialization — all in one action with complex branching. The existing TODOs (lines 6–18, 34) acknowledge this.

### 18. `DaysController` is entirely dead code
**File:** [days_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/days_controller.rb)

Every action body is commented out. The controller still has routes (commented out in `routes.rb` line 27). The corresponding views ([show.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/orgs/days/show.html.erb), [index_of_one_member.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/orgs/days/index_of_one_member.html.erb)) are orphaned.

### 19. `MembersController` actions are stubs
**File:** [members_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/members_controller.rb)

`index`, `create`, and `destroy` are empty method bodies. `update` performs validation and role manipulation but never calls `member.save` — changes are computed and then discarded.

### 21. `ApplicationHelper` includes concerns designed for controllers
**File:** [application_helper.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/helpers/application_helper.rb)

The helper includes `Authentication`, `OrgScope`, and `ProjectScope` — concerns with `before_action` hooks, `redirect_to` calls, and controller-specific logic. These modules assume a controller context (`request`, `cookies`, `session`, `redirect_to`) that does not exist in helper/view contexts. The `helper_method` declarations in the concerns already make the reader methods available to views without this include.

### 23. `@entries.size` triggers full table count in `ProjectsController`
**File:** [projects_controller.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/projects_controller.rb#L9)

```ruby
@entries_count = @project.entries.size
```

This issues a `SELECT COUNT(*)` that can be expensive. If only used for "has entries?", prefer `.any?`; if displayed, consider caching or using `counter_cache`.

### 24. View renders user-controlled `@group_by` unescaped
**File:** [index.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/orgs/entries/index.html.erb#L8)

```erb
group_by '<%= @group_by %>' is invalid
```

While `@group_by` comes from `params[:group_by]` and Rails auto-escapes ERB output, this renders arbitrary user input as visible page content in an error-like message. The controller doesn't validate `@group_by` against a whitelist before it reaches the view.

### 25. `Entry#today?`, `#future?`, `#past?` ignore timezones
**File:** [entry.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/models/entry.rb#L27-L37)

All three methods use `Time.current.to_date` which depends on `Time.zone`. The `# TODO: timezone correction` comments acknowledge this but no timezone tracking exists for users or orgs.

### 27. N+1 queries in org switcher partial
**File:** [_org_switcher.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/shared_partials/_org_switcher.html.erb#L12)

The view iterates `current_user.memberships.includes(:org, participations: :project)` — however `.order("org.name asc")` references the table name without the Rails-conventional pluralization. Depending on ActiveRecord version and join strategy this may error or produce incorrect results. Additionally, each `member.org.name` and `participation.project.name` access could trigger lazy loads if the includes don't match the actual association paths.

### 28. Slug generation has a race condition
**Files:** [org.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/models/org.rb#L17-L23), [project.rb](file:///Users/andy/Dropbox/www/2025/done_today/app/models/project.rb#L18-L24)

```ruby
new_slug = "#{new_slug}-#{rand(99)}" while Org.exists?(slug: new_slug)
```

The `exists?` → `create` sequence has a TOCTOU (time-of-check, time-of-use) race. Two concurrent requests could check, both find the slug available, and one will fail on the unique DB index. The DB constraint catches it, but the exception is unhandled.

---

## 🏗️ Infrastructure & Configuration

### 30. `config.load_defaults 8.0` may be stale for Rails 8.1
**File:** [application.rb](file:///Users/andy/Dropbox/www/2025/done_today/config/application.rb#L27)

The Gemfile pins `rails ~> 8.1.3` but `config.load_defaults 8.0` loads the 8.0 defaults. This means any new 8.1 defaults (cache format changes, etc.) are not activated.

### 31. Pico CSS loaded from unpkg CDN in production without SRI
**File:** [_head.html.erb](file:///Users/andy/Dropbox/www/2025/done_today/app/views/layouts/_head.html.erb#L19)

```erb
stylesheet_link_tag "https://unpkg.com/@picocss/pico@latest/css/pico.amber.min.css"
```

- Using `@latest` means the stylesheet can change without notice, potentially breaking the UI.
- No Subresource Integrity (SRI) hash is provided, so a compromised CDN could inject malicious CSS.
- Combined with no CSP (issue #8), this broadens the attack surface.

### 32. `BUNDLE_WITHOUT="development"` in Dockerfile excludes the test group
**File:** [Dockerfile](file:///Users/andy/Dropbox/www/2025/done_today/Dockerfile#L26)

`BUNDLE_WITHOUT="development"` only excludes the development group; the `test` group gems are included in the production image. This bloats the image with `rspec`, `rubocop`, `factory_bot`, etc. It should be `BUNDLE_WITHOUT="development:test"`.

### 33. `deploy.yml` uses placeholder values
**File:** [deploy.yml](file:///Users/andy/Dropbox/www/2025/done_today/config/deploy.yml)

Contains `image: your-user/done_today`, `username: your-user`, server IP `192.168.0.1`, and proxy host `app.example.com`. Deploying with these defaults will fail or deploy to wrong targets.

---

## 📝 Summary of Inline TODOs Found

The codebase contains numerous inline `TODO` comments indicating acknowledged but unfinished work. Here's a consolidated listing:

| Location | TODO |
|---|---|
| [entries_controller.rb:6-18](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L6-L18) | Make entries#index the central point, add filters, grouping, sorting, pagination |
| [entries_controller.rb:16](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L16) | Cleanup, extract, simplify the controller |
| [entries_controller.rb:34](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L34) | Ensure edit mode uses correct project |
| [entries_controller.rb:65-69](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L65-L69) | Scan logs for #tags, autocomplete, tag queries |
| [entries_controller.rb:76](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/entries_controller.rb#L76) | Move entries in status 'todo' to another day |
| [days_controller.rb:4](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/days_controller.rb#L4) | Check if replaced by entries controller |
| [members_controller.rb:4](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/members_controller.rb#L4) | Add `before_action :authenticate_owner!` |
| [projects_controller.rb:4-6](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/projects_controller.rb#L4-L6) | Only display participant/owner-visible projects |
| [projects_controller.rb:23-30](file:///Users/andy/Dropbox/www/2025/done_today/app/controllers/orgs/projects_controller.rb#L23-L30) | Add filters, sorting, pagination |
| [record_history_service.rb:5](file:///Users/andy/Dropbox/www/2025/done_today/app/services/record_history_service.rb#L5) | Push to background job instead of inline creation |
| [entry.rb:28,32,36](file:///Users/andy/Dropbox/www/2025/done_today/app/models/entry.rb#L28) | Timezone correction for day comparison methods |
| [_select.html.erb:6](file:///Users/andy/Dropbox/www/2025/done_today/app/views/orgs/days/_select.html.erb#L6) | Add datepicker to select any day |
| [_org_switcher.html.erb:1](file:///Users/andy/Dropbox/www/2025/done_today/app/views/shared_partials/_org_switcher.html.erb#L1) | Extract all DB queries into a concern/current object |
