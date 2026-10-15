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

  describe "#archive! and #unarchive!" do
    let(:member) { create(:member, org:) }

    it "moves the member between the active and the archived scope" do
      member.archive!

      expect(member.reload).to be_archived
      expect(org.members.active).not_to include(member)
      expect(org.members.archived).to include(member)

      member.unarchive!

      expect(member.reload).not_to be_archived
      expect(org.members.active).to include(member)
    end

    it "keeps the first archived_at when archived twice" do
      member.update!(archived_at: 2.days.ago.round)
      first = member.archived_at

      member.archive!

      expect(member.reload.archived_at).to eq(first)
    end

    it "keeps entries and participations" do
      participant = create(:participant, member:, project: create(:project, org:))
      entry = create(:entry, member:, day: create(:day, project: participant.project))

      member.archive!

      expect(Entry.exists?(entry.id)).to be(true)
      expect(Participant.exists?(participant.id)).to be(true)
    end
  end

  # regression: `has_many :entries, dependent: :destroy` deleted a person's whole history
  describe "destroying" do
    let(:member) { create(:member, org:) }
    let!(:entry) { create(:entry, member:, day: create(:day, project: create(:project, org:))) }

    it "refuses while the member has entries and keeps them" do
      expect { member.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

      expect(Entry.exists?(entry.id)).to be(true)
      expect(described_class.exists?(member.id)).to be(true)
    end

    it "is refused by the database too, when callbacks are skipped" do
      expect { described_class.transaction(requires_new: true) { described_class.where(id: member.id).delete_all } }
        .to raise_error(ActiveRecord::InvalidForeignKey)

      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "works for a member without entries" do
      other = create(:member, org:)
      create(:participant, member: other, project: create(:project, org:))

      expect { other.destroy! }.to change(described_class, :count).by(-1).and change(Participant, :count).by(-1)
    end
  end
end
