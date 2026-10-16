require "rails_helper"

RSpec.describe EntryPolicy do
  let(:project) { create(:project) }
  let(:day) { create(:day, project:) }
  let!(:colleagues_entry) { create(:entry, day:, member: create(:participant, project:).member) }
  let(:member) { nil }

  def member_with(org_role:, project_role:)
    create(:member, org: project.org, role: org_role).tap do |member|
      create(:participant, project:, member:, role: project_role) if project_role
    end
  end

  def may_update?(entry)
    described_class.new(entry, member:).apply(:update?)
  end

  def scope(name = :default)
    described_class.new(member:).apply_scope(Entry.all, type: :active_record_relation, name:)
  end

  # org role, project role => may update own entry, may update a colleague's entry
  {
    [ "member", nil ] => [ false, false ],
    [ "member", "observer" ] => [ false, false ],
    [ "member", "participant" ] => [ true, false ],
    [ "member", "lead" ] => [ true, true ],
    [ "owner", nil ] => [ false, false ],
    [ "owner", "observer" ] => [ false, false ],
    [ "owner", "participant" ] => [ true, false ],
    [ "owner", "lead" ] => [ true, true ]
  }.each do |(org_role, project_role), (own, colleagues)|
    context "with org role #{org_role} and project role #{project_role.inspect}" do
      let(:member) { member_with(org_role:, project_role:) }
      # an observer or ex-participant may still have entries from earlier
      let!(:own_entry) { create(:entry, day:, member:) }

      it { expect(may_update?(own_entry)).to be(own) }
      it { expect(may_update?(colleagues_entry)).to be(colleagues) }

      it "shows the edit trail exactly when the project may be managed" do
        manage = ProjectPolicy.new(project, member:).apply(:manage?)
        history = [ own_entry, colleagues_entry ].map { described_class.new(it, member:).apply(:history?) }

        expect(history).to eq([ manage, manage ])
      end

      it "scopes exactly the entries it may update as editable" do
        expected = [ (own_entry if own), (colleagues_entry if colleagues) ].compact

        expect(scope(:editable)).to match_array(expected)
      end

      it "scopes the entries as readable exactly when the project may be shown" do
        readable = ProjectPolicy.new(project, member:).apply(:show?)

        expect(scope.include?(colleagues_entry)).to be(readable)
      end
    end
  end

  context "with a project lead" do
    let(:member) { member_with(org_role: "member", project_role: "lead") }

    it "does not let them edit entries of another project" do
      elsewhere = create(:entry, day: create(:day, project: create(:project, org: project.org)))

      expect(may_update?(elsewhere)).to be(false)
      expect(scope(:editable)).not_to include(elsewhere)
    end

    it "lets them neither read nor edit once archived, not even their own entries" do
      own_entry = create(:entry, day:, member:)
      member.archive!

      expect(may_update?(own_entry)).to be(false)
      expect(scope(:editable)).to be_empty
      expect(scope).to be_empty
    end
  end

  context "with an archived project" do
    let(:member) { member_with(org_role: "owner", project_role: "lead") }

    it "lets nobody edit its entries" do
      own_entry = create(:entry, day:, member:)
      project.archive!

      expect(may_update?(own_entry)).to be(false)
      expect(may_update?(colleagues_entry)).to be(false)
      expect(scope(:editable)).to be_empty
      expect(scope).to include(own_entry, colleagues_entry)
    end
  end

  context "with an owner of another org" do
    let(:member) { create(:member, :owner) }

    it "lets them neither read nor edit" do
      expect(may_update?(colleagues_entry)).to be(false)
      expect(scope(:editable)).to be_empty
      expect(scope).to be_empty
    end
  end

  context "without a member" do
    it "allows nothing" do
      expect(may_update?(colleagues_entry)).to be(false)
      expect(scope(:editable)).to be_empty
      expect(scope).to be_empty
    end
  end
end
