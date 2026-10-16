require "rails_helper"

# The invitee follows the emailed link: /invitations/:token
#
RSpec.describe "Users::Invitations" do
  include ActiveSupport::Testing::TimeHelpers

  let(:org) { create(:org, name: "Acme") }
  let(:invitation) { create(:invitation, org:, email: "ada@example.com", name: "Ada", invited_by: create(:member, :owner, org:)) }
  let(:token) { invitation.generate_token_for(:acceptance) }
  let(:password) { "a long and unusual passphrase" }

  def accept(name: "Ada Lovelace", password: self.password, confirmation: password)
    patch accept_invitation_path(token), params: { user: { name:, password:, password_confirmation: confirmation } }
  end

  def page
    Nokogiri::HTML(response.body)
  end

  describe "GET /invitations/:token" do
    after { travel_back }

    it "asks a new email for name and password" do
      get accept_invitation_path(token)

      expect(response).to have_http_status(:ok)
      expect(page.at_css("h1").text).to eq("Join Acme")
      expect(page.at_css("input[name='user[name]']")["value"]).to eq("Ada")
      expect(page.css("input[type=password]").size).to eq(2)
    end

    # each returns the link to open
    {
      "expired" => -> { token.tap { travel(Invitation::EXPIRES_IN + 1.second) } },
      "used" => -> { token.tap { invitation.update!(accepted_at: Time.current) } },
      "revoked" => -> { token.tap { invitation.destroy! } },
      "tampered" => -> { "#{token}x" }
    }.each do |state, link|
      it "refuses a #{state} link" do
        get accept_invitation_path(instance_exec(&link))

        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq("That invitation link is invalid or has expired, ask for a new one")
      end
    end
  end

  describe "PATCH /invitations/:token" do
    it "creates the user and the member, signs them in and lands in the org" do
      accept

      user = User.find_by!(email: "ada@example.com")
      expect(user).to have_attributes(name: "Ada Lovelace")
      expect(user.authenticate(password)).to be_truthy
      expect(org.members.find_by!(user:)).to have_attributes(role: "member", name: "Ada Lovelace")
      expect(response).to redirect_to(org_path(org))

      follow_redirect!

      expect(response).to have_http_status(:ok)
    end

    it "uses the link up" do
      accept

      expect(invitation.reload).to be_accepted

      delete session_path
      accept(name: "Mallory")

      expect(response).to redirect_to(new_session_path)
      expect(User.where(email: "ada@example.com").count).to eq(1)
    end

    it "refuses an expired link" do
      token

      travel(Invitation::EXPIRES_IN + 1.second) { accept }

      expect(response).to redirect_to(new_session_path)
      expect(User.exists?(email: "ada@example.com")).to be(false)
    end

    it "refuses a tampered link" do
      patch accept_invitation_path("#{token}x"), params: { user: { name: "Ada", password:, password_confirmation: password } }

      expect(response).to redirect_to(new_session_path)
      expect(User.exists?(email: "ada@example.com")).to be(false)
    end

    it "refuses passwords that do not match" do
      accept(confirmation: "something else entirely")

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.text).to include("Password confirmation doesn't match")
      expect(User.exists?(email: "ada@example.com")).to be(false)
      expect(invitation.reload).not_to be_accepted
    end

    it "refuses a short password" do
      accept(password: "short", confirmation: "short")

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: "ada@example.com")).to be(false)
    end

    it "checks the password against Have I Been Pwned" do
      token # the inviting owner's password is not the one checked here
      allow(AppConf).to receive(:production_env?).and_return(true)
      allow(Pwned::Password).to receive(:new).and_return(instance_double(Pwned::Password, pwned_count: 3))

      accept

      expect(Pwned::Password).to have_received(:new).with(password, {})
      expect(response).to have_http_status(:unprocessable_content)
      expect(page.text).to include("Password might easily be guessed")
      expect(User.exists?(email: "ada@example.com")).to be(false)
    end

    it "ignores an email in the params, the invitation decides" do
      patch accept_invitation_path(token), params: { user: { email: "mallory@example.com", name: "Ada", password:, password_confirmation: password } }

      expect(User.exists?(email: "mallory@example.com")).to be(false)
      expect(User.exists?(email: "ada@example.com")).to be(true)
    end

    it "is rate limited" do
      allow(Users::InvitationsController.cache_store).to receive(:increment).and_return(11)

      accept

      expect(User.exists?(email: "ada@example.com")).to be(false)
      expect(flash[:alert]).to eq("Try again later.")
    end
  end

  describe "an email that already has an account" do
    let!(:ada) { create(:user, email: "ada@example.com", name: "Ada L.") }

    it "asks them to sign in, then comes back to the invitation" do
      get accept_invitation_path(token)

      expect(response).to redirect_to(new_session_path(email: "ada@example.com"))
      expect(flash[:notice]).to eq("Sign in as ada@example.com to join Acme")

      sign_in(ada)

      expect(response).to redirect_to(accept_invitation_url(token))
    end

    it "offers to join once signed in, without asking for a password" do
      sign_in(ada)

      get accept_invitation_path(token)

      expect(response).to have_http_status(:ok)
      expect(page.at_css("form[action='#{accept_invitation_path(token)}'] [type=submit]")["value"]).to eq("Join Acme")
      expect(page.css("input[type=password]")).to be_empty
    end

    it "says who invited them" do
      sign_in(ada)

      get accept_invitation_path(token)

      expect(page.at_css("main p").text.squish).to eq("#{invitation.invited_by.name} invited you, ada@example.com, as member.")
    end

    it "adds the member once signed in and lands in the org" do
      other = create(:member, user: ada)
      sign_in(ada)

      patch accept_invitation_path(token)

      expect(org.members.find_by!(user: ada)).to have_attributes(role: "member", name: "Ada L.")
      expect(invitation.reload).to be_accepted
      expect(other.reload).not_to be_archived
      expect(response).to redirect_to(org_path(org))
    end

    it "never sets the password of the existing account" do
      accept

      expect(response).to redirect_to(new_session_path(email: "ada@example.com"))
      expect(ada.reload.authenticate(password)).to be(false)
      expect(ada.name).to eq("Ada L.")
      expect(org.members.exists?(user: ada)).to be(false)
      expect(invitation.reload).not_to be_accepted
    end

    it "ignores a password sent along by the signed-in invitee" do
      sign_in(ada)

      accept

      expect(ada.reload.authenticate(password)).to be(false)
      expect(org.members.exists?(user: ada)).to be(true)
    end

    it "reactivates their archived member, with the invited role" do
      member = create(:member, org:, user: ada, role: "member")
      create(:entry, member:, day: create(:day, project: create(:project, org:)))
      member.archive!
      invitation.update!(role: "owner")
      sign_in(ada)

      expect { patch accept_invitation_path(token) }.not_to change(Member, :count)

      expect(member.reload).to have_attributes(archived_at: nil, role: "owner")
      expect(member.entries.count).to eq(1)
      expect(response).to redirect_to(org_path(org))
    end

    it "leaves an active member as it is, who joined after the invitation was sent" do
      token
      member = create(:member, :owner, org:, user: ada)
      sign_in(ada)

      expect { patch accept_invitation_path(token) }.not_to change(Member, :count)

      expect(member.reload.role).to eq("owner")
      expect(invitation.reload).to be_accepted
      expect(response).to redirect_to(org_path(org))
    end
  end

  describe "while signed in as someone else" do
    let(:someone) { create(:user, email: "someone@example.com") }

    before { sign_in(someone) }

    it "asks to sign out first" do
      get accept_invitation_path(token)

      expect(response).to have_http_status(:forbidden)
      expect(page.text).to include("ada@example.com", "someone@example.com")
      expect(page.at_css("form[action='#{session_path}']")).to be_present
    end

    it "creates nobody" do
      accept

      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(email: "ada@example.com")).to be(false)
      expect(org.members.exists?(user: someone)).to be(false)
    end
  end
end
