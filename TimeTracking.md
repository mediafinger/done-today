# Time Tracking — Implementation Plan

Plan for the features in [TODOs.markdown](TODOs.markdown): inline `#tag` and time syntax in
entry logs, working-time calculation, and time/topic summaries.

Context assumptions: **local single-user app**, no HTTPS/auth hardening needed yet. Where the
plan touches an authorization gap it is noted as *future* rather than done now.

---

## 1. Where the app stands today

| Layer       | State                                                                                                                                                                                                                                                      |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Domain      | `Org > Project > Day > Entry`, plus `Member`/`Participant` for access. `Entry` holds one free-text `log` + a PG-enum `status` (`todo/doing/done`).                                                                                                         |
| Controllers | [entries_controller.rb](app/controllers/orgs/entries_controller.rb) does everything: `mode` (read/edit), `group_by` (date/member/project), filtering, day auto-build. [days_controller.rb](app/controllers/orgs/days_controller.rb) is 100% commented out. |
| Views       | Pico CSS, classless-ish. `_entry` (read) and `_editable_entry` (edit) are separate partials with a hand-rolled `left-aligned-grid-N` layout.                                                                                                               |
| JS          | Importmap + Stimulus, but **zero real controllers** — only the generated `hello_controller.js`.                                                                                                                                                            |
| Tests       | **None.** `spec/` contains only `rails_helper`, `spec_helper` and a stray `spec/spec/system/support/` (double-nested path — RSpec never loads it). `rake ci` runs rspec against an empty suite.                                                            |

### The key structural insight

Everything in the TODO list is **derived from the text the user types**. So the whole feature set
reduces to one question: *where does `entry.log` get turned into structured data?*

Recommendation: **`log` stays the single source of truth**, and a pure-Ruby value object parses it
into columns on save. That keeps the "type one line, hit enter" UX (the reason this app exists)
while making tags and durations queryable in SQL for the summary pages.

---

## 2. Refactorings to do first

These are cheap, and each one removes friction from a later phase. Bugs found while reading are
marked 🐞.

### 2.1 Get a test harness in place — *do this one first*

The parser is regex-heavy with a long tail of edge cases ("handle edge cases by displaying issues"
is literally in the TODOs). Writing it without tests will hurt.

- Move `spec/spec/system/support/org_scope_helper.rb` → `spec/system/support/org_scope_helper.rb`
  🐞 (current path is never loaded).
- Add `spec/factories/` for `user, org, member, project, participant, day, entry` — `factory_bot_rails`
  and the `factory_bot:awesome_lint` rake task are already wired up, they just have nothing to lint.
- Add `spec/models/` and `spec/services/` directories so `rake ci` becomes meaningful.

### 2.2 Delete dead code

- `app/controllers/orgs/days_controller.rb` — fully commented out, route already commented out.
  Delete the controller and `app/views/orgs/days/{show,index_of_one_member}.html.erb`.
  **Keep `app/views/orgs/days/_select.html.erb`** — it is still rendered by
  [_nav.html.erb](app/views/layouts/_nav.html.erb); move it to `app/views/shared_partials/_date_nav.html.erb`.
- `app/views/orgs/projects/_select.html.erb` — literally says "unused selector".
- `app/javascript/controllers/hello_controller.js`.
- [ERD.md](ERD.md) — top half is a stray JS snippet; it duplicates [README.markdown](README.markdown).
  Either fold the useful bits into the README or drop it.

### 2.3 Fix the bugs found while reading

- 🐞 **Missing partial**: [index.html.erb](app/views/orgs/entries/index.html.erb) renders
  `orgs/entries/entries_nav_by_project` when `group_by == "project"`, but that partial does not exist.
  Hitting `/entries?project_id=…` (without `date` or `member_id`) raises `MissingTemplate`.
  Either create it or drop the branch.
- 🐞 **Date parsing is inconsistent**: `EntriesController#date` does
  `Date.parse(params[:date]) rescue Time.current.to_date`, but the action then uses the *raw*
  `params[:date]` for `days.find_by(date: …)` and `days.build(date: …)`. An invalid date silently
  yields an empty day instead of today. Parse once into `@date`, use `@date` everywhere, and drop
  the modifier-`rescue` (`Date.parse(...) rescue nil` swallows more than `ArgumentError`).
- 🐞 **`Member#readable_projects`** contains `projects = projects.where(id: projects)` — a
  self-referential no-op, so a plain `member` sees *all* org projects rather than the ones they
  participate in. Should be `where(id: participations.select(:project_id))`.
