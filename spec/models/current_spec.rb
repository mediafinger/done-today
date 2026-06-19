require "rails_helper"

RSpec.describe Current do
  after do
    described_class.reset
  end

  describe "attribute setters" do
    it "sets user and updates user_id" do
      user = build_stubbed(:user, id: SecureRandom.uuid)
      described_class.user = user
      expect(described_class.user).to eq(user)
      expect(described_class.user_id).to eq(user.id)
    end

    it "sets org and updates org_id" do
      org = build_stubbed(:org, id: SecureRandom.uuid)
      described_class.org = org
      expect(described_class.org).to eq(org)
      expect(described_class.org_id).to eq(org.id)
    end

    it "sets project and updates project_id" do
      project = build_stubbed(:project, id: SecureRandom.uuid)
      described_class.project = project
      expect(described_class.project).to eq(project)
      expect(described_class.project_id).to eq(project.id)
    end

    it "sets member and updates member_id" do
      member = build_stubbed(:member, id: SecureRandom.uuid)
      described_class.member = member
      expect(described_class.member).to eq(member)
      expect(described_class.member_id).to eq(member.id)
    end
  end
end
