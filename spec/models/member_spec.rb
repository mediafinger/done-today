require "rails_helper"

RSpec.describe Member do
  let(:org) { create(:org) }

  describe "roles" do
    it "adds and removes roles without duplicating them" do
      member = create(:member, org:)

      member.add_role!("owner")
      member.add_role!("owner")

      expect(member.reload.roles).to contain_exactly("member", "owner")

      member.delete_role!("owner")

      expect(member.reload.roles).to contain_exactly("member")
    end

    it "refuses an unknown role" do
      member = create(:member, org:)

      member.add_role("wizard")

      expect(member.errors[:roles]).to be_present
    end
  end
end