- 🐞 **`RecordHistoryService.call` requires `org:` and `user:`**, but
  [application_record.rb](app/models/application_record.rb)'s `create_with_history` /
  `update_with_history` / `destroy_with_history` pass neither. Any call raises `ArgumentError`.
  Nothing calls them today. Either default them to `Current.org` / `Current.user` (consistent with
  the rest of the app) or delete the three helpers.
- 🐞 **`RecordHistory#get_history_for_*` are instance methods** calling `where` — unusable as
  written. Make them `scope`s or class methods.
- 🐞 **`EntriesController#update` ignores a blank log**: `entry.log = update_params[:log] if
  update_params[:log].present?`. You cannot shorten a log to blank, and — more importantly — this
  is what makes the existing "prevent losing edited log when clicking a button instead of enter"
  TODO bite (see 2.4).
- **No length validation on `log`** although the form sets `maxlength: 500`. Add
  `validates :log, length: { in: 3..500 }` so client and server agree — time markup makes long
  lines more likely.
- **`Day` has no model-level uniqueness** on `[project_id, date]` despite the unique DB index, so
  `find_or_create_by!` can surface `RecordNotUnique` instead of a validation error.

### 2.4 Make the status buttons part of the form

This is the highest-value refactor, because it deletes a TODO outright. Today
[_editable_entry.html.erb](app/views/orgs/entries/_editable_entry.html.erb) renders the status
buttons as `link_to … entry_path(entry, entry: { status: "todo" }), turbo_method: :patch` — a PATCH
link carrying state in the query string, *outside* the form. Clicking it discards whatever the user
typed in the text field.

Replace with real submit buttons inside the same form:

```erb
<% Entry::STATES.each do |state| %>
  <%= form.button state, name: "entry[status]", value: state,
        class: "btn-tdd #{entry.status == state ? "btn-#{state}" : 'btn-inactive'}" %>
<% end %>
```

Now one submit carries both `log` and `status`, the `present?` guard from 2.3 can go, and the
"losing edited log" TODO is fixed at the root rather than patched in JS.

### 2.5 Strict locals + eager loading in the entry partials

- `_entry.html.erb` guards every local with `defined?(with_date) && with_date` while
  `index.html.erb` always passes them. Replace the comment header with Rails 8 strict locals:
  `<%# locals: (entry:, entries:, index:, with_date: false, with_member: false, with_project: false) %>`.
  The "Expects the following local variables" comment then becomes enforced.
- 🐞 **N+1**: `EntriesController#index` read mode does `current_org.entries.where(day: …)` with no
  `includes`, while `_entry` calls `entry.member`, `entry.project` and `entry.day`. Add
  `.includes(:member, day: :project)`. Summaries will multiply this.

### 2.6 Replace the hand-rolled grid before adding columns

`_entry.html.erb` computes `grid_columns` inline and `general.css` defines
`.left-aligned-grid-2` … `-5`. Time tracking adds a **duration column and a tags column** — that is
a 6th and 7th variant of a hard-coded grid. Switch the entry list to a single
`grid-template-columns` with `auto`/`1fr` sizing (or a plain `<table>`) now, while there are only
two partials to change.

### 2.7 Decide the timezone story

`Entry#today?/past?/future?` all carry a `# TODO: timezone correction`. Time tracking makes this
real. Recommendation, matching the [AppConf](config/app_conf.rb) pattern already in place:

- Register `AppConf.timezone` (default `"Europe/Berlin"`), set `config.time_zone` from it.
- `Day#date` remains a plain local date. Clock times are stored as **minutes since midnight**
  (integers), not timestamps — so the timezone only ever affects *"what is today"*, never stored
  data. No DST or UTC-offset bugs possible.

### 2.8 Note for later (not now — local-only app)

- `EntriesController#create` never checks that `current_member` participates in `current_project`.
- `EntriesController#update` scopes to `current_project.entries` but never consults
  `Participant#editable_entries` — any participant can edit any entry in the project.

Both are harmless locally; record them for whenever this goes multi-user.

---

## 3. Data model changes

One migration covers the whole feature set.

