require "rails_helper"

RSpec.describe "Orgs::Days" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in(participant.member.user) }

  describe "GET /days/:date/edit" do
    it "shows the requested day, not today" do
      get edit_day_path(org, project, "2026-03-01")

      # the date nav always links to today, so assert on the heading
      expect(response.body).to include("#{project.name} Day 2026-03-01 (Sunday)")
      expect(response.body).not_to include("Day #{Time.zone.today.iso8601}")
    end

    it "is a 404 for a date that does not exist" do
      get edit_day_path(org, project, "2026-02-31")

      expect(response).to have_http_status(:not_found)
    end

    it "is a 404 for something that is no date" do
      get "/#{org.slug}/#{project.slug}/days/not-a-date/edit"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the editable entry form" do
    let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "renders the status controls as submit buttons inside the form" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).to include(%(<button name="entry[status]" type="submit" value="done"))
    end

    # ENTER submits a form through its first submit button. When that was the "todo"
    #   status button, every ENTER in the log field reset the status to todo.
    it "makes a button without a status the one ENTER submits through" do
      get edit_day_path(org, project, Time.zone.today)

      form = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(entry)} form")
      default_button = form.at_css("button[type=submit]")

      expect(default_button["name"]).to be_nil
      expect(form.css("button[name='entry[status]']").size).to eq(Entry::STATES.size)
    end

    it "no longer links the status to a PATCH url that drops the typed log" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).not_to include("entry%5Bstatus%5D")
    end

    it "wires the entry-form controller up to the field and to the status buttons" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).to include("keydown.esc-&gt;entry-form#revert")
      expect(response.body).to include("blur-&gt;entry-form#saveIfChanged")
      expect(response.body).to include("mousedown-&gt;entry-form#noteStatusPress")
    end

    it "gives every entry a stable dom id so a Turbo Stream can address it" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(entry)}"))
    end

    it "gives each log field its own id instead of repeating entry_log" do
      create(:entry, day: entry.day, member:, log: "A second entry")

      get edit_day_path(org, project, Time.zone.today)

      expect(response.body.scan(%(id="entry_log")).count).to eq(0)
    end

    it "focuses the new entry field without an inline script" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).not_to include("document.location.hash")
      expect(response.body).to include(%(data-controller="autofocus"))
    end
  end

  describe "past days" do
    let!(:old_entry) { create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:) }

    it "renders a past day read-only and offers to unlock it" do
      get edit_day_path(org, project, Time.zone.yesterday)

      expect(response.body).not_to include(%(data-controller="entry-form"))
      expect(response.body).to include(old_entry.log)
      expect(response.body).to include("unlock to edit")
    end

    it "does not offer a new entry field while the day is locked" do
      get edit_day_path(org, project, Time.zone.yesterday)

      expect(response.body).not_to include(%(id="new-entry"))
    end

    it "edits the day once it has been unlocked" do
      get edit_day_path(org, project, Time.zone.yesterday, unlocked: "1")

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).to include(%(id="new-entry"))
      expect(response.body).to include("lock again")
    end

    it "keeps today editable without unlocking" do
      create(:entry, day: create(:day, project:, date: Time.zone.today), member:)

      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).to include(%(data-controller="entry-form"))
      expect(response.body).not_to include("unlock to edit")
    end

    it "keeps a future day editable without unlocking" do
      get edit_day_path(org, project, Time.zone.tomorrow)

      expect(response.body).to include(%(id="new-entry"))
      expect(response.body).not_to include("unlock to edit")
    end
  end

  describe "validating a day in edit mode" do
    let(:day) { create(:day, project:, date: Time.zone.yesterday) }

    def edit_day(**params)
      get edit_day_path(org, project, day.date, unlocked: "1", **params)
      Nokogiri::HTML(response.body)
    end

    def validate_day
      edit_day(validate: "1")
    end

    it "offers the check once the day has entries" do
      create(:entry, day:, member:, log: "start@09:00 kickoff")

      link = edit_day.at_css(".spacing-grid a[href*='validate']")

      expect(link.text).to eq("validate")
      expect(link["href"]).to eq(edit_day_path(org, project, day.date, unlocked: true, validate: "1"))
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
      create(:entry, day:, member:, log: "end@24:00 for~40h #release wrapped up", status: "todo")

      box = validate_day.at_css("#time-issues")

      expect(box.css("li").map { it["data-code"] }).to eq(%w[over_a_day tags_exceed_day todo_time])
      expect(box.at_css("li").text.squish).to eq("#{member.name} for~40h exceeds 24h")
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

    it "accepts a day without times, as they are optional" do
      create(:entry, day:, member:, log: "wrote some code")

      page = validate_day

      expect(page.at_css("#validation-ok")).to be_present
      expect(page.at_css("#time-issues")).to be_nil
    end

    it "asks for times when the project requires them" do
      project.update!(times_required: true)
      create(:entry, day:, member:, log: "wrote some code")

      expect(validate_day.css("#time-issues li").map { it["data-code"] }).to eq(%w[no_times])
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
      get day_path(org, project, day.date)
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
      create(:entry, day: create(:day, project:, date: day.date + 1), member:, log: "end@17:00")

      expect(read_day.at_css(".time-info").text.squish).to eq("#{member.name} 09:00 – …")
    end

    it "links the tags of the tag line to their overview page" do
      log("handed over #Handover")

      link = read_day.at_css(".tag-info a.tag")

      expect(link.text).to eq("#handover")
      expect(link["href"]).to eq(tag_path(org, project, "handover"))
    end

    it "links the tags inside a log, keeping how they were written" do
      log("reviewed #PR123 today")

      link = read_day.at_css("#entries a.tag")

      expect(link.text).to eq("#PR123")
      expect(link["href"]).to eq(tag_path(org, project, "pr123"))
    end

    it "still escapes the rest of the log" do
      log("<b>bold</b> #tagged")

      read_day

      expect(response.body).to include("&lt;b&gt;bold&lt;/b&gt;")
      expect(response.body).not_to include("<b>bold</b>")
    end
  end

  describe "GET /days/:date" do
    it "lists everybody's entries of the day, and only of that day" do
      colleague = create(:participant, project:).member
      create(:entry, day: create(:day, project:, date: Date.new(2026, 9, 1)), member:, log: "mine")
      create(:entry, day: Day.find_by(date: Date.new(2026, 9, 1)), member: colleague, log: "theirs")
      create(:entry, day: create(:day, project:, date: Date.new(2026, 9, 2)), member:, log: "the next day")

      get day_path(org, project, "2026-09-01")

      expect(response.body).to include("mine", "theirs")
      expect(response.body).not_to include("the next day")
    end

    it "offers to add or edit" do
      get day_path(org, project, Time.zone.today)

      link = Nokogiri::HTML(response.body).css(".spacing-grid a").find { it.text == "add or edit" }

      expect(link["href"]).to eq(edit_day_path(org, project, Time.zone.today))
    end
  end

  describe "a day of another project of the member" do
    let(:other) { create(:participant, project: create(:project, org:), member:).project }

    before { create(:entry, day: create(:day, project: other, date: Time.zone.today), member:, log: "elsewhere") }

    it "shows that project's day" do
      get day_path(org, other, Time.zone.today)

      expect(response.body).to include("elsewhere", "#{other.name} Day")
    end

    it "keeps the project in the arrows" do
      get day_path(org, other, Time.zone.today)

      arrows = Nokogiri::HTML(response.body).css(".spacing-grid .right a")

      expect(arrows.map { it["href"] }).to eq([
        day_path(org, other, Time.zone.yesterday), day_path(org, other, Time.zone.tomorrow)
      ])
    end

    # the new entry field used to post into the project selected in the session
    it "writes new entries into the project of the path" do
      get edit_day_path(org, other, Time.zone.today)

      form = Nokogiri::HTML(response.body).at_css("#new-entry form")

      expect(form["action"]).to eq(entries_path(org, other))
    end

    it "is a 404 for a project of the org the member cannot read" do
      get day_path(org, create(:project, org:), Time.zone.today)

      expect(response).to have_http_status(:not_found)
    end

    it "is a 404 for a project of another org under this org's slug" do
      membership = create(:member, user: member.user)
      foreign = create(:participant, member: membership, project: create(:project, org: membership.org)).project

      get day_path(org, foreign, Time.zone.today)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the date nav" do
    it "stays in edit mode on the edit page" do
      get edit_day_path(org, project, Time.zone.today)

      link = Nokogiri::HTML(response.body).css("nav a").find { it.text == "yesterday" }

      expect(link["href"]).to eq(edit_day_path(org, project, Time.zone.yesterday))
    end

    it "goes to the day's entries everywhere else" do
      get project_path(org, project)

      link = Nokogiri::HTML(response.body).css("nav a").find { it.text == "yesterday" }

      expect(link["href"]).to eq(day_path(org, project, Time.zone.yesterday))
    end
  end

  describe "as an observer of the project" do
    let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    before { sign_in(create(:participant, :observer, project:).member.user) }

    it "does not offer to add or edit" do
      get day_path(org, project, Time.zone.today)

      expect(response.body).not_to include("add or edit")
    end

    it "shows the day read-only in edit mode, with everybody's entries and no way to unlock" do
      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).to include(entry.log)
      expect(response.body).not_to include(%(id="new-entry"))
      expect(response.body).not_to include(%(data-controller="entry-form"))
      expect(response.body).not_to include("unlock to edit")
    end
  end
end
