require "rails_helper"

RSpec.describe PasswordsMailer do
  describe "reset" do
    let(:user) { create(:user, email: "resetme@example.com") }
    let(:mail) { described_class.reset(user) }

    it "renders the headers" do
      pending "Fix template location bug (templates are in app/views/users/passwords_mailer/ instead of app/views/passwords_mailer/)"
      expect(mail.subject).to eq("Reset your password")
      expect(mail.to).to eq(["resetme@example.com"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      pending "Fix template location bug (templates are in app/views/users/passwords_mailer/ instead of app/views/passwords_mailer/)"
      expect(mail.body.encoded).to include("password")
      expect(mail.body.encoded).to include(user.password_reset_token)
    end
  end
end