```ruby
class AddTimeTrackingToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :tags,              :text, array: true, default: [], null: false
    add_column :entries, :day_start_minutes, :integer   # from  start@09:00
    add_column :entries, :day_end_minutes,   :integer   # from  end@18:00
    add_column :entries, :from_minutes,      :integer   # from  from@11:00
    add_column :entries, :to_minutes,        :integer   # from  to@12:00
    add_column :entries, :duration_minutes,  :integer   # from  for~1h30m, or to - from

    add_index :entries, :tags, using: :gin
    add_index :entries, [ :day_id, :from_minutes ]
  end
end
```

Design notes:

- **Minutes since midnight, as integers.** `0..1440`, where `1440` = `24:00`. Sorting, arithmetic,
  `SUM()` and overlap detection are all trivial; no timezone surface at all.
- **`day_start/end` live on the entry, not the day.** You type `start@09:00` as an entry, so the
  text that produced the value stays next to the value. A day's span is
  `MIN(day_start_minutes)` / `MAX(day_end_minutes)` across its entries — cheap, and it means there
  is never a `days` row that disagrees with its entries.
- **`tags` as `text[]` with a GIN index**, not a join table. This matches the idiom already used for
  `members.roles` / `participants.roles`, and makes tag filters one operator:
  `Entry.where("tags && ARRAY[?]::text[]", %w[foo])`.
- **No denormalized totals on `days`** for now. `TimeSummary` (§7) aggregates in one query. Add
  cached columns on `days` only if the month/project overviews actually get slow.

### Tag metadata: `tag_rules`

Two TODO items need per-tag metadata: `#Break #OOO #Vacation` mean *not working*, and `#PR123`
should link out. That cannot live in the `text[]`.

```ruby
create_enum :tag_kind, %w[work break absence]

create_table :tag_rules, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
  t.uuid   :org_id,     null: false
  t.uuid   :project_id                      # nullable → org-wide rule
  t.string :matcher,    null: false         # "break"  or  "pr" (prefix)
  t.string :matcher_kind, null: false, default: "exact"   # exact | prefix
  t.enum   :kind, enum_type: "tag_kind", default: "work", null: false
  t.string :url_template                    # "https://github.com/me/repo/pull/%{rest}"
  t.timestamps
  t.index [ :org_id, :project_id, :matcher ], unique: true
end
```

`matcher_kind: "prefix"` is what makes `#PR123`, `#PR456`, `#PR789` work from a *single* rule:
match `pr`, feed the remainder `123` into `url_template`. A per-PR row would be unusable.

Defaults (`break`, `ooo`, `vacation`, `holiday`, `sick` → `kind: absence/break`) ship as a code-level
constant in `TagRule::DEFAULTS` and are seeded per org, so the feature works before the user
configures anything.

We need a settings UI for the Tag-Matchers (we will also need it to create or manage projects and other things... but this is a start).

---

## 4. Phase 1 — Editing UX

Covers the first TODO block. Depends on refactor 2.4.

**Goal:** ESC discards, blur persists, past entries are protected.

1. **`app/javascript/controllers/entry_form_controller.js`** (the app's first real Stimulus
   controller):

   ```js
   import { Controller } from "@hotwired/stimulus"

   export default class extends Controller {
     static targets = ["log"]

     connect()  { this.original = this.logTarget.value; this.submitting = false }
     revert()   { this.logTarget.value = this.original; this.logTarget.blur() }
     saveIfChanged() {
       if (this.submitting || this.logTarget.value === this.original) return
       this.submitting = true
       this.element.requestSubmit()
     }
   }
   ```

   Wired as `data: { controller: "entry-form", action: "keydown.esc->entry-form#revert" }` on the
   form, and `action: "blur->entry-form#saveIfChanged"` on the field.

   ⚠️ **The double-submit trap:** clicking a status button first blurs the field. Without the
   `submitting` guard you fire two PATCHes. Guard it, and reset the flag on
   `turbo:submit-end`.

   ESC over CTRL+Z: CTRL+Z is the browser's own undo inside a text field — overriding it is hostile. - BUT: currently CTRL+Z does nothing when the field is dirty, wouldn't is just make sense to remove all changes from this field?
   ESC is unambiguous.

2. **Turbo Streams for `create`/`update`.** With blur-to-save, a full-page redirect on every field
   exit is jarring — the page jumps and focus is lost. Respond with
   `turbo_stream.replace(dom_id(entry), …)` plus a replace of the summary region (§7).
   *This is effectively a prerequisite of blur-saving, not a nice-to-have.*

