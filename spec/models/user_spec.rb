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

  describe "#remember_last_visit!" do
    let(:org) { create(:org) }
    let(:user) { create(:member, org:).user }
    let(:project) { create(:project, org:) }

    it "keeps the project when the same org is opened again" do
      user.remember_last_visit!(org:, project:)
      user.remember_last_visit!(org:)

      expect(user.reload).to have_attributes(last_org: org, last_project: project)
    end

    it "drops the project when another org is opened" do
      user.remember_last_visit!(org:, project:)
      user.remember_last_visit!(org: create(:org))

      expect(user.reload.last_project).to be_nil
    end

    it "drops a project that does not belong to the org" do
      user.remember_last_visit!(org:, project: create(:project))

      expect(user.reload).to have_attributes(last_org: org, last_project: nil)
    end
  end
end
