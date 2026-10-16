require "rails_helper"

RSpec.describe "The org switcher" do
  let(:home) { create(:member, org: create(:org, name: "Home")) }
  # guests always take part in a project
  let(:client) do
    project = create(:project, org: create(:org, name: "Client"))
    create(:participant, project:, member: create(:member, :guest, user: home.user, org: project.org))
  end

  def org_entries
    Nokogiri::HTML(response.body).css("nav details li b").map { it.text.squish }
  end

  it "marks the orgs where the user is a guest" do
    client
    sign_in(home.user)

    get org_path(home.org)

    expect(org_entries).to contain_exactly("Client (guest)", "Home")
  end
end
