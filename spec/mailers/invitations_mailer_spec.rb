require "rails_helper"

RSpec.describe InvitationsMailer do
  let(:org) { create(:org, name: "Acme") }
  let(:invitation) { create(:invitation, org:, email: "ada@example.com", invited_by: create(:member, :owner, org:, name: "Olivia")) }

  describe "#invite" do
    subject(:mail) { described_class.invite(invitation) }

    it "goes to the invited email" do
      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.subject).to eq("Join Acme on Done today")
    end

    it "says who invited them, and links to a token that finds the invitation" do
      [ mail.html_part, mail.text_part ].each do |part|
        body = part.body.decoded
        token = body[%r{/invitations/([^"\s<]+)}, 1]

        expect(body).to include("Olivia", "Acme")
        expect(Invitation.find_by_token_for(:acceptance, CGI.unescape(token))).to eq(invitation)
      end
    end
  end
end
