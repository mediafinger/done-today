require "rails_helper"

RSpec.describe "Orgs::Entries" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in_and_open(participant) }

  describe "GET /entries" do
    it "defaults to today when no date is given" do
      get entries_path(mode: "edit")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Time.zone.today.iso8601)
    end

    it "falls back to today when the date cannot be parsed" do
      get entries_path(date: "not-a-date", mode: "edit")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Time.zone.today.iso8601)
    end

    it "shows the requested day, not today" do
      get entries_path(date: "2026-03-01", mode: "edit")

      # the date nav always links to today, so assert on the heading
      expect(response.body).to include("Day 2026-03-01 (Sunday)")
      expect(response.body).not_to include("Day #{Time.zone.today.iso8601}")
    end

    it "sends the old project grouping to the project page" do
      get entries_path(project_id: project.id, mode: "read")

      expect(response).to redirect_to(project_path(project.slug))
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "the editable entry form" do
    let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "renders the status controls as submit buttons inside the form" do
      get entries_path(mode: "edit")

      expect(response.body).to include(%(<button name="entry[status]" type="submit" value="done"))
    end

    # ENTER submits a form through its first submit button. When that was the "todo"
    #   status button, every ENTER in the log field reset the status to todo.
    it "makes a button without a status the one ENTER submits through" do
      get entries_path(mode: "edit")

      form = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(entry)} form")
      default_button = form.at_css("button[type=submit]")

      expect(default_button["name"]).to be_nil
      expect(form.css("button[name='entry[status]']").size).to eq(Entry::STATES.size)
    end

    it "no longer links the status to a PATCH url that drops the typed log" do
      get entries_path(mode: "edit")

      expect(response.body).not_to include("entry%5Bstatus%5D")
    end

    it "wires the entry-form controller up to the field and to the status buttons" do
      get entries_path(mode: "edit")

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).to include("keydown.esc-&gt;entry-form#revert")
      expect(response.body).to include("blur-&gt;entry-form#saveIfChanged")
      expect(response.body).to include("mousedown-&gt;entry-form#noteStatusPress")
    end

    it "gives every entry a stable dom id so a Turbo Stream can address it" do
      get entries_path(mode: "edit")

      expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(entry)}"))
    end

    it "gives each log field its own id instead of repeating entry_log" do
      create(:entry, day: entry.day, member:, log: "A second entry")

      get entries_path(mode: "edit")

      expect(response.body.scan(%(id="entry_log")).count).to eq(0)
    end

    it "focuses the new entry field without an inline script" do
      get entries_path(mode: "edit")

      expect(response.body).not_to include("document.location.hash")
      expect(response.body).to include(%(data-controller="autofocus"))
    end
  end

  describe "past days" do
    let!(:old_entry) { create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:) }

    it "renders a past day read-only and offers to unlock it" do
      get entries_path(date: Time.zone.yesterday.iso8601, mode: "edit")

      expect(response.body).not_to include(%(data-controller="entry-form"))
      expect(response.body).to include(old_entry.log)
      expect(response.body).to include("unlock to edit")
    end

    it "does not offer a new entry field while the day is locked" do
      get entries_path(date: Time.zone.yesterday.iso8601, mode: "edit")

      expect(response.body).not_to include(%(id="new-entry"))
    end

    it "edits the day once it has been unlocked" do
      get entries_path(date: Time.zone.yesterday.iso8601, mode: "edit", unlocked: "1")

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).to include(%(id="new-entry"))
      expect(response.body).to include("lock again")
    end

    it "keeps today editable without unlocking" do
      create(:entry, day: create(:day, project:, date: Time.zone.today), member:)

      get entries_path(mode: "edit")

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).not_to include("unlock to edit")
    end

    it "keeps a future day editable without unlocking" do
      get entries_path(date: Time.zone.tomorrow.iso8601, mode: "edit")

      expect(response.body).to include(%(id="new-entry"))
      expect(response.body).not_to include("unlock to edit")
    end
  end

  describe "the lock on past days" do
    let!(:old_entry) { create(:entry, day: create(:day, project:, date: yesterday), member:) }

    def yesterday = Time.zone.yesterday

    it "refuses to update an entry of a locked past day" do
      patch entry_path(old_entry), params: { entry: { log: "Changed in passing" } }

      expect(old_entry.reload.log).to eq("Wrote some code")
      expect(response).to redirect_to(entries_path(date: yesterday, mode: "edit"))
      expect(flash[:alert]).to eq("#{yesterday.iso8601} is locked, unlock the day to change it")
    end

    it "reports the lock in place for a Turbo Stream update" do
      patch entry_path(old_entry), params: { entry: { status: "done" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is locked, unlock the day to change it")
      expect(old_entry.reload.status).to eq("doing")
    end

    it "updates the entry once the day is unlocked" do
      patch entry_path(old_entry), params: { entry: { log: "Fixed it after all" }, unlocked: "1" }

      expect(old_entry.reload.log).to eq("Fixed it after all")
      expect(response).to redirect_to(entries_path(date: yesterday, mode: "edit", unlocked: true))
    end

    it "refuses a new entry on a locked past day, without creating the day" do
      expect { post entries_path, params: { entry: { date: (yesterday - 1).iso8601, log: "Logged late" } } }
        .not_to change { [ Entry.count, Day.count ] }

      expect(flash[:alert]).to include("is locked")
    end

    it "creates the entry once the day is unlocked" do
      expect { post entries_path, params: { entry: { date: yesterday.iso8601, log: "Logged late" }, unlocked: "1" } }
        .to change(Entry, :count).by(1)
    end

    it "keeps today and future days open without unlocking" do
      post entries_path, params: { entry: { date: Time.zone.tomorrow.iso8601, log: "Planned ahead" } }

      expect(Entry.exists?(log: "Planned ahead")).to be(true)
    end
  end

  describe "validating a day in edit mode" do
    let(:day) { create(:day, project:, date: Time.zone.yesterday) }

    def edit_day(**params)
      get entries_path(date: day.date.iso8601, mode: "edit", unlocked: "1", **params)
      Nokogiri::HTML(response.body)
    end

    def validate_day
      edit_day(validate: "1")
    end

    it "offers the check once the day has entries" do
      create(:entry, day:, member:, log: "start@09:00 kickoff")

      link = edit_day.at_css(".spacing-grid a[href*='validate']")

      expect(link.text).to eq("validate")
      expect(link["href"]).to eq(entries_path(date: day.date, mode: "edit", unlocked: true, validate: "1"))
    end

    it "does not offer it for a day without entries" do
      expect(edit_day.at_css("a[href*='validate']")).to be_nil
    end

    it "explains the issues without being asked" do
      create(:entry, day:, member:, log: "start@09:00 kickoff")

      page = edit_day

      expect(page.at_css("#time-issues").text).to include("has no end@")
      expect(page.at_css("#validation-ok")).to be_nil
    end

    it "keeps quiet about a day that adds up until the button is pressed" do
      create(:entry, day:, member:, log: "start@09:00 end@17:00 a sound day")

      page = edit_day

      expect(page.at_css("#time-issues")).to be_nil
      expect(page.at_css("#validation-ok")).to be_nil
    end

    it "explains the issues in a box above the entries" do
      create(:entry, day:, member:, log: "start@09:00 kickoff")
      create(:entry, day:, member:, log: "end@25:00 for~40h wrapped up", status: "todo")

      box = validate_day.at_css("#time-issues")

      expect(box.css("li").map { it.text.squish }).to eq([
        "#{member.name} for~40h exceeds 24h",
        "#{member.name} end@25:00 for~40h is still marked as todo"
      ])
      expect(response.body.index("time-issues")).to be < response.body.index(%(id="editable-entries"))
    end

    it "reports the all-clear with the day's total" do
      create(:entry, day:, member:, log: "start@09:00 kickoff")
      create(:entry, day:, member:, log: "#break for~30m")
      create(:entry, day:, member:, log: "end@17:00 wrapped up")

      page = validate_day

      expect(page.at_css("#validation-ok").text.squish).to eq("Everything ok — 7h30m total")
      expect(page.at_css("#time-issues")).to be_nil
    end

    it "checks only this member's own entries" do
      colleague = create(:participant, project:).member
      create(:entry, day:, member:, log: "start@09:00 end@17:00 a sound day")
      create(:entry, day:, member: colleague, log: "start@09:00 an open day of theirs")

      page = validate_day

      expect(page.at_css("#validation-ok")).to be_present
      expect(page.at_css("#time-issues")).to be_nil
    end
  end

  describe "the time and tag information of a day" do
    let(:day) { create(:day, project:, date: Date.new(2026, 9, 21)) }

    def log(text, status: "done")
      create(:entry, day:, member:, log: text, status:)
    end

    def read_day
      get entries_path(date: day.date.iso8601, mode: "read")
      Nokogiri::HTML(response.body)
    end

    it "shows start, end, breaks and the total above the entries" do
      log("start@09:00")
      log("#break for~30m")
      log("end@17:30")

      page = read_day
      info = page.at_css(".time-summary .time-info").text.squish

      expect(info).to eq("#{member.name} 09:00 – 17:30 · 30m break · 8h total")
      expect(response.body.index("time-summary")).to be < response.body.index(%(id="entries"))
    end

    it "shows an open end while the day is still running" do
      log("start@09:00")

      expect(read_day.at_css(".time-info").text.squish).to eq("#{member.name} 09:00 – …")
    end

    it "lists every tag of the day in one line" do
      log("start@09:00 #Handover")
      log("paired on #PR123 and #handover")

      expect(read_day.css(".tag-info .tag").map(&:text)).to eq(%w[#handover #pr123])
    end

    it "colours the time red while a time entry is todo" do
      log("start@09:00", status: "doing")
      log("end@17:00", status: "todo")

      expect(read_day.at_css(".time-info")["class"]).to include("time-todo")
    end

    it "colours the time yellow while a time entry is doing" do
      log("start@09:00", status: "doing")
      log("end@17:00")

      expect(read_day.at_css(".time-info")["class"]).to include("time-doing")
    end

    it "keeps the time uncoloured once every time entry is done" do
      log("start@09:00")
      log("unrelated", status: "todo")

      expect(read_day.at_css(".time-info")["class"]).not_to match(/time-(todo|doing)/)
    end

    it "keeps the members' times apart" do
      colleague = create(:participant, project:).member
      log("start@09:00")
      create(:entry, day:, member: colleague, log: "start@11:00")

      expect(read_day.css(".time-info").map { it.text.squish }).to contain_exactly(
        "#{member.name} 09:00 – …", "#{colleague.name} 11:00 – …"
      )
    end

    it "leaves out the block on a day without markup" do
      log("wrote some code")

      expect(read_day.at_css(".time-summary")).to be_nil
    end

    it "does not add up start and end times across days" do
      log("start@09:00")

      get entries_path(mode: "read")

      expect(response.body).not_to include("time-summary")
    end

    it "links the tags of the tag line to their overview page" do
      log("handed over #Handover")

      link = read_day.at_css(".tag-info a.tag")

      expect(link.text).to eq("#handover")
      expect(link["href"]).to eq(tag_path("handover"))
    end

    it "links the tags inside a log, keeping how they were written" do
      log("reviewed #PR123 today")

      link = read_day.at_css("#entries a.tag")

      expect(link.text).to eq("#PR123")
      expect(link["href"]).to eq(tag_path("pr123"))
    end

    it "still escapes the rest of the log" do
      log("<b>bold</b> #tagged")

      read_day

      expect(response.body).to include("&lt;b&gt;bold&lt;/b&gt;")
      expect(response.body).not_to include("<b>bold</b>")
    end
  end

  describe "GET /entries?week=" do
    it "sends the old week URL to the week page" do
      get entries_path(week: "2026-W38", project_id: project.id)

      expect(response).to redirect_to(week_path("2026-W38", project_id: project.id))
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "GET /entries?tag=" do
    it "sends the old tag URL to the tag page, keeping the project" do
      other = create(:participant, project: create(:project, org:), member:).project

      get entries_path(tag: "handover", mode: "read", project_id: other.id)

      expect(response).to redirect_to(tag_path("handover", project_id: other.id))
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "GET /entries?member_id=" do
    it "sends the old member URL to the member's page" do
      get entries_path(member_id: member.id, project_id: project.id)

      expect(response).to redirect_to(member_entries_path(member, project_id: project.id))
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "GET /entries?mode=read without a date" do
    it "lists the entries of every day, under today's headline" do
      create(:entry, day: create(:day, project:, date: Date.new(2026, 9, 1)), member:, log: "long ago")

      get entries_path(mode: "read")

      expect(response.body).to include("Day #{Time.zone.today.iso8601}", "long ago")
    end
  end

  describe "a day of another project than the current one" do
    let(:other) { create(:participant, project: create(:project, org:), member:).project }

    before { create(:entry, day: create(:day, project: other, date: Time.zone.today), member:, log: "elsewhere") }

    it "shows that project's day and offers to switch to it" do
      get entries_path(date: Time.zone.today.iso8601, project_id: other.id)

      expect(response.body).to include("elsewhere", "Switch to project &#39;#{other.name}&#39; to add or edit")
    end
  end

  describe "the date nav" do
    it "stays in edit mode on the edit page" do
      get entries_path(mode: "edit")

      link = Nokogiri::HTML(response.body).css("nav a").find { it.text == "yesterday" }

      expect(link["href"]).to eq(entries_path(date: Time.zone.yesterday, mode: "edit"))
    end
  end

  describe "as an observer of the project" do
    let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    before { sign_in_and_open(create(:participant, :observer, project:)) }

    it "does not offer to add or edit" do
      get entries_path(mode: "read")

      expect(response.body).not_to include("add or edit")
    end

    it "shows the day read-only in edit mode, with everybody's entries and no way to unlock" do
      get entries_path(mode: "edit")

      expect(response.body).to include(entry.log)
      expect(response.body).not_to include(%(id="new-entry"))
      expect(response.body).not_to include(%(data-controller="entry-form"))
      expect(response.body).not_to include("unlock to edit")
    end

    it "refuses to create an entry" do
      expect { post entries_path, params: { entry: { date: Time.zone.today.iso8601, log: "Only watching" } } }
        .not_to change(Entry, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /entries" do
    it "creates an entry on the given day" do
      expect { post entries_path, params: { entry: { date: "2026-03-02", log: "Wrote a spec" }, unlocked: "1" } }
        .to change(Entry, :count).by(1)

      expect(Entry.last.log).to eq("Wrote a spec")
      expect(Entry.last.day.date.iso8601).to eq("2026-03-02")
    end

    it "reports a validation failure instead of raising" do
      expect { post entries_path, params: { entry: { date: "2026-03-02", log: "x" }, unlocked: "1" } }
        .not_to change(Entry, :count)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /entries/:id" do
    let(:entry) { create(:entry, day: create(:day, project:), member:) }

    it "updates the log" do
      patch entry_path(entry), params: { entry: { log: "Rewrote a spec" } }

      expect(entry.reload.log).to eq("Rewrote a spec")
    end

    it "keeps the status when only the log is submitted" do
      entry.update!(status: "done")

      patch entry_path(entry), params: { entry: { log: "Rewrote a spec" } }

      expect(entry.reload.status).to eq("done")
    end

    it "updates the status" do
      patch entry_path(entry), params: { entry: { status: "done" } }

      expect(entry.reload.status).to eq("done")
    end

    it "updates log and status together without dropping either" do
      patch entry_path(entry), params: { entry: { log: "Both at once", status: "done" } }

      expect(entry.reload.log).to eq("Both at once")
      expect(entry.status).to eq("done")
    end

    it "surfaces a blank log as an error rather than silently ignoring it" do
      patch entry_path(entry), params: { entry: { log: "" } }

      expect(entry.reload.log).to eq("Wrote some code")
      expect(flash[:alert]).to be_present
    end

    it "refuses to update a colleague's entry and leaves it alone" do
      colleagues_entry = create(:entry, day: entry.day, member: create(:participant, project:).member)

      patch entry_path(colleagues_entry), params: { entry: { log: "Not mine to change" } }

      expect(response).to have_http_status(:forbidden)
      expect(colleagues_entry.reload.log).to eq("Wrote some code")
    end

    it "refuses a Turbo Stream update of a colleague's entry with a bare 403" do
      colleagues_entry = create(:entry, day: entry.day, member: create(:participant, project:).member)

      patch entry_path(colleagues_entry), params: { entry: { status: "done" } }, as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
      expect(colleagues_entry.reload.status).to eq("doing")
    end

    it "stays on the unlocked past day instead of locking it again" do
      patch entry_path(entry), params: { entry: { log: "Fixed it after all" }, unlocked: "1" }

      expect(response).to redirect_to(entries_path(date: entry.day.date, mode: "edit", unlocked: true))
    end
  end

  describe "Turbo Stream responses" do
    let(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "replaces just the edited entry instead of redirecting the whole page" do
      patch entry_path(entry), params: { entry: { log: "Saved on blur" } }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(entry)}"))
      expect(response.body).to include("Saved on blur")
    end

    it "reports an invalid update in place, keeping what was typed" do
      patch entry_path(entry), params: { entry: { log: "x" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(value="x"))
      expect(entry.reload.log).to eq("Wrote some code")
    end

    it "inserts a created entry above the input field and blanks the field" do
      post entries_path, params: { entry: { date: Time.zone.today.iso8601, log: "Typed and blurred" } },
        as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="before" target="new-entry"))
      expect(response.body).to include(%(action="replace" target="new-entry"))
      expect(response.body).to include("Typed and blurred")
    end

    it "reports an invalid create without throwing the text away" do
      post entries_path, params: { entry: { date: Time.zone.today.iso8601, log: "x" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include(%(action="before" target="new-entry"))
      expect(response.body).to include(%(value="x"))
    end
  end
end
