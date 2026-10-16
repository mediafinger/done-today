require "rails_helper"

RSpec.describe ProjectPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:record) { project }
  let(:member) { nil }
  let(:context) { { member: } }

  def member_with(org_role:, project_role:, of: org)
    create(:member, org: of, role: org_role).tap do |member|
      create(:participant, project:, member:, role: project_role) if project_role
    end
  end

  # show?, create_entry?, export?, manage?
  def allowed
    %i[show? create_entry? export? manage?].map { policy.apply(it) }
  end

  def scope(name = :default)
    described_class.new(member:).apply_scope(Project.all, type: :active_record_relation, name:)
  end

  # org role, project role => show?, create_entry?, export?, manage?
  {
    [ "member", nil ] => [ false, false, false, false ],
    [ "member", "observer" ] => [ true, false, false, false ],
    [ "member", "participant" ] => [ true, true, false, false ],
    [ "member", "lead" ] => [ true, true, true, true ],
    [ "manager", nil ] => [ true, false, true, true ],
    [ "manager", "participant" ] => [ true, true, true, true ],
    [ "owner", nil ] => [ true, false, true, true ],
    [ "owner", "observer" ] => [ true, false, true, true ],
    [ "owner", "participant" ] => [ true, true, true, true ],
    [ "owner", "lead" ] => [ true, true, true, true ]
  }.each do |(org_role, project_role), (show, create_entry, export, manage)|
    context "with org role #{org_role} and project role #{project_role.inspect}" do
      let(:member) { member_with(org_role:, project_role:) }

      it { expect(policy.apply(:show?)).to be(show) }
      it { expect(policy.apply(:create_entry?)).to be(create_entry) }
      it { expect(policy.apply(:export?)).to be(export) }
      it { expect(policy.apply(:manage?)).to be(manage) }
      # the edit trail of the entries is for those who manage the project
      it { expect(policy.apply(:entry_history?)).to be(manage) }

      it "scopes the project as readable exactly when it may be shown" do
        expect(scope.include?(project)).to be(show)
      end

      it "scopes the project as exportable exactly when it may be exported" do
        expect(scope(:exportable).include?(project)).to be(export)
      end
    end
  end

  # internals see that every project of the org exists, guests only theirs
  describe "the listable scope" do
    before do
      create(:project, org:)
      create(:project) # of another org
    end

    {
      "member" => true, "manager" => true, "owner" => true, "guest" => false
    }.each do |org_role, lists_all|
      context "with org role #{org_role}, participating in the project" do
        let(:member) { member_with(org_role:, project_role: "participant") }

        it "lists #{lists_all ? "all projects of the org" : "only their project"}" do
          expect(scope(:listable)).to match_array(lists_all ? org.projects : [ project ])
        end
      end
    end

    it "lists nothing for an archived member" do
      create(:member, :owner, org:)
      member = member_with(org_role: "owner", project_role: nil).tap(&:archive!)

      expect(described_class.new(member:).apply_scope(Project.all, type: :active_record_relation, name: :listable)).to be_empty
    end
  end

  context "with a guest participating in the project" do
    let(:member) { member_with(org_role: "guest", project_role: "participant") }

    it "allows what a participant may do" do
      expect(allowed).to eq([ true, true, false, false ])
    end
  end

  # archived projects stay readable and exportable, nobody writes into them any more
  context "with an archived project" do
    before { project.archive! }

    # org role, project role => show?, create_entry?, export?, manage?
    {
      [ "member", "observer" ] => [ true, false, false, false ],
      [ "member", "participant" ] => [ true, false, false, false ],
      [ "member", "lead" ] => [ true, false, true, true ],
      [ "owner", nil ] => [ true, false, true, true ],
      [ "owner", "participant" ] => [ true, false, true, true ]
    }.each do |(org_role, project_role), expected|
      context "with org role #{org_role} and project role #{project_role.inspect}" do
        let(:member) { member_with(org_role:, project_role:) }

        it("allows #{expected}") { expect(allowed).to eq(expected) }

        it "scopes it as manageable exactly when it may be managed, so it can be unarchived" do
          expect(scope(:manageable).include?(project)).to be(expected.last)
        end
      end
    end
  end

  describe "create? and the manageable scope" do
    let(:record) { Project }

    # org role, project role => create?, manageable includes the project
    {
      [ "member", nil ] => [ false, false ],
      [ "member", "participant" ] => [ false, false ],
      [ "member", "lead" ] => [ false, true ],
      [ "manager", nil ] => [ true, true ],
      [ "owner", nil ] => [ true, true ]
    }.each do |(org_role, project_role), (create, manageable)|
      context "with org role #{org_role} and project role #{project_role.inspect}" do
        let(:member) { member_with(org_role:, project_role:) }

        it("allows #{[ create, manageable ]}") do
          expect([ policy.apply(:create?), scope(:manageable).include?(project) ]).to eq([ create, manageable ])
        end
      end
    end

    context "with an owner of another org" do
      let(:member) { member_with(org_role: "owner", project_role: nil, of: create(:org)) }

      it { expect(scope(:manageable)).not_to include(project) }
    end

    context "with an archived org owner" do
      let(:member) { member_with(org_role: "owner", project_role: nil).tap(&:archive!) }

      before { create(:member, :owner, org:) } # the org keeps an owner

      it "lets them create and manage nothing" do
        expect(policy.apply(:create?)).to be(false)
        expect(scope(:manageable)).to be_empty
      end
    end
  end

  context "with an owner of another org" do
    let(:member) { member_with(org_role: "owner", project_role: nil, of: create(:org)) }

    it "allows nothing" do
      expect(allowed).to all(be(false))
      expect(scope).not_to include(project)
      expect(scope(:exportable)).not_to include(project)
    end
  end

  context "with an archived owner of the org and the project" do
    let(:member) { member_with(org_role: "owner", project_role: "lead").tap(&:archive!) }

    before { create(:member, :owner, org:) } # the org keeps an owner

    it "allows nothing" do
      expect(allowed).to all(be(false))
      expect(scope).to be_empty
      expect(scope(:exportable)).to be_empty
    end
  end

  context "without a member" do
    let(:member) { nil }

    it "allows nothing" do
      expect(allowed).to all(be(false))
      expect(described_class.new(Project, member:).apply(:create?)).to be(false)
      expect([ scope, scope(:manageable), scope(:exportable) ]).to all(be_empty)
    end
  end

  it { expect(policy.resolve_rule(:validate_times?)).to eq(:show?) }

  %i[export_csv? export_days_csv?].each do |rule|
    it { expect(policy.resolve_rule(rule)).to eq(:export?) }
  end

  %i[edit? update? archive? unarchive?].each do |rule|
    it { expect(policy.resolve_rule(rule)).to eq(:manage?) }
  end
end
