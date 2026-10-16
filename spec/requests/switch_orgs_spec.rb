require "rails_helper"

RSpec.describe "SwitchOrgs" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "turns away a user who is not a member of the org, instead of raising" do
    get open_path(create(:project).org.slug)

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("You are not a member of this org")
  end

  it "answers an unknown org the same way, so slugs cannot be probed" do
    get open_path("no-such-org")

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("You are not a member of this org")
  end

  it "opens the org and a project the member participates in" do
    project = create(:project)
    participant = create(:participant, project:, member: create(:member, org: project.org, user:))

    get open_path(participant.org.slug, participant.project.slug)

    expect(response).to redirect_to(project_path(participant.project.slug))
  end
end
