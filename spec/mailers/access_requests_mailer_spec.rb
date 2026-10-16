require "rails_helper"

RSpec.describe AccessRequestsMailer do
  let(:org) { create(:org, name: "Acme") }
  let(:project) { create(:project, org:, name: "Website") }
  let(:lead) { create(:participant, :lead, project:, member: create(:member, org:, name: "Pat", user: create(:user, email: "pat@example.com"))).member }
  let(:access_request) { create(:access_request, project:, member: create(:member, org:, name: "Carl"), message: "Need the invoices") }

  describe "#requested" do
    subject(:mail) { described_class.requested(access_request, lead) }

    it "goes to the lead" do
      expect(mail.to).to eq([ "pat@example.com" ])
      expect(mail.subject).to eq("Carl asks to join Website")
    end

    it "quotes the message and links to the project's participants" do
      [ mail.html_part, mail.text_part ].each do |part|
        body = part.body.decoded

        expect(body).to include("Carl", "Website", "Acme", "Need the invoices")
        expect(body).to include(Rails.application.routes.url_helpers.edit_project_path(org, project))
      end
    end
  end
end
