require "rails_helper"

RSpec.describe "Users::Passwords" do
  describe "POST /passwords" do
    it "enqueues the reset mail for a known address" do
      user = create(:user)

      expect { post passwords_path, params: { email: user.email } }
        .to have_enqueued_mail(Users::PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "enqueues nothing for an unknown address" do
      expect { post passwords_path, params: { email: "nobody@example.com" } }
        .not_to have_enqueued_mail

      expect(response).to redirect_to(new_session_path)
    end
  end
end