3. **Protect past entries — recommendation: yes, soft-lock.** Once entries carry hours you will be
   reporting from them, and an accidental keystroke on last Tuesday is a silent data error. Render
   days before today read-only by default with an explicit **"unlock"** toggle
   (`?unlocked=1` → renders `_editable_entry` instead of `_entry`). Today and future days stay
   freely editable. `Entry#past?` already exists for the check (after 2.7). The unlock toggle should toggle all entires of the page, not only one. It should be reset when leaving the page (and maybe after 60 seconds of inactivity?).

4. Also remove the inline `<script>` in
   [_new_entry.html.erb](app/views/orgs/entries/_new_entry.html.erb) that sets
   `document.location.hash` — it breaks under a CSP nonce and fights Turbo. Use Turbo's
   `autofocus` handling or a two-line Stimulus controller.

**Tests:** system specs for ESC-reverts, blur-persists, status-button-preserves-typed-text,
past-day-is-read-only. (`rake ui` runs system specs separately — they are excluded from `rake ci`.)

---

## 5. Phase 2 — The parser

**Goal:** one tested, pure-Ruby object that turns a log string into structured data. No UI.

### `app/values/entry_log.rb`

A value object (PORO, not AR). `EntryLog.new(text)` exposes:

| Method                                    | Returns                                                          |
|-------------------------------------------|------------------------------------------------------------------|
| `#segments`                               | `[[:text, "fixed the "], [:tag, "PR123"], [:time, :for, 90], …]` |
| `#tags`                                   | `["pr123", "review"]` — downcased, deduped                       |
| `#day_start_minutes` / `#day_end_minutes` | `Integer` or `nil`                                               |
| `#from_minutes` / `#to_minutes`           | `Integer` or `nil`                                               |
| `#duration_minutes`                       | explicit `for~`, else `to - from`, else `nil`                    |
| `#issues`                                 | `[Issue(code:, severity:, message:)]`                            |
| `#marker_only?`                           | true when the log is time markup with no prose                   |

**`#segments` is the single source of truth.** Both extraction *and* HTML rendering (§6) consume it,
so display can never drift from what was stored. Tokenize once with `StringScanner`.

### Grammar

```ruby
BOUNDARY  = /(?<![^\s])/          # start-of-string or after whitespace

TAG       = /#{BOUNDARY}\#(?<name>\p{Alnum}[\p{Alnum}_\/-]*)/
DAY_START = /#{BOUNDARY}start@(?<h>\d{1,2}):(?<m>\d{2})\b/i
DAY_END   = /#{BOUNDARY}end@(?<h>\d{1,2}):(?<m>\d{2})\b/i
FROM      = /#{BOUNDARY}from@(?<h>\d{1,2}):(?<m>\d{2})\b/i
TO        = /#{BOUNDARY}to@(?<h>\d{1,2}):(?<m>\d{2})\b/i
FOR       = /#{BOUNDARY}for~(?=\d)(?:(?<h>\d+)h)?(?:(?<m>\d+)m)?\b/i
```

> **Corrected during implementation.** Two of the rules first written here were wrong; both were
> caught by building the thing. The grammar above is the version that shipped.

- **The token boundary cannot live in the regex.** `StringScanner` matches from its pointer and
  cannot see behind it, so after consuming `x` in `x#b`, `sc.scan(/(?<![^\s])\#\w+/)` **matches** --
  the negative lookbehind trivially succeeds (and a positive `(?<=\s)` trivially fails). The rule is
  enforced in `#tokenize` instead, by tracking whether the last consumed text ended in whitespace.
  Note `sc.pos` is a *byte* index, so indexing back into the string would break on `"Übung #Sport"`.
- **`for~` needs a trailing `(?![\p{Alnum}])` as well as the leading `(?=\d)`.** With only the
  lookahead, `for~90` matches as a *zero-length* duration: both groups match empty and `\b` succeeds
  between `~` and `9`. The trailing lookahead is what sends `for~90`, `for~1hh` and bare `for~` to
  `invalid_duration`.
- `\b` after `\d{2}` is what rejects `10:005`.
- `freezolite` freezes string literals -- the parser must build new strings, never `gsub!` a literal.

### Segments carry their source text

The shape shown above as `[:time, :for, 90]` cannot round-trip: `for~90m` and `for~1h30m` both mean
90. **The last element of every segment is the verbatim source**, so
`segments.map(&:last).join == input` holds for any input, including markup that failed to parse:

```ruby
[:text, "Fixed "], [:tag, "pr123", "#PR123"], [:time, :from, 660, "from@11:00"]
```

