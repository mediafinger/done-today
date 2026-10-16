require "rails_helper"

# Who may invite is covered by spec/requests/authorization_matrix_spec.rb,
#   this is what an org owner sends, resends and revokes.
#
RSpec.describe "Orgs::Invitations" do
  include ActiveJob::TestHelper

  let(:org) { create(:org, name: "Acme") }
  let(:owner) { create(:member, :owner, org:, name: "Olivia") }

  def invite(email, roles: %w[member], name: nil)
    post invitations_path(org), params: { invitation: { email:, name:, roles: [ "", *roles ] } }
  end

  before { sign_in(owner.user) }

  describe "POST /:org/invitations" do
    it "stores the invitation and mails the link" do
      expect { invite("Ada@Example.com", name: "Ada") }.to have_enqueued_mail(InvitationsMailer, :invite)

      expect(org.invitations.sole).to have_attributes(email: "ada@example.com", name: "Ada", roles: %w[member], invited_by: owner)
      expect(response).to redirect_to(members_path(org))
      expect(flash[:notice]).to eq("Invited ada@example.com")
    end

    it "invites as owner" do
      invite("ada@example.com", roles: %w[member owner])

      expect(org.invitations.sole.roles).to eq(%w[member owner])
    end

    it "refuses an email that is already a member" do
      create(:member, org:, user: create(:user, email: "ada@example.com"))

      expect { invite("ada@example.com") }.not_to have_enqueued_mail(InvitationsMailer, :invite)

      expect(org.invitations).to be_empty
      expect(flash[:alert]).to eq("ada@example.com is already a member")
    end

    it "invites an account of another org" do
      create(:member, user: create(:user, email: "ada@example.com"))

      expect { invite("ada@example.com") }.to have_enqueued_mail(InvitationsMailer, :invite)
    end

    it "invites a deactivated member back" do
      create(:member, org:, user: create(:user, email: "ada@example.com")).archive!

      expect { invite("ada@example.com") }.to have_enqueued_mail(InvitationsMailer, :invite)
    end

    it "refuses an invalid email" do
      invite("not an email")

      expect(org.invitations).to be_empty
      expect(flash[:alert]).to include("not a valid email")
    end

    it "sends a pending invitation again with the new roles, the old link stops working" do
      invitation = create(:invitation, org:, email: "ada@example.com", sent_at: 1.day.ago)
      old_token = invitation.generate_token_for(:acceptance)

      expect { invite("ada@example.com", roles: %w[member owner]) }.to have_enqueued_mail(InvitationsMailer, :invite)

      expect(invitation.reload.roles).to eq(%w[member owner])
      expect(Invitation.find_by_token_for(:acceptance, old_token)).to be_nil
      expect(org.invitations.count).to eq(1)
    end

    it "is rate limited" do
      allow(Orgs::InvitationsController.cache_store).to receive(:increment).and_return(21)

      expect { invite("ada@example.com") }.not_to have_enqueued_mail(InvitationsMailer, :invite)

      expect(response).to redirect_to(members_path(org))
      expect(flash[:alert]).to eq("Too many invitations, try again later")
    end
  end

  describe "PATCH /:org/invitations/:id/resend" do
    it "mails a new link, the old one stops working" do
      invitation = create(:invitation, org:, sent_at: 8.days.ago)
      old_token = invitation.generate_token_for(:acceptance)

      expect { patch resend_invitation_path(org, invitation) }.to have_enqueued_mail(InvitationsMailer, :invite)

      expect(invitation.reload).not_to be_expired
      expect(Invitation.find_by_token_for(:acceptance, old_token)).to be_nil
    end
  end

  describe "DELETE /:org/invitations/:id" do
    it "revokes the invitation, its link stops working" do
      invitation = create(:invitation, org:)
      token = invitation.generate_token_for(:acceptance)

      delete invitation_path(org, invitation)

      expect(Invitation.find_by_token_for(:acceptance, token)).to be_nil
      expect(flash[:notice]).to eq("Revoked the invitation of #{invitation.email}")
    end

    it "does not find another org's invitation" do
      invitation = create(:invitation)

      delete invitation_path(org, invitation)

      expect(response).to have_http_status(:not_found)
      expect(invitation.reload).to be_present
    end
  end

  describe "the members page" do
    it "has the invite form" do
      get members_path(org)

      form = Nokogiri::HTML(response.body).at_css("form#new-invitation")
      expect(form["action"]).to eq(invitations_path(org))
      expect(form.css("input[type=checkbox][checked]").pluck("value")).to eq(%w[member])
    end

    it "lists the pending invitations, expired ones marked" do
      create(:invitation, org:, email: "ada@example.com")
      create(:invitation, org:, email: "bob@example.com", sent_at: 8.days.ago)
      create(:invitation, org:, email: "cy@example.com", accepted_at: Time.current)

      get members_path(org)

      pending = Nokogiri::HTML(response.body).at_css("#pending-invitations").text
      expect(pending).to include("ada@example.com", "bob@example.com", "expired")
      expect(pending).not_to include("cy@example.com")
    end
  end
end
