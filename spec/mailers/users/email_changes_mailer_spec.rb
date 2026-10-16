require "rails_helper"

RSpec.describe Users::EmailChangesMailer do
  let(:user) { create(:user, email: "anna@example.com").tap { it.update!(unconfirmed_email: "bell@example.com") } }

  describe "#confirm" do
    subject(:mail) { described_class.confirm(user) }

    it "goes to the new address with the confirmation link" do
      link = "https://#{AppConf.done_host}/user/email/confirmations/"

      expect(mail.to).to eq([ "bell@example.com" ])
      expect(mail.subject).to eq("Confirm your new email")
      expect(mail.html_part.body.to_s).to include(link)
      expect(mail.text_part.body.to_s).to include(link)
    end
  end

  describe "#requested" do
    subject(:mail) { described_class.requested(user, "anna@example.com", "bell@example.com") }

    it "goes to the current address with the link to cancel or undo" do
      link = "https://#{AppConf.done_host}/user/email/reverts/"

      expect(mail.to).to eq([ "anna@example.com" ])
      expect(mail.subject).to eq("Your email is about to change")
      expect(mail.text_part.body.to_s).to include("bell@example.com", link)
      expect(mail.html_part.body.to_s).to include("bell@example.com", link)
    end
  end
end