Phase 3's renderer destructures a four-element time tuple.

### Edge cases → `issues`, never validation errors

**The log text is always saved verbatim, whatever the markup says.** A typo in `for~1hh` must not
block `entry.save`, or fast typing becomes miserable. Parse failures produce advisory issues that
the UI shows; that is exactly what "handle edge cases by displaying issues" asks for.

| Input                              | Behaviour                                                        |
|------------------------------------|------------------------------------------------------------------|
| `for~90m` / `for~1h` / `for~1h30m` | 90 / 60 / 90                                                     |
| `for~0m`                           | issue `zero_duration`, `duration_minutes` stays nil              |
| minutes > 59, hours > 24           | issue `invalid_time`, token rendered as plain text               |
| `from@` with no `to@`/`for~`       | `open_range` (info on today, warning on a past day)              |
| `to@` **and** `for~` disagree      | issue `conflicting_duration`; `to − from` wins                   |
| `to@` earlier than `from@`         | issue `negative_range`                                           |
| `#Tag` vs `#tag`                   | stored downcased, original casing preserved in `log` for display |
| `#PR123,` trailing punctuation     | `,` is not in the tag charset → excluded, stays as text          |

**Past midnight:** do not accept hours past 24:00 - users have to create a new entry on the next day if an ativity is going on over night.

### Wiring into `Entry`

```ruby
before_validation :parse_log, if: :log_changed?

def parsed = @parsed ||= EntryLog.new(log.to_s)

def parse_log
  self.tags              = parsed.tags
  self.day_start_minutes = parsed.day_start_minutes
  # … etc
end
```

Plus a `rake time_tracking:backfill` task re-saving existing entries (seed data has none of this
markup, so it is mostly a no-op — but write it anyway, you will re-run it when the grammar grows).

**Tests:** `spec/values/entry_log_spec.rb` is the one spec file that really matters. One example per
row of the table above, plus round-tripping `#segments` back to the original string.

---

## 6. Phase 3 — Tags in the UI

1. **Rendering.** `app/helpers/log_helper.rb#render_log(entry)` walks `entry.parsed.segments`:
   escape every `:text` segment, wrap `:tag` segments in a chip (`<a>` when a `tag_rule` supplies a
   `url_template`, `<span>` otherwise), wrap `:time` segments in a badge, then join and mark the
   *assembled* string html-safe.
   ⚠️ Escape per segment and concatenate — never `html_safe` the raw log.
2. **Search.** Add a `tag` filter to `EntriesController#index`:
   `@entries = @entries.where("entries.tags && ARRAY[?]::text[]", Array(params[:tag]))`.
   Tag chips link to `entries_path(tag: name)`. This finally gives `#index` the "central filter
   point" role its own TODO comment asks for.
3. **Topic overview.** `Orgs::TagsController#index` — every tag in the project with entry count,
   total time, and open (`todo`/`doing`) count. `GROUP BY unnest(tags)`.
4. **`tag_rules`.** Model + `Orgs::TagRulesController` (index/create/update/destroy) reachable from
   [settings](app/views/orgs/settings/show.html.erb). Seed `TagRule::DEFAULTS` on org create.
5. **`#PR123` links.** `TagRule#url_for(tag)` → `format(url_template, rest: "123")`.

**Tests:** model specs for `TagRule` matching (exact vs prefix, project rule shadows org rule),
helper spec asserting `render_log("<script> #tag")` escapes the script tag.

---

## 7. Phase 4 — Times and working-time calculation

### `app/values/time_summary.rb`

`TimeSummary.new(entries)` — takes *any* entry collection, so **the same object serves the day page,
the week page, the month page and the project page.** That is the whole reason to build it as a
PORO over a relation rather than a method on `Day`.

| Method               | Meaning                                          |
|----------------------|--------------------------------------------------|
| `#span_minutes`      | `max(day_end) − min(day_start)` — gross presence |
| `#break_minutes`     | duration of entries tagged `kind: break`         |
| `#absence_minutes`   | duration of entries tagged `kind: absence`       |
| `#work_minutes`      | `span − break − absence`                         |
| `#tracked_minutes`   | `SUM(duration_minutes)` over work entries        |
| `#untracked_minutes` | `work_minutes − tracked_minutes`                 |
| `#by_tag`            | `{ "review" => 145, … }`                         |
| `#issues`            | day-level checks, below                          |

Aggregation stays in Postgres:

```sql
SUM(duration_minutes) FILTER (WHERE NOT tags && ARRAY['break','ooo']::text[])
```

