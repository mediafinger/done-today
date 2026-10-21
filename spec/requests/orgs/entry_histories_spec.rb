require "rails_helper"

RSpec.describe "Orgs::EntryHistories" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:author) { create(:participant, project:) }
  let(:lead) { create(:participant, :lead, project:) }
  let!(:entry) { create(:entry, day: create(:day, project:, date: Time.zone.today), member: author.member) }

  # writes through the app, so the history is what the controller records
  def edit_as(participant, **attributes)
    sign_in(participant.member.user)
    patch entry_path(org, project, entry), params: { entry: attributes }
  end

  describe "GET /:org/:project/entries/:id/history" do
    it "lists the changes with who made them, for a project lead" do
      edit_as(author, log: "Wrote more code")
      edit_as(lead, status: "done")

      get entry_history_path(org, project, entry)

      expect(response).to have_http_status(:ok)
      rows = Nokogiri::HTML(response.body).css("tbody tr").map { it.text.squish }
      expect(rows.size).to eq(2)
      expect(rows.first).to include(author.member.name, "updated", "log", "Wrote some code", "Wrote more code")
      expect(rows.last).to include(lead.member.name, "updated", "status", "doing", "done")
    end

    it "marks a change made through the MCP server" do
      user = author.member.user
      Current.set(org:, user:, connection: create(:token_auth_connection, user:)) do
        Entries::Update.call(entry:, attributes: { log: "Logged by Claude" })
      end
      sign_in(lead.member.user)

      get entry_history_path(org, project, entry)

      expect(Nokogiri::HTML(response.body).css("tbody tr").sole.text).to include("via MCP")
    end

    it "names a deactivated member as well" do
      edit_as(author, log: "Wrote more code")
      author.member.archive!
      sign_in(lead.member.user)

      get entry_history_path(org, project, entry)

      expect(Nokogiri::HTML(response.body).css("tbody tr").text).to include(author.member.name)
    end

    it "explains an entry without recorded changes" do
      sign_in(lead.member.user)

      get entry_history_path(org, project, entry)

      expect(response.body).to include("No changes recorded")
    end

    it "is forbidden for the author" do
      edit_as(author, log: "Wrote more code")

      get entry_history_path(org, project, entry)

      expect(response).to have_http_status(:forbidden)
    end

    it "is a 404 for an entry of another org" do
      other = create(:entry)
      sign_in(lead.member.user)

      get entry_history_path(org, project, other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the marker on the day page" do
    before { create(:entry, day: entry.day, member: author.member, log: "Never changed") }

    def history_links
      Nokogiri::HTML(response.body).css("a").map { it["href"] }.select { it.end_with?("/history") }
    end

    it "links the edited entries to their history, for a project lead" do
      edit_as(author, log: "Wrote more code")
      sign_in(lead.member.user)

      get day_path(org, project, Time.zone.today)

      expect(history_links).to eq([ entry_history_path(org, project, entry) ])
    end

    it "is not shown to participants" do
      edit_as(author, log: "Wrote more code")

      get day_path(org, project, Time.zone.today)

      expect(history_links).to be_empty
    end
  end
end
