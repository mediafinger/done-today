require "rails_helper"

RSpec.describe Orgs::EntriesController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let!(:member) { create(:member, org: org, user: user, roles: ["member"]) }
  let(:project) { create(:project, org: org) }
  let!(:participant) { create(:participant, org: org, project: project, member: member, roles: ["participant"]) }
  let(:day) { create(:day, org: org, project: project, date: Date.current) }
  let!(:entry) { create(:entry, day: day, org: org, member: member, log: "Initial entry", status: "doing") }

  before do
    session = sign_in(user)
    session.update!(org: org, project: project)
  end

  describe "GET #index in read mode" do
    it "returns readable entries and has status success" do
      get :index, params: { mode: "read" }
      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@entries)).to include(entry)
    end
  end

  describe "GET #index in edit mode" do
    it "returns editable entries and has status success" do
      get :index, params: { mode: "edit", date: Date.current.to_s }
      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@entries)).to include(entry)
    end
  end

  describe "POST #create" do
    it "creates a new entry and redirects to the edit index" do
      expect {
        post :create, params: { entry: { date: Date.current.to_s, log: "New entry text", status: "todo" } }
      }.to change(Entry, :count).by(1)

      expect(response).to redirect_to(entries_path(date: Date.current.to_s, mode: "edit", scroll_to: "new-entry-field"))
    end
  end

  describe "PATCH #update" do
    it "updates the entry details and redirects" do
      patch :update, params: { id: entry.id, entry: { log: "Updated log", status: "done" } }
      expect(entry.reload.log).to eq("Updated log")
      expect(entry.status).to eq("done")
      expect(response).to redirect_to(entries_path(date: entry.day.date, mode: "edit"))
    end
  end
end
