require "rails_helper"

RSpec.describe Member do
  let(:org) { create(:org) }

  describe "role" do
    it "is member by default" do
      expect(create(:member, org:)).to have_attributes(role: "member", owner?: false)
    end

    it "refuses an unknown role" do
      member = build(:member, org:, role: "wizard")

      expect(member).not_to be_valid
      expect(member.errors[:role]).to be_present
    end
  end

  describe "guests" do
    let(:project) { create(:project, org:) }

    it "counts members, managers and owners as internal, guests not" do
      expect(%w[guest member manager owner].map { build(:member, role: it).internal? }).to eq([ false, true, true, true ])
    end

    it "lets a member become a guest who participates in a project" do
      member = create(:participant, project:).member

      expect(member.update(role: "guest")).to be(true)
    end

    # guests only see their projects, so they need at least one
    it "refuses to make a member without a project a guest" do
      member = create(:member, org:)

      expect(member.update(role: "guest")).to be(false)
      expect(member.errors[:role]).to include("guest has to participate in a project first")
    end

    it "refuses to make a project owner a guest, naming the project" do
      member = create(:participant, :owner, project:).member

      expect(member.update(role: "guest")).to be(false)
      expect(member.errors[:role]).to include("guest cannot own #{project.name}, change the project role first")
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

  describe "managers" do
    it "lets managers and owners manage the org, nobody else" do
      expect(%w[guest member manager owner].map { build(:member, role: it).managing? }).to eq([ false, false, true, true ])
    end

    it "does not count a manager as the org's owner" do
      owner = create(:member, :owner, org:)
      create(:member, :manager, org:)
      owner.role = "manager"

      expect(owner).not_to be_valid
    end
  end

  describe "keeping an owner" do
    let(:owner) { create(:member, :owner, org:) }

    it "refuses to demote the last active owner" do
      owner.role = "member"

      expect(owner).not_to be_valid
      expect(owner.errors[:base]).to include("#{org.name} needs at least one active owner")
    end

    it "refuses to archive the last active owner" do
      expect { owner.archive! }.to raise_error(ActiveRecord::RecordInvalid)

      expect(owner.reload).not_to be_archived
    end

    it "does not count an archived owner" do
      create(:member, :owner, org:, archived_at: 1.day.ago)
      owner.role = "member"

      expect(owner).not_to be_valid
    end

    it "does not count an owner of another org" do
      create(:member, :owner)
      owner.role = "member"

      expect(owner).not_to be_valid
    end

    it "lets one of two owners step down" do
      create(:member, :owner, org:)

      expect { owner.update!(role: "member") }.not_to raise_error
      expect { owner.archive! }.not_to raise_error
    end

    it "leaves changes that keep the owner alone" do
      owner.name = "Renamed"

      expect(owner).to be_valid
    end

    it "lets an archived owner be changed, who no longer counts anyway" do
      create(:member, :owner, org:)
      owner.archive!

      expect { owner.update!(role: "member") }.not_to raise_error
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
