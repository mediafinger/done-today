require "rails_helper"

RSpec.describe "Orgs::Entries" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let!(:participant) { create(:participant, project:, member:) }

  before { sign_in(participant.member.user) }

  describe "the lock on past days" do
    let!(:old_entry) { create(:entry, day: create(:day, project:, date: yesterday), member:) }

    def yesterday = Time.zone.yesterday

    it "refuses to update an entry of a locked past day" do
      patch entry_path(org, project, old_entry), params: { entry: { log: "Changed in passing" } }

      expect(old_entry.reload.log).to eq("Wrote some code")
      expect(response).to redirect_to(edit_day_path(org, project, yesterday))
      expect(flash[:alert]).to eq("#{yesterday.iso8601} is locked, unlock the day to change it")
    end

    it "reports the lock in place for a Turbo Stream update" do
      patch entry_path(org, project, old_entry), params: { entry: { status: "done" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is locked, unlock the day to change it")
      expect(old_entry.reload.status).to eq("doing")
    end

    it "updates the entry once the day is unlocked" do
      patch entry_path(org, project, old_entry), params: { entry: { log: "Fixed it after all" }, unlocked: "1" }

      expect(old_entry.reload.log).to eq("Fixed it after all")
      expect(response).to redirect_to(edit_day_path(org, project, yesterday, unlocked: true))
    end

    it "refuses a new entry on a locked past day, without creating the day" do
      expect { post entries_path(org, project), params: { entry: { date: (yesterday - 1).iso8601, log: "Logged late" } } }
        .not_to change { [ Entry.count, Day.count ] }

      expect(flash[:alert]).to include("is locked")
    end

    it "creates the entry once the day is unlocked" do
      expect { post entries_path(org, project), params: { entry: { date: yesterday.iso8601, log: "Logged late" }, unlocked: "1" } }
        .to change(Entry, :count).by(1)
    end

    it "keeps today and future days open without unlocking" do
      post entries_path(org, project), params: { entry: { date: Time.zone.tomorrow.iso8601, log: "Planned ahead" } }

      expect(Entry.exists?(log: "Planned ahead")).to be(true)
    end
  end

  describe "as an observer of the project" do
    before { sign_in(create(:participant, :observer, project:).member.user) }

    it "refuses to create an entry" do
      expect { post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Only watching" } } }
        .not_to change(Entry, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /entries" do
    it "creates an entry on the given day" do
      expect { post entries_path(org, project), params: { entry: { date: "2026-03-02", log: "Wrote a spec" }, unlocked: "1" } }
        .to change(Entry, :count).by(1)

      expect(Entry.last.log).to eq("Wrote a spec")
      expect(Entry.last.day.date.iso8601).to eq("2026-03-02")
    end

    it "reports a validation failure instead of raising" do
      expect { post entries_path(org, project), params: { entry: { date: "2026-03-02", log: "x" }, unlocked: "1" } }
        .not_to change(Entry, :count)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it "writes into the project of the path, whichever the member visited last" do
      other = create(:participant, project: create(:project, org:), member:).project
      get day_path(org, other, Time.zone.today)

      post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged here" } }

      expect(Entry.find_by(log: "Logged here").project).to eq(project)
    end

    it "refuses an entry for a project the member cannot read" do
      hidden = create(:project, org:)

      post entries_path(org, hidden), params: { entry: { date: Time.zone.today.iso8601, log: "Not here" } }

      expect(response).to have_http_status(:not_found)
      expect(Entry.exists?(log: "Not here")).to be(false)
    end
  end

  describe "PATCH /entries/:id" do
    let(:entry) { create(:entry, day: create(:day, project:), member:) }

    it "updates the log" do
      patch entry_path(org, project, entry), params: { entry: { log: "Rewrote a spec" } }

      expect(entry.reload.log).to eq("Rewrote a spec")
    end

    it "keeps the status when only the log is submitted" do
      entry.update!(status: "done")

      patch entry_path(org, project, entry), params: { entry: { log: "Rewrote a spec" } }

      expect(entry.reload.status).to eq("done")
    end

    it "updates the status" do
      patch entry_path(org, project, entry), params: { entry: { status: "done" } }

      expect(entry.reload.status).to eq("done")
    end

    it "updates log and status together without dropping either" do
      patch entry_path(org, project, entry), params: { entry: { log: "Both at once", status: "done" } }

      expect(entry.reload.log).to eq("Both at once")
      expect(entry.status).to eq("done")
    end

    it "surfaces a blank log as an error rather than silently ignoring it" do
      patch entry_path(org, project, entry), params: { entry: { log: "" } }

      expect(entry.reload.log).to eq("Wrote some code")
      expect(flash[:alert]).to be_present
    end

    it "refuses to update a colleague's entry and leaves it alone" do
      colleagues_entry = create(:entry, day: entry.day, member: create(:participant, project:).member)

      patch entry_path(org, project, colleagues_entry), params: { entry: { log: "Not mine to change" } }

      expect(response).to have_http_status(:forbidden)
      expect(colleagues_entry.reload.log).to eq("Wrote some code")
    end

    it "refuses a Turbo Stream update of a colleague's entry with a bare 403" do
      colleagues_entry = create(:entry, day: entry.day, member: create(:participant, project:).member)

      patch entry_path(org, project, colleagues_entry), params: { entry: { status: "done" } }, as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
      expect(colleagues_entry.reload.status).to eq("doing")
    end

    it "is a 404 for an entry of another project than the path's" do
      other = create(:participant, project: create(:project, org:), member:).project
      elsewhere = create(:entry, day: create(:day, project: other), member:)

      patch entry_path(org, project, elsewhere), params: { entry: { log: "Wrong project" } }

      expect(response).to have_http_status(:not_found)
      expect(elsewhere.reload.log).to eq("Wrote some code")
    end

    it "stays on the unlocked past day instead of locking it again" do
      patch entry_path(org, project, entry), params: { entry: { log: "Fixed it after all" }, unlocked: "1" }

      expect(response).to redirect_to(edit_day_path(org, project, entry.day.date, unlocked: true))
    end
  end

  describe "DELETE /entries/:id" do
    let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "deletes the entry and keeps the day" do
      expect { delete entry_path(org, project, entry) }.to change(Entry, :count).by(-1)

      expect(Day.exists?(entry.day_id)).to be(true)
      expect(response).to redirect_to(edit_day_path(org, project, Time.zone.today))
    end

    it "keeps the last log in the history" do
      delete entry_path(org, project, entry)

      history = RecordHistory.find_by!(record_id: entry.id, event: "deleted")
      expect(history.record_changes["log"]).to eq([ "Wrote some code", nil ])
      expect(history.user_id).to eq(member.user_id)
    end

    it "refuses an entry of a locked past day, and deletes it once unlocked" do
      old_entry = create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:)

      expect { delete entry_path(org, project, old_entry) }.not_to change(Entry, :count)
      expect(flash[:alert]).to include("is locked")

      expect { delete entry_path(org, project, old_entry), params: { unlocked: "1" } }.to change(Entry, :count).by(-1)
    end

    it "refuses an observer, even for an entry of their own" do
      participant.update!(role: "observer")

      expect { delete entry_path(org, project, entry) }.not_to change(Entry, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "the edit trail" do
    let(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    def histories = RecordHistory.where(record_type: "Entry")

    it "records who created an entry, in which org, with its log" do
      expect { post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Wrote a spec" } } }
        .to change(histories, :count).by(1)

      history = histories.last
      expect(history).to have_attributes(event: "created", record_id: Entry.last.id, org_id: org.id,
        user_id: member.user_id, done_by_admin: false)
      expect(history.record_changes).to include("log" => [ nil, "Wrote a spec" ], "status" => %w[doing todo])
      expect(history.record_changes.keys).not_to include("created_at", "updated_at")
    end

    it "records an edit with exactly the changed attributes" do
      entry

      expect { patch entry_path(org, project, entry), params: { entry: { log: "Rewrote a spec", status: "done" } } }
        .to change(histories, :count).by(1)

      expect(histories.last).to have_attributes(event: "updated", record_id: entry.id, user_id: member.user_id)
      expect(histories.last.record_changes)
        .to eq("log" => [ "Wrote some code", "Rewrote a spec" ], "status" => %w[doing done])
    end

    it "records a project lead editing a colleague's entry as the lead" do
      lead = create(:participant, :lead, project:)
      sign_in(lead.member.user)

      patch entry_path(org, project, entry), params: { entry: { status: "done" } }

      expect(histories.last).to have_attributes(event: "updated", user_id: lead.member.user_id)
    end

    it "records nothing for a refused edit" do
      colleagues_entry = create(:entry, day: entry.day, member: create(:participant, project:).member)

      expect { patch entry_path(org, project, colleagues_entry), params: { entry: { log: "Not mine to change" } } }
        .not_to change(histories, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "records nothing for an invalid edit" do
      entry

      expect { patch entry_path(org, project, entry), params: { entry: { log: "x" } } }.not_to change(histories, :count)
    end

    it "records nothing for a save that changes nothing" do
      entry

      expect { patch entry_path(org, project, entry), params: { entry: { status: "doing" } } }.not_to change(histories, :count)
    end

    it "records nothing on a locked past day" do
      old_entry = create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:)

      expect { patch entry_path(org, project, old_entry), params: { entry: { log: "Changed in passing" } } }
        .not_to change(histories, :count)
    end

    it "rolls the edit back when the history cannot be written" do
      allow(RecordHistoryService).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

      expect { patch entry_path(org, project, entry), params: { entry: { log: "Lost with the history" } } }
        .to raise_error(ActiveRecord::StatementInvalid)

      expect(entry.reload.log).to eq("Wrote some code")
    end

    it "rolls the new entry and its day back when the history cannot be written" do
      allow(RecordHistoryService).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

      counts = -> { [ Entry.count, Day.count ] }
      before = counts.call

      expect { post entries_path(org, project), params: { entry: { date: "2026-03-02", log: "Lost" }, unlocked: "1" } }
        .to raise_error(ActiveRecord::StatementInvalid)

      expect(counts.call).to eq(before)
    end
  end

  describe "Turbo Stream responses" do
    let(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member:) }

    it "replaces just the edited entry instead of redirecting the whole page" do
      patch entry_path(org, project, entry), params: { entry: { log: "Saved on blur" } }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(entry)}"))
      expect(response.body).to include("Saved on blur")
    end

    it "reports an invalid update in place, keeping what was typed" do
      patch entry_path(org, project, entry), params: { entry: { log: "x" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(value="x"))
      expect(entry.reload.log).to eq("Wrote some code")
    end

    it "inserts a created entry above the input field and blanks the field" do
      post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Typed and blurred" } },
        as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="before" target="new-entry"))
      expect(response.body).to include(%(action="replace" target="new-entry"))
      expect(response.body).to include("Typed and blurred")
    end

    it "removes a deleted entry from the list" do
      create(:entry, day: entry.day, member:, log: "Stays on the day")

      delete entry_path(org, project, entry), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="remove" target="#{ActionView::RecordIdentifier.dom_id(entry)}"))
      expect(response.body).not_to include("no-entries-yet")
    end

    it "puts the hint back once the last entry is deleted" do
      delete entry_path(org, project, entry), as: :turbo_stream

      expect(response.body).to include(%(action="before" target="new-entry"))
      expect(response.body).to include(%(id="no-entries-yet"))
    end

    it "reports a refused delete in place" do
      old_entry = create(:entry, day: create(:day, project:, date: Time.zone.yesterday), member:)

      delete entry_path(org, project, old_entry), as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(old_entry)}"))
      expect(response.body).to include("is locked")
    end

    it "reports an invalid create without throwing the text away" do
      post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "x" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include(%(action="before" target="new-entry"))
      expect(response.body).to include(%(value="x"))
    end
  end
end
