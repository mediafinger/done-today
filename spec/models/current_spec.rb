require "rails_helper"

RSpec.describe Current, type: :model do
  after(:each) do
    Current.reset
  end

  describe "attribute setters" do
    it "sets user and updates user_id" do
      user = build_stubbed(:user, id: SecureRandom.uuid)
      Current.user = user
      expect(Current.user).to eq(user)
      expect(Current.user_id).to eq(user.id)
    end

    it "sets org and updates org_id" do
      org = build_stubbed(:org, id: SecureRandom.uuid)
      Current.org = org
      expect(Current.org).to eq(org)
      expect(Current.org_id).to eq(org.id)
    end

    it "sets project and updates project_id" do
      project = build_stubbed(:project, id: SecureRandom.uuid)
      Current.project = project
      expect(Current.project).to eq(project)
      expect(Current.project_id).to eq(project.id)
    end

    it "sets member and updates member_id" do
      member = build_stubbed(:member, id: SecureRandom.uuid)
      Current.member = member
      expect(Current.member).to eq(member)
      expect(Current.member_id).to eq(member.id)
    end
  end
end
