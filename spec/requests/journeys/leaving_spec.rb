require "rails_helper"

# A member leaves and comes back: their access goes, their history stays.
#
RSpec.describe "Deactivating and reactivating a member" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:owner) { create(:member, :owner, org:) }
  let(:leaver) { create(:participant, project:).member }
  let!(:entry) { create(:entry, day: create(:day, project:), member: leaver, log: "Left a handover note") }

  it "locks them out of the org, keeps their entries, and lets them back in" do
    sign_in(owner.user)
    patch deactivate_member_path(org, leaver)
    expect(leaver.reload).to be_archived

    # the owner still reads their entries
    get project_path(org, project)
    expect(response.body).to include("Left a handover note")

    # the leaver signs in, but the org is gone for them
    sign_in(leaver.user)
    get org_path(org)
    expect(response).to have_http_status(:not_found)
    get project_path(org, project)
    expect(response).to have_http_status(:not_found)

    sign_in(owner.user)
    patch reactivate_member_path(org, leaver)

    sign_in(leaver.user)
    get project_path(org, project)
    expect(response).to have_http_status(:ok)
    expect(Entry.find(entry.id).member).to eq(leaver)
  end

  it "keeps the last owner from leaving the org without an owner" do
    sign_in(owner.user)

    patch deactivate_member_path(org, owner)

    expect(owner.reload).not_to be_archived
    expect(flash[:alert]).to include("needs at least one active owner")
  end
end