### Day-level issue detection

Per-entry issues come from the parser; these need the whole day in view:

- `end@` present but no `start@` → *"no start time recorded"*
- more than one `start@` → *"several start times found"*
- `end@` before `start@` → *"day ends before it starts"*
- an entry's `from/to` falls outside `[day_start, day_end]` → *"entry outside working hours"*
- two entries' `[from, to)` intervals overlap → *"overlapping time ranges"*
- `tracked_minutes > work_minutes` → *"more time logged than worked"*
- a past day with entries but no times → *"no time tracked"* (info, not a warning)

Overlap detection: sort by `from_minutes`, compare each `to` with the next `from`. O(n log n), and n
is a handful per day.

### Display

- `_entry` gains a duration column: `for~1h30m` renders as a right-aligned `1h30m` badge.
- An entry whose log is *only* time markup (`marker_only?`) renders as a thin rule —
  `── 09:00 day started ──` — not as a normal entry with todo/doing/done buttons. Typing
  `start@09:00` as a "log" is the intended UX, but it is not a task.
- `app/helpers/duration_helper.rb#format_minutes`: `90 → "1h30m"`, `60 → "1h"`, `45 → "45m"`,
  `0 → "0m"`, `nil → "–"`.

**Tests:** `spec/values/time_summary_spec.rb` — one example per issue code, plus a realistic full
day (start, four entries, a break, end) asserting every total.

---

## 8. Phase 5 — Summaries on the day page

Append a summary block below the entry list on `entries#index`:

```
09:00 – 18:00   ·   8h30m worked   ·   30m break   ·   7h45m tracked   ·   45m untracked

  #review   2h15m      #meetings  1h30m      #pr123  1h00m      #refactor  3h00m

  ⚠ entries #3 and #4 overlap between 14:00 and 14:30
```

- Partial `orgs/summaries/_time_summary.html.erb`, taking a `TimeSummary`.
- Give it a stable `dom_id` so the Turbo Stream responses from Phase 1 can replace it on every
  entry save — the totals update live as you type.
- Issues render as a distinct list below the totals, warnings and infos styled apart.

---

## 9. Phase 6 — Week / month / project overviews

`Orgs::SummariesController#show`, params `period` (`week|month|custom`), `date`, `project_id`,
`member_id`, `tag`. Reuses `TimeSummary` unchanged — the only new code is the date-range → entry
scope, and the layout.

- **Week:** one row per day (span, worked, tracked, top 3 tags) + a week footer.
- **Month:** one row per week + a tag breakdown for the month.
- **Project:** the project page already shows days; add a `TimeSummary` header for the project's
  whole lifetime and a per-month table.
- Add `prev`/`next` navigation mirroring
  [_entries_nav_by_date](app/views/orgs/entries/_entries_nav_by_date.html.erb).

Watch for N+1 here — load entries once per page with
`.includes(:member, day: :project)` and let `TimeSummary` work in memory, or push the aggregation
fully into SQL for the month view. Revisit the denormalized `days` counters (§3) only if this is
measurably slow.

---

## 10. Decisions I need from you

### Answered

1. **`tag_rules` table + settings UI it is.
2. **Protect past entries?** yes
3. **Past midnight:** never, user has to create entries on two days
4. **Which status do timed entries get?** no automatic status change, track the time as TODO (and optionally for the topic)
5. **Phase order.** UX first
---

## 11. Suggested order of work

| # | Phase           | Ships                                                        |
|---|-----------------|--------------------------------------------------------------|
| 0 | §2 Refactorings | Test harness, dead code gone, 8 bugs fixed                   |
| 1 | §4 Editing UX   | ESC / blur-save / locked past days / Turbo Streams           |
| 2 | §5 Parser       | `EntryLog` + migration + backfill (no visible change)        |
| 3 | §6 Tags         | `#tag` search, topic overview, `#PR123` links, absence kinds |
| 4 | §7 Times        | `start@`/`end@`/`from@`/`to@`/`for~`, issue detection        |
| 5 | §8 Day summary  | Totals under each day                                        |
| 6 | §9 Overviews    | Week / month / project pages                                 |

Phases 0–1 and 2 are independent and could run in parallel; everything from 3 onward is a chain.

Run `rake ci` after each phase (needs `chruby ruby-4.0.7` first), and `bin/rubocop -a` before
committing — `rake ci` includes rubocop and will fail the build on style.
