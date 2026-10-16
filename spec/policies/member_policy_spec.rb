require "rails_helper"

RSpec.describe MemberPolicy do
  let(:org) { create(:org) }
  let(:colleague) { create(:member, org:) }

  # org roles => index?, manage? (a colleague)
  {
    %w[member] => [ false, false ],
    %w[member owner] => [ true, true ],
    %w[owner] => [ true, true ]
  }.each do |org_roles, (index, manage)|
    context "with org roles #{org_roles}" do
      let(:member) { create(:member, org:, roles: org_roles) }

      it { expect(described_class.new(member, Member).index?).to be(index) }
      it { expect(described_class.new(member, colleague).manage?).to be(manage) }
      it { expect(described_class.new(member, Member).invite?).to be(index) }
    end
  end

  it "lets an owner manage themselves" do
    owner = create(:member, :owner, org:)

    expect(described_class.new(owner, owner).manage?).to be(true)
  end

  it "does not let an owner manage the members of another org" do
    owner = create(:member, :owner)

    expect(described_class.new(owner, colleague).manage?).to be(false)
  end

  it "does not let an archived owner do anything" do
    create(:member, :owner, org:)
    owner = create(:member, :owner, org:).tap(&:archive!)

    expect([
      described_class.new(owner, Member).index?, described_class.new(owner, colleague).manage?,
      described_class.new(owner, Member).invite?
    ]).to all(be(false))
  end

  it "allows nothing without a member" do
    expect([ described_class.new(nil, Member).index?, described_class.new(nil, colleague).manage? ]).to all(be(false))
  end

  it "lets an owner manage a deactivated member, to reactivate them" do
    owner = create(:member, :owner, org:)

    expect(described_class.new(owner, colleague.tap(&:archive!)).manage?).to be(true)
  end

  it "lets nobody invite without a member" do
    expect(described_class.new(nil, Member).invite?).to be(false)
  end
end
