require "rails_helper"

# Nothing is selected after signing in, so / offers the user's orgs and projects.
#
RSpec.describe "GET /" do
  let(:participant) { create(:participant) }
  let(:org) { participant.org }
  let(:project) { participant.project }

  def links
    Nokogiri::HTML(response.body).css("main a").pluck("href")
  end

  it "links the orgs and the projects the user takes part in" do
    sign_in(participant.member.user)

    get root_path

    expect(links).to include(org_path(org), project_path(org, project))
  end

  it "leaves out the orgs the user was deactivated in" do
    participant.member.archive!
    sign_in(participant.member.user)

    get root_path

    expect(links).not_to include(org_path(org))
  end

  it "says so when the user belongs to no org" do
    sign_in(create(:user))

    get root_path

    expect(response.body).to include("not a member of any org yet")
  end
end
