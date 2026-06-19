# Test Suite Progress

We have successfully implemented a comprehensive RSpec test suite for the **Done Today** application. Below is the summary of files created, tests covered, and known issues marked as pending.

## 📊 Summary of Created Spec Files

### Factories
* [spec/factories.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/factories.rb) — Definitions for User, Org, Member, Project, Participant, Day, Entry, Session, Integration, ProjectIntegration, and RecordHistory.

### Models (Unit Specs)
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

### Services & Validators
* [spec/services/record_history_service_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/services/record_history_service_spec.rb) — Verify `.call` persists record history under successful invocations.
* [spec/validators/array_inclusion_validator_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/validators/array_inclusion_validator_spec.rb) — Verify array inclusion limits and custom validation messages.

### Controllers (Integration Specs)
* [spec/controllers/users/sessions_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/sessions_controller_spec.rb) — Sign-in, sign-out, session cookie generation, rate-limit settings check.
* [spec/controllers/users/passwords_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/passwords_controller_spec.rb) — Password reset request form, reset token validation, password updates.
* [spec/controllers/users/display_modes_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/users/display_modes_controller_spec.rb) — Switching display mode cookie settings and referrer redirection.
* [spec/controllers/orgs/entries_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/entries_controller_spec.rb) — Org-scoped entry retrieval under read and edit modes, new entry creation, updating logs/status.
* [spec/controllers/orgs/projects_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/orgs/projects_controller_spec.rb) — Listing projects, showing project timelines via slug, scoping check.
* [spec/controllers/switch_orgs_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/switch_orgs_controller_spec.rb) — Org and project switcher flow validation, authorization boundary checks.
* [spec/controllers/application_controller_spec.rb](file:///Users/andy/Dropbox/www/2025/done_today/spec/controllers/application_controller_spec.rb) — Default landing page checks and 404 response handler.

---

## 🔍 Pending Specs (Unresolved Code Bugs)

Consistent with instructions to test correct behavior while marking buggy features as `pending`, the following cases are marked as pending:

### 1. `RecordHistory` Query Methods (`RecordHistory` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #22
* **Issue:** `get_history_for_org_record`, `get_history_for_org_events`, and `get_history_for_user_events` call `where` internally but are defined as instance methods. They should be class methods.
* **Testing:** Written to expect class method behavior, marked as pending:
  ```ruby
  describe "query methods (BUG #22)" do
    # ...
    it "returns history for org and record" do
      pending "Fix bug #22 (defined as instance method instead of class method)"
      # ...
    end
  end
  ```

### 2. `RecordHistoryService.call` Keyword Arguments (`ApplicationRecord` spec)
* **Bug Reference:** `TECHNICAL_DEBT.md` Bug #5
* **Issue:** `ApplicationRecord#create_with_history` (and update/destroy wrappers) does not forward `org:` and `user:` arguments automatically, but `RecordHistoryService.call` defines them as mandatory keywords.
* **Testing:** Written to expect automated history tracking wrapper calls to work, marked as pending:
  ```ruby
  it "raises ArgumentError due to signature mismatch (BUG #5) if org/user omitted" do
    pending "Fix bug #5 (RecordHistoryService requires named parameters org: and user:, but create_with_history doesn't pass them by default)"
    # ...
  end
  ```
