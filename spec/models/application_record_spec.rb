require "rails_helper"

RSpec.describe ApplicationRecord do
  let(:org) { create(:org) }
  let(:user) { create(:user) }
  let(:project) { build(:project, org: org) }


  describe "#create_with_history" do
    it "saves the record and creates history when org and user are provided in params" do
      expect {
        project.create_with_history(project, org: org, user: user)
      }.to change(Project, :count).by(1)
       .and change(RecordHistory, :count).by(1)

      history = RecordHistory.last
      expect(history.event).to eq("created")
      expect(history.record_type).to eq("Project")
      expect(history.record_id).to eq(project.id)
    end

    it "raises ArgumentError if org/user omitted" do
      expect {
        project.create_with_history(project)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#update_with_history" do
    before { project.save! }

    it "saves the updated record and creates history when org and user are provided" do
      project.name = "Updated Project Name"
      expect {
        project.update_with_history(project, org: org, user: user)
      }.to change(RecordHistory, :count).by(1)

      history = RecordHistory.last
      expect(history.event).to eq("updated")
    end
  end

  describe "#destroy_with_history" do
    before { project.save! }

    it "destroys the record and creates history when org and user are provided" do
      expect {
        project.destroy_with_history(project, org: org, user: user)
      }.to change(Project, :count).by(-1)
       .and change(RecordHistory, :count).by(1)

      history = RecordHistory.last
      expect(history.event).to eq("deleted")
    end
  end
end
