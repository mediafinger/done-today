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
    before { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "renders the status controls as submit buttons inside the form" do
      get entries_path(mode: "edit")

      expect(response.body).to include(%(<button name="entry[status]" type="submit" value="done"))
    end

    it "no longer links the status to a PATCH url that drops the typed log" do
      get entries_path(mode: "edit")

      expect(response.body).not_to include("entry%5Bstatus%5D")
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
  end
end
