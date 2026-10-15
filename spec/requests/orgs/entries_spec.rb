require "rails_helper"

RSpec.describe "Orgs::Entries" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in_and_open(participant) }

  describe "the URLs from before the split" do
    def expect_moved_to(path)
      expect(response).to redirect_to(path)
      expect(response).to have_http_status(:moved_permanently)
    end

    it "sends a bare /entries to today's entries" do
      get entries_path

      expect_moved_to(day_path(Time.zone.today))
    end

    it "sends the edit mode to the day's edit page, keeping unlocked and validate" do
      get entries_path(date: "2026-03-01", mode: "edit", unlocked: "1", validate: "1")

      expect_moved_to(edit_day_path("2026-03-01", unlocked: "1", validate: "1"))
    end

    it "sends an unparseable date to today" do
      get entries_path(date: "not-a-date", mode: "edit")

      expect_moved_to(edit_day_path(Time.zone.today))
    end

    it "sends a day of another project to that day, keeping the project" do
      other = create(:participant, project: create(:project, org:), member:).project

      get entries_path(date: "2026-03-01", project_id: other.id)

      expect_moved_to(day_path("2026-03-01", project_id: other.id))
    end

    it "sends the project grouping to the project page" do
      get entries_path(project_id: project.id, mode: "read")

      expect_moved_to(project_path(project.slug))
    end

    it "sends the week to the week page" do
      get entries_path(week: "2026-W38", project_id: project.id)

      expect_moved_to(week_path("2026-W38", project_id: project.id))
    end

    it "sends the tag to the tag page, keeping the project" do
      other = create(:participant, project: create(:project, org:), member:).project

      get entries_path(tag: "handover", mode: "read", project_id: other.id)

      expect_moved_to(tag_path("handover", project_id: other.id))
    end

    it "sends the member to the member's page" do
      get entries_path(member_id: member.id, project_id: project.id)

      expect_moved_to(member_entries_path(member, project_id: project.id))
    end

    it "is a 404 for a project the member cannot read" do
      get entries_path(project_id: create(:project, org:).id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the lock on past days" do
    let!(:old_entry) { create(:entry, day: create(:day, project:, date: yesterday), member:) }

    def yesterday = Time.zone.yesterday

    it "refuses to update an entry of a locked past day" do
      patch entry_path(old_entry), params: { entry: { log: "Changed in passing" } }

      expect(old_entry.reload.log).to eq("Wrote some code")
      expect(response).to redirect_to(edit_day_path(yesterday))
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
      expect(response).to redirect_to(edit_day_path(yesterday, unlocked: true))
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

  describe "as an observer of the project" do
    before { sign_in_and_open(create(:participant, :observer, project:)) }

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

    # a project_id passed the project check, then the missing current project raised
    it "sends an org owner without a current project to pick one, even with a project_id" do
      owner = create(:member, :owner, org:)
      sign_in(owner.user)
      get open_path(org.slug)

      post entries_path(project_id: project.id), params: { entry: { date: Time.zone.today.iso8601, log: "Not here" } }

      expect(response).to redirect_to(projects_path)
      expect(Entry.exists?(log: "Not here")).to be(false)
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

      expect(response).to redirect_to(edit_day_path(entry.day.date, unlocked: true))
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
