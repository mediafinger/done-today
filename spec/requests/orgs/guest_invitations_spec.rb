require "rails_helper"

# Org owners and project owners invite guests (externals) to a project.
#   Who may do what is covered by spec/requests/authorization_matrix_spec.rb.
#
RSpec.describe "Guest invitations" do
  let(:org) { create(:org, name: "Acme") }
  let(:project) { create(:project, org:, name: "Website") }
  let(:project_owner) { create(:participant, :owner, project:, member: create(:member, org:, name: "Pat")).member }
  let(:owner) { create(:member, :owner, org:) }

  def page
    Nokogiri::HTML(response.body)
  end

  def invite_guest(email, project_role: "participant")
    post guest_invitations_path(org, project), params: { invitation: { email:, name: "Gus", project_role: } }
  end

  describe "POST /:org/:project/guest_invitations" do
    before { sign_in(project_owner.user) }

    it "stores a guest invitation to the project and mails the link" do
      expect { invite_guest("Gus@Example.com", project_role: "observer") }.to have_enqueued_mail(InvitationsMailer, :invite)

      expect(org.invitations.sole).to have_attributes(
        email: "gus@example.com", name: "Gus", role: "guest", project:, project_role: "observer", invited_by: project_owner
      )
      expect(response).to redirect_to(edit_project_path(org, project))
      expect(flash[:notice]).to eq("Invited gus@example.com")
    end

    it "refuses the project role owner" do
      invite_guest("gus@example.com", project_role: "owner")

      expect(flash[:alert]).to be_present
      expect(org.invitations).to be_empty
    end

    # an org owner decides what somebody invited to the org becomes
    it "leaves a pending invitation to the org alone" do
      create(:invitation, org:, email: "gus@example.com")

      invite_guest("gus@example.com")

      expect(flash[:alert]).to eq("gus@example.com is already invited")
      expect(org.invitations.sole.role).to eq("member")
    end

    it "lists the pending guest invitations of the project, to resend or revoke them" do
      invitation = create(:invitation, :guest, org:, project:, email: "gus@example.com")
      create(:invitation, :guest, org:, email: "elsewhere@example.com")

      get edit_project_path(org, project)

      expect(page.css("#guest-invitations tbody tr").map { it.at_css("td").text }).to eq([ "gus@example.com" ])

      patch resend_guest_invitation_path(org, project, invitation)
      expect(flash[:notice]).to eq("Sent the invitation to gus@example.com again")

      delete guest_invitation_path(org, project, invitation)
      expect(project.invitations).to be_empty
    end

    it "turns away an invitation of another project" do
      invitation = create(:invitation, :guest, org:, email: "elsewhere@example.com")

      delete guest_invitation_path(org, project, invitation)

      expect(response).to have_http_status(:not_found)
      expect(invitation.reload).to be_present
    end
  end

  describe "POST /:org/invitations as guest" do
    before { sign_in(owner.user) }

    it "lets an org owner invite a guest to a project" do
      post invitations_path(org), params: {
        invitation: { email: "gus@example.com", role: "guest", project_id: project.id, project_role: "participant" }
      }

      expect(org.invitations.sole).to have_attributes(role: "guest", project:, project_role: "participant")
    end

    it "drops the project of an invitation as member" do
      post invitations_path(org), params: {
        invitation: { email: "gus@example.com", role: "member", project_id: project.id, project_role: "participant" }
      }

      expect(org.invitations.sole).to have_attributes(role: "member", project: nil, project_role: nil)
    end

    it "shows the project of pending guest invitations" do
      create(:invitation, :guest, org:, project:, email: "gus@example.com")

      get members_path(org)

      expect(page.at_css("#pending-invitations tbody tr").text).to include("guest in Website (participant)")
    end
  end

  describe "accepting" do
    let(:invitation) { create(:invitation, :guest, org:, project:, email: "gus@example.com") }

    it "lands a new guest in their project" do
      patch accept_invitation_path(invitation.generate_token_for(:acceptance)), params: {
        user: { name: "Gus", password: "a long and unusual passphrase", password_confirmation: "a long and unusual passphrase" }
      }

      expect(org.members.sole).to have_attributes(role: "guest", projects: [ project ])
      expect(response).to redirect_to(project_path(org, project))
    end

    it "names the project on the join page" do
      sign_in(create(:user, email: "gus@example.com"))

      get accept_invitation_path(invitation.generate_token_for(:acceptance))

      expect(page.at_css("main p").text.squish).to include("as guest in Website")
    end
  end
end
