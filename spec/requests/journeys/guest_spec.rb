require "rails_helper"

# A project lead brings in an external for one project, and lets them go again.
#
RSpec.describe "Working with a guest" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:, name: "Client site") }
  let(:lead) { create(:participant, :lead, project:).member }
  let(:password) { "correct horse battery staple" }

  before { create(:project, org:, name: "Internal tools") }

  it "lets the guest see and log only their project, until they are removed from it" do
    sign_in(lead.user)
    post guest_invitations_path(org, project), params: { invitation: { email: "gus@example.com", name: "Gus", project_role: "participant" } }
    invitation = Invitation.pending.find_by!(email: "gus@example.com")

    delete session_path
    patch accept_invitation_path(invitation.generate_token_for(:acceptance)),
      params: { user: { name: "Gus", password:, password_confirmation: password } }
    expect(response).to redirect_to(project_path(org, project))
    guest = org.members.guests.sole

    # only their project, no member list
    get org_path(org)
    expect(response.body).to include("Client site")
    expect(response.body).not_to include("Internal tools")
    get members_path(org)
    expect(response).to have_http_status(:forbidden)

    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Reviewed the mockups" } }
    expect(guest.entries.sole.log).to eq("Reviewed the mockups")

    # removed from their only project, they are deactivated, their entry stays
    sign_in(lead.user)
    delete participant_path(org, project, project.participants.find_by!(member: guest))
    expect(guest.reload).to be_archived
    expect(Entry.where(member: guest).count).to eq(1)

    sign_in(guest.user)
    get project_path(org, project)
    expect(response).to have_http_status(:not_found)
  end
end
