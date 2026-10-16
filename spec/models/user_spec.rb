require "rails_helper"

RSpec.describe User do
  # regression: `has_many :memberships, dependent: :destroy` took the members and,
  #   through them, every entry of the user with it
  describe "destroying" do
    let(:user) { create(:user) }

    it "refuses while the user has memberships and keeps their entries" do
      member = create(:member, user:)
      entry = create(:entry, member:, day: create(:day, project: create(:project, org: member.org)))

      expect { user.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

      expect(Member.exists?(member.id)).to be(true)
      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "is refused by the database too, when callbacks are skipped" do
      create(:member, user:)

      expect { described_class.transaction(requires_new: true) { described_class.where(id: user.id).delete_all } }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
