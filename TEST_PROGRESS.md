# Test Suite Progress

We have successfully implemented a comprehensive RSpec test suite for the **Done Today** application. Below is the summary of files created, tests covered, and known issues marked as pending.

## 📊 Summary of Created Spec Files

### Factories
* [spec/factories.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/factories.rb) — Definitions for User, Org, Member, Project, Participant, Day, Entry, Session, Integration, ProjectIntegration, and RecordHistory.

### Models & Helpers (Unit Specs)
* [spec/models/user_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/user_spec.rb) — Validation, normalizations, and association coverage.
* [spec/models/org_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/org_spec.rb) — Validation, association, and slug-generation callback coverage.
* [spec/models/member_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/member_spec.rb) — Validation, association, fallback name callback, scope filter, role mutations, and project/entry access logic coverage.
* [spec/models/project_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/project_spec.rb) — Validation, association, and slug-generation callback coverage.
* [spec/models/participant_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/participant_spec.rb) — Validation, callback assignment, role scopes, and project entry accessibility filters.
* [spec/models/day_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/day_spec.rb) — Association, date validations, and callback assignment coverage.
* [spec/models/entry_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/entry_spec.rb) — Association, status validations/helper predicates, and day timeline comparison predicates.
* [spec/models/session_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/session_spec.rb) — Validates associations.
* [spec/models/integration_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/integration_spec.rb) — Validation checks on credentials, templates, and services.
* [spec/models/project_integration_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/project_integration_spec.rb) — Association validation and callback org assignment.
* [spec/models/record_history_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/record_history_spec.rb) — Basic validation, read-only status checks. *(Has pending tests for Bug #22).*
* [spec/models/application_record_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/application_record_spec.rb) — Transaction wrappers with history recording (`create_with_history`, etc.). *(Has pending tests for Bug #5).*
* [spec/models/current_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/models/current_spec.rb) — Verifies side-effects of setting models in `Current` context.
* [spec/helpers/application_helper_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/helpers/application_helper_spec.rb) — Verifies ApplicationHelper module inclusions. *(Has pending tests for Bug #21).*

### Services & Validators
* [spec/services/record_history_service_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/services/record_history_service_spec.rb) — Verify `.call` persists record history under successful invocations.
* [spec/validators/array_inclusion_validator_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/validators/array_inclusion_validator_spec.rb) — Verify array inclusion limits and custom validation messages.

### Mailers
* [spec/mailers/passwords_mailer_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/mailers/passwords_mailer_spec.rb) — Verifies password reset instructions headers and contents. *(Has pending tests for mailer template location bug).*

### Controllers (Integration Specs)
* [spec/controllers/users/sessions_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/sessions_controller_spec.rb) — Sign-in, sign-out, session cookie generation, rate-limit settings check.
* [spec/controllers/users/passwords_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/passwords_controller_spec.rb) — Password reset request form, reset token validation, password updates.
* [spec/controllers/users/display_modes_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/display_modes_controller_spec.rb) — Switching display mode cookie settings and referrer redirection.
* [spec/controllers/users/preferences_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/preferences_controller_spec.rb) — Stub PreferencesController show and edit actions.
* [spec/controllers/orgs/entries_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/entries_controller_spec.rb) — Org-scoped entry retrieval under read and edit modes, new entry creation, updating logs/status.
* [spec/controllers/orgs/projects_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/projects_controller_spec.rb) — Listing projects, showing project timelines via slug, scoping check.
* [spec/controllers/orgs/members_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/members_controller_spec.rb) — Stub MembersController index, create, update, and destroy actions. *(Has pending tests for Bug #19 and parameter parsing).*
* [spec/controllers/orgs/settings_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/settings_controller_spec.rb) — Stub SettingsController show and edit actions.
* [spec/controllers/orgs/days_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/days_controller_spec.rb) — Stub DaysController index and show actions.
* [spec/controllers/switch_orgs_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/switch_orgs_controller_spec.rb) — Org and project switcher flow validation, authorization boundary checks.
* [spec/controllers/application_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/application_controller_spec.rb) — Default landing page checks and 404 response handler.
* [spec/controllers/app_org_base_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/app_org_base_controller_spec.rb) — Verifies require_member filter logic.

---

## 🔍 Pending Specs (Unresolved Code Bugs)

Consistent with instructions to test correct behavior while marking buggy features as `pending`, the following cases are marked as pending:

### 1. `RecordHistory` Query Methods (`RecordHistory` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #22
* **Issue:** `get_history_for_org_record`, `get_history_for_org_events`, and `get_history_for_user_events` call `where` internally but are defined as instance methods. They should be class methods.
* **Testing:** Written to expect class method behavior, marked as pending.
* [x] fixed, ensure tests work now

### 2. `RecordHistoryService.call` Keyword Arguments (`ApplicationRecord` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #5
* **Issue:** `ApplicationRecord#create_with_history` (and update/destroy wrappers) does not forward `org:` and `user:` arguments automatically, but `RecordHistoryService.call` defines them as mandatory keywords.
* **Testing:** Written to expect automated history tracking wrapper calls to work, marked as pending.
* not a bug, as org_id and user_id are stored without an AR relation
* [x] treat as fixed and adapt tests if necessary

### 3. `SwitchOrgsController#switch_to` lacks membership validation (`SwitchOrgsController` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #11
* **Issue:** Lack of membership validation prior to project query raises `NoMethodError` on `nil` member object.
* **Testing:** Asserts redirection to root path with alert for non-members, marked as pending.

### 4. `MembersController` Update and Parameter Parsing (`MembersController` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #19
* **Issue:** `update` does not call `member.save` (roles are mutated in-memory only). Additionally, `params.expect(:member)` incorrectly expects a scalar instead of a nested parameters hash under Rails 8, causing a `ParameterMissing` exception.
* **Testing:** Asserts roles are updated in the database (marked pending for save/parameter bugs).

### 5. `PasswordsMailer` Template Path Mismatch (`PasswordsMailer` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` / `spec/mailers`
* **Issue:** The password mailer templates are located in `app/views/users/passwords_mailer/` instead of `app/views/passwords_mailer/`, raising `ActionView::MissingTemplate` at runtime.
* **Testing:** Asserts headers and body are correctly rendered, marked as pending.

### 6. `ApplicationHelper` Controller Concerns Inclusion (`ApplicationHelper` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #21
* **Issue:** `ApplicationHelper` directly includes controller concerns (`Authentication`, `OrgScope`, `ProjectScope`) which expect request context (`session`, `cookies`) not present in helpers/views.
* **Testing:** Asserts that helper methods resolve without raising errors, marked as pending.
