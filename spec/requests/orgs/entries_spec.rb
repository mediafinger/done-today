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
      expect(response.body).to include("Day 2026-03-01")
      expect(response.body).not_to include("Day #{Time.zone.today.iso8601}")
    end

    it "renders the project grouping without blowing up on a missing partial" do
      get entries_path(project_id: project.id, mode: "read")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.name)
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
      expect(link["href"]).to eq(entries_path(tag: "handover", mode: "read"))
    end

    it "links the tags inside a log, keeping how they were written" do
      log("reviewed #PR123 today")

      link = read_day.at_css("#entries a.tag")

      expect(link.text).to eq("#PR123")
      expect(link["href"]).to eq(entries_path(tag: "pr123", mode: "read"))
    end

    it "still escapes the rest of the log" do
      log("<b>bold</b> #tagged")

      read_day

      expect(response.body).to include("&lt;b&gt;bold&lt;/b&gt;")
      expect(response.body).not_to include("<b>bold</b>")
    end
  end

  describe "GET /entries?tag=" do
    let(:colleague) { create(:participant, project:).member }

    def entry_on(date, log, by: member, status: "done")
      day = Day.find_or_create_by!(project:, date: Date.parse(date))
      create(:entry, day:, member: by, log:, status:)
    end

    def read_tag(tag, **params)
      get entries_path(tag:, mode: "read", **params)
      Nokogiri::HTML(response.body)
    end

    # the date and member heading of every listed line
    def lines(page)
      page.css("#entries li").map { |line| line.css(".entry-group-heading").map { it.text.squish } }
    end

    it "names the project and the tag in the headline" do
      expect(read_tag("handover").at_css(".spacing-grid h2").text.squish).to eq("#{project.name} #handover")
    end

    it "lists the tagged entries newest first, showing date and member only where they change" do
      entry_on("2026-09-01", "first #handover")
      entry_on("2026-09-03", "third #handover", by: colleague)
      entry_on("2026-09-03", "fourth #handover", by: colleague)
      entry_on("2026-09-02", "untagged")

      page = read_tag("handover")

      expect(page.css("#entries li").map { it.text.squish }).to all(include("handover"))
      expect(lines(page)).to eq([
        [ "2026-09-03", colleague.name ],
        [],
        [ "2026-09-01", member.name ]
      ])
      expect(page.at_css("#entries").text).to match(/fourth.*third.*first/m)
    end

    it "puts the headings of a group on a row of their own, above its entries" do
      entry_on("2026-09-01", "first #handover")
      entry_on("2026-09-01", "second #handover")

      page = read_tag("handover")
      heading_rows = page.css("#entries .entry-heading-row")

      expect(heading_rows.map { it.text.squish }).to eq([ "2026-09-01 #{member.name}" ])
      expect(heading_rows.css(".btn-done")).to be_empty
      expect(page.css("#entries .entry-grid:not(.entry-heading-row)").map { it.text.squish })
        .to all(match(/handover todo doing done\z/))
    end

    it "shows the status of each entry" do
      entry_on("2026-09-01", "waiting #handover", status: "todo")

      expect(read_tag("handover").at_css("#entries .btn-todo").text).to eq("todo")
    end

    it "leaves out entries of other projects" do
      other = create(:participant, project: create(:project, org:), member:).project
      create(:entry, day: create(:day, project: other), member:, log: "elsewhere #handover")

      expect(read_tag("handover").at_css("#entries").text).not_to include("elsewhere")
    end

    it "finds the tag however it is written in the URL" do
      entry_on("2026-09-01", "done #Handover")

      expect(lines(read_tag("#HandOver")).size).to eq(1)
    end

    it "stays read-only, even when asked to edit" do
      entry_on(Time.zone.today.iso8601, "today #handover")

      page = read_tag("handover", mode: "edit")

      expect(page.at_css("form")).to be_nil
      expect(page.to_html).not_to include("add or edit")
    end

    it "says so when nothing carries the tag" do
      expect(read_tag("nothing").text).to include("No entries are tagged #nothing yet.")
    end
  end

  describe "POST /entries" do
    it "creates an entry on the given day" do
      expect { post entries_path, params: { entry: { date: "2026-03-02", log: "Wrote a spec" } } }
        .to change(Entry, :count).by(1)

      expect(Entry.last.log).to eq("Wrote a spec")
      expect(Entry.last.day.date.iso8601).to eq("2026-03-02")
    end

    it "reports a validation failure instead of raising" do
      expect { post entries_path, params: { entry: { date: "2026-03-02", log: "x" } } }
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
