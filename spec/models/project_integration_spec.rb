require "rails_helper"

RSpec.describe ProjectIntegration, type: :model do
  describe "associations" do
    it "has expected associations" do
      org_assoc = ProjectIntegration.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      proj_assoc = ProjectIntegration.reflect_on_association(:project)
      expect(proj_assoc.macro).to eq(:belongs_to)

      int_assoc = ProjectIntegration.reflect_on_association(:integration)
      expect(int_assoc.macro).to eq(:belongs_to)
    end
  end

  describe "callbacks" do
    it "sets the org from project's org on validation" do
      org = create(:org)
      project = create(:project, org: org)
      integration = create(:integration, org: org)
      pi = build(:project_integration, project: project, integration: integration, org: nil)
      pi.valid?
      expect(pi.org).to eq(org)
    end
  end
end
