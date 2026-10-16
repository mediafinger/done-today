require "rails_helper"

RSpec.describe ProjectPolicy do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:record) { project }
  let(:member) { nil }
  let(:context) { { member: } }

  def member_with(org_roles:, project_roles:, of: org)
    create(:member, org: of, roles: org_roles).tap do |member|
      create(:participant, project:, member:, roles: project_roles) if project_roles
    end
  end

  # show?, create_entry?, export?, manage?
  def allowed
    %i[show? create_entry? export? manage?].map { policy.apply(it) }
  end

  def scope(name = :default)
    described_class.new(member:).apply_scope(Project.all, type: :active_record_relation, name:)
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
      context "with org roles #{org_roles} and project roles #{project_roles.inspect}" do
        let(:member) { member_with(org_roles:, project_roles:) }

        it("allows #{expected}") { expect(allowed).to eq(expected) }

        it "scopes it as manageable exactly when it may be managed, so it can be unarchived" do
          expect(scope(:manageable).include?(project)).to be(expected.last)
        end
      end
    end
  end

  describe "create? and the manageable scope" do
    let(:record) { Project }

    # org roles, project roles => create?, manageable includes the project
    {
      [ %w[member], nil ] => [ false, false ],
      [ %w[member], %w[participant] ] => [ false, false ],
      [ %w[member], %w[owner] ] => [ false, true ],
      [ %w[member owner], nil ] => [ true, true ]
    }.each do |(org_roles, project_roles), (create, manageable)|
      context "with org roles #{org_roles} and project roles #{project_roles.inspect}" do
        let(:member) { member_with(org_roles:, project_roles:) }

        it("allows #{[ create, manageable ]}") do
          expect([ policy.apply(:create?), scope(:manageable).include?(project) ]).to eq([ create, manageable ])
        end
      end
    end

    context "with an owner of another org" do
      let(:member) { member_with(org_roles: %w[member owner], project_roles: nil, of: create(:org)) }

      it { expect(scope(:manageable)).not_to include(project) }
    end

    context "with an archived org owner" do
      let(:member) { member_with(org_roles: %w[member owner], project_roles: nil).tap(&:archive!) }

      before { create(:member, :owner, org:) } # the org keeps an owner

      it "lets them create and manage nothing" do
        expect(policy.apply(:create?)).to be(false)
        expect(scope(:manageable)).to be_empty
      end
    end
  end

  context "with an owner of another org" do
    let(:member) { member_with(org_roles: %w[member owner], project_roles: nil, of: create(:org)) }

    it "allows nothing" do
      expect(allowed).to all(be(false))
      expect(scope).not_to include(project)
      expect(scope(:exportable)).not_to include(project)
    end
  end

  context "with an archived owner of the org and the project" do
    let(:member) { member_with(org_roles: %w[member owner], project_roles: %w[owner]).tap(&:archive!) }

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
