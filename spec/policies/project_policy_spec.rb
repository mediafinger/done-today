require "rails_helper"

RSpec.describe ProjectPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }

  def member_with(org_roles:, project_roles:, of: org)
    create(:member, org: of, roles: org_roles).tap do |member|
      create(:participant, project:, member:, roles: project_roles) if project_roles
    end
  end

  # org roles, project roles => show?, create_entry?, export?, manage?
  {
    [ %w[member], nil ] => [ false, false, false, false ],
    [ %w[member], %w[observer] ] => [ true, false, false, false ],
    [ %w[member], %w[participant] ] => [ true, true, false, false ],
    [ %w[member], %w[owner] ] => [ true, true, true, true ],
    [ %w[member owner], nil ] => [ true, false, true, true ],
    [ %w[member owner], %w[observer] ] => [ true, false, true, true ],
    [ %w[member owner], %w[participant] ] => [ true, true, true, true ],
    [ %w[member owner], %w[owner] ] => [ true, true, true, true ]
  }.each do |(org_roles, project_roles), (show, create_entry, export, manage)|
    context "with org roles #{org_roles} and project roles #{project_roles.inspect}" do
      let(:member) { member_with(org_roles:, project_roles:) }
      let(:policy) { described_class.new(member, project) }

      it { expect(policy.show?).to be(show) }
      it { expect(policy.create_entry?).to be(create_entry) }
      it { expect(policy.export?).to be(export) }
      it { expect(policy.manage?).to be(manage) }
      # the edit trail of the entries is for those who manage the project
      it { expect(policy.entry_history?).to be(manage) }

      it "lists the project as readable exactly when it may be shown" do
        expect(described_class.readable(member).include?(project)).to be(show)
      end

      it "lists the project as exportable exactly when it may be exported" do
        expect(described_class.exportable(member).include?(project)).to be(export)
      end
    end
  end

  # archived projects stay readable and exportable, nobody writes into them any more
  context "with an archived project" do
    before { project.archive! }

    # org roles, project roles => show?, create_entry?, export?, manage?
    {
      [ %w[member], %w[observer] ] => [ true, false, false, false ],
      [ %w[member], %w[participant] ] => [ true, false, false, false ],
      [ %w[member], %w[owner] ] => [ true, false, true, true ],
      [ %w[member owner], nil ] => [ true, false, true, true ],
      [ %w[member owner], %w[participant] ] => [ true, false, true, true ]
    }.each do |(org_roles, project_roles), expected|
      it "allows #{expected} with org roles #{org_roles} and project roles #{project_roles.inspect}" do
        policy = described_class.new(member_with(org_roles:, project_roles:), project)

        expect([ policy.show?, policy.create_entry?, policy.export?, policy.manage? ]).to eq(expected)
      end
    end
  end

  describe "#create? and .manageable" do
    # org roles, project roles => create?, manageable includes the project
    {
      [ %w[member], nil ] => [ false, false ],
      [ %w[member], %w[participant] ] => [ false, false ],
      [ %w[member], %w[owner] ] => [ false, true ],
      [ %w[member owner], nil ] => [ true, true ]
    }.each do |(org_roles, project_roles), (create, manageable)|
      it "allows #{[ create, manageable ]} with org roles #{org_roles} and project roles #{project_roles.inspect}" do
        member = member_with(org_roles:, project_roles:)

        expect(described_class.new(member, Project).create?).to be(create)
        expect(described_class.manageable(member).include?(project)).to be(manageable)
      end
    end

    it "keeps an archived project manageable, so it can be unarchived" do
      project.archive!

      expect(described_class.manageable(member_with(org_roles: %w[member], project_roles: %w[owner]))).to include(project)
      expect(described_class.manageable(member_with(org_roles: %w[member owner], project_roles: nil))).to include(project)
    end

    it "lets an owner of another org manage nothing here" do
      owner = member_with(org_roles: %w[member owner], project_roles: nil, of: create(:org))

      expect(described_class.manageable(owner)).not_to include(project)
    end

    it "lets an archived org owner create nothing" do
      create(:member, :owner, org:)
      owner = member_with(org_roles: %w[member owner], project_roles: nil).tap(&:archive!)

      expect(described_class.new(owner, Project).create?).to be(false)
      expect(described_class.manageable(owner)).to be_empty
    end
  end

  context "with an owner of another org" do
    let(:member) { member_with(org_roles: %w[member owner], project_roles: nil, of: create(:org)) }
    let(:policy) { described_class.new(member, project) }

    it "allows nothing" do
      expect([ policy.show?, policy.create_entry?, policy.export?, policy.manage? ]).to all(be(false))
      expect(described_class.readable(member)).not_to include(project)
      expect(described_class.exportable(member)).not_to include(project)
    end
  end

  context "with a member without roles" do
    # roles are validated, so this is only reachable in memory
    let(:member) { member_with(org_roles: %w[member owner], project_roles: %w[owner]).tap { it.roles = [] } }
    let(:policy) { described_class.new(member, project) }

    it "allows nothing" do
      expect([ policy.show?, policy.create_entry?, policy.export?, policy.manage? ]).to all(be(false))
      expect(described_class.readable(member)).to be_empty
      expect(described_class.exportable(member)).to be_empty
    end
  end

  context "with an archived owner of the org and the project" do
    let(:member) { member_with(org_roles: %w[member owner], project_roles: %w[owner]).tap(&:archive!) }
    let(:policy) { described_class.new(member, project) }

    before { create(:member, :owner, org:) } # the org keeps an owner

    it "allows nothing" do
      expect([ policy.show?, policy.create_entry?, policy.export?, policy.manage? ]).to all(be(false))
      expect(described_class.readable(member)).to be_empty
      expect(described_class.exportable(member)).to be_empty
    end
  end

  context "without a member" do
    let(:policy) { described_class.new(nil, project) }

    it "allows nothing" do
      expect([ policy.show?, policy.create_entry?, policy.export?, policy.manage? ]).to all(be(false))
      expect(described_class.readable(nil)).to be_empty
      expect(described_class.manageable(nil)).to be_empty
      expect(described_class.exportable(nil)).to be_empty
      expect(described_class.new(nil, Project).create?).to be(false)
    end
  end

  describe "#authorize!" do
    let(:member) { member_with(org_roles: %w[member], project_roles: %w[observer]) }

    it "returns the record when allowed" do
      expect(described_class.new(member, project).authorize!(:show?)).to eq(project)
    end

    it "raises when refused" do
      expect { described_class.new(member, project).authorize!(:create_entry?) }
        .to raise_error(ApplicationPolicy::NotAuthorizedError, "ProjectPolicy#create_entry?")
    end
  end
end
