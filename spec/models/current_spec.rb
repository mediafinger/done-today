require "rails_helper"

RSpec.describe Current do
  after { described_class.reset }

  it "keeps the ids in step with the records" do
    org = create(:org)
    project = create(:project, org:)
    member = create(:member, org:)

    described_class.user = member.user
    described_class.org = org
    described_class.project = project
    described_class.member = member

    expect(described_class.attributes.values_at(:user_id, :org_id, :project_id, :member_id))
      .to eq([ member.user.id, org.id, project.id, member.id ])
  end

  it "clears an id together with its record" do
    described_class.org = create(:org)
    described_class.org = nil

    expect(described_class.org_id).to be_nil
  end
end
