require "rails_helper"


RSpec.describe Users::PasswordsMailer do
  describe "#reset" do
    subject(:mail) { described_class.reset(user) }

    let(:user) { create(:user) }

    it "is addressed to the user" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to eq("Reset your password")
    end

    # regression: the templates lived in users/passwords_mailer, rendering raised MissingTemplate
    it "renders the reset link in both parts" do
      expect(mail.html_part.body.to_s).to include("/passwords/")
      expect(mail.text_part.body.to_s).to include("/passwords/")
    end

    it "is sent from DEFAULT_EMAIL_SENDER" do
      allow(AppConf).to receive(:default_email_sender).and_return("Done <noreply@mediafinger.eu>")

      expect(mail.from).to eq([ "noreply@mediafinger.eu" ])
      expect(mail[:from].display_names).to eq([ "Done" ])
    end

    it "links to DONE_HOST over https" do
      link = "https://#{AppConf.done_host}/passwords/"

      expect(mail.html_part.body.to_s).to include(link)
      expect(mail.text_part.body.to_s).to include(link)
    end
  end
end
