require "rails_helper"

RSpec.describe User do
  # regression: `has_many :memberships, dependent: :destroy` took the members and,
  #   through them, every entry of the user with it
  describe "destroying" do
    let(:user) { create(:user) }

    it "refuses while the user has memberships and keeps their entries" do
      member = create(:member, user:)
      entry = create(:entry, member:, day: create(:day, project: create(:project, org: member.org)))

      expect { user.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

      expect(Member.exists?(member.id)).to be(true)
      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "is refused by the database too, when callbacks are skipped" do
      create(:member, user:)

      expect { described_class.transaction(requires_new: true) { described_class.where(id: user.id).delete_all } }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "#remember_last_visit!" do
    let(:org) { create(:org) }
    let(:user) { create(:member, org:).user }
    let(:project) { create(:project, org:) }

    it "keeps the project when the same org is opened again" do
      user.remember_last_visit!(org:, project:)
      user.remember_last_visit!(org:)

      expect(user.reload).to have_attributes(last_org: org, last_project: project)
    end

    it "drops the project when another org is opened" do
      user.remember_last_visit!(org:, project:)
      user.remember_last_visit!(org: create(:org))

      expect(user.reload.last_project).to be_nil
    end

    it "drops a project that does not belong to the org" do
      user.remember_last_visit!(org:, project: create(:project))

      expect(user.reload).to have_attributes(last_org: org, last_project: nil)
    end
  end

  describe "validations" do
    it "stores the email stripped and downcased, so it is unique regardless of case" do
      create(:user, email: " Ada@Example.com ")

      expect(described_class.last.email).to eq("ada@example.com")
      expect(build(:user, email: "ADA@example.com")).not_to be_valid
    end

    it "refuses an email that is no address" do
      user = build(:user, email: "ada at example")

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("ada at example is not a valid email format")
    end

    it "takes a name of 3 to 72 characters, stripped" do
      expect(build(:user, name: "  Ada  ").tap(&:validate).name).to eq("Ada")
      expect(build(:user, name: "Al")).not_to be_valid
      expect(build(:user, name: "A" * 73)).not_to be_valid
    end

    it "takes a password of 10 to 72 characters" do
      expect(build(:user, password: "short pass")).to be_valid
      expect(build(:user, password: "too short")).not_to be_valid
      expect(build(:user, password: "x" * 73)).not_to be_valid
    end

    it "keeps the password when an update leaves it out" do
      user = create(:user)

      expect(described_class.find(user.id).update(name: "Renamed")).to be(true)
      expect(user.reload.authenticate("correct horse battery staple")).to eq(user)
    end

    it "requires a password when it is changed on purpose" do
      user = create(:user)
      user.password = nil

      expect(user.valid?(:change_password)).to be(false)
    end

    it "only checks the password against breaches in production" do
      user = build(:user)
      allow(Pwned::Password).to receive(:new).and_wrap_original do |new, *args, **options|
        new.call(*args, **options).tap { allow(it).to receive(:pwned_count).and_return(3) }
      end

      expect(user).to be_valid

      allow(AppConf).to receive(:production_env?).and_return(true)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("might easily be guessed")
    end

    it "refuses an unknown display mode" do
      expect(build(:user, display_mode: "sepia")).not_to be_valid
    end
  end

  describe "#theme" do
    it "is the display mode, or nil to follow the OS" do
      expect(build(:user, display_mode: "dark").theme).to eq("dark")
      expect(build(:user, display_mode: "system").theme).to be_nil
    end
  end

  describe "#end_sessions_except" do
    it "deletes every other session of the user, not those of others" do
      user = create(:user)
      kept = user.sessions.create!
      user.sessions.create!
      others = create(:user).sessions.create!

      user.end_sessions_except(kept)

      expect(Session.all).to contain_exactly(kept, others)
    end
  end

  describe "changing the email" do
    include ActiveSupport::Testing::TimeHelpers

    let(:user) { create(:user, email: "anna@example.com") }

    it "keeps the email until the new address is confirmed" do
      user.update!(unconfirmed_email: " Bell@Example.com ")

      expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: "bell@example.com")
    end

    it "refuses the current email, a taken one and an invalid one" do
      create(:user, email: "taken@example.com")

      expect(user.update(unconfirmed_email: "anna@example.com")).to be(false)
      expect(user.update(unconfirmed_email: "taken@example.com")).to be(false)
      expect(user.update(unconfirmed_email: "no-at-sign")).to be(false)
    end

    describe "#confirm_email_change" do
      it "moves the unconfirmed email to the email" do
        user.update!(unconfirmed_email: "bell@example.com")

        expect(user.confirm_email_change).to be(true)
        expect(user.reload).to have_attributes(email: "bell@example.com", unconfirmed_email: nil)
      end

      it "refuses an address somebody else took meanwhile" do
        user.update!(unconfirmed_email: "bell@example.com")
        create(:user, email: "bell@example.com")

        expect(user.confirm_email_change).to be(false)
        expect(user.reload.email).to eq("anna@example.com")
      end
    end

    describe "the confirmation token" do
      before { user.update!(unconfirmed_email: "bell@example.com") }

      it "finds the user" do
        expect(described_class.find_by_token_for(:email_confirmation, user.generate_token_for(:email_confirmation))).to eq(user)
      end

      it "dies with another unconfirmed email, after confirming and after a day" do
        tokens = Array.new(3) { user.generate_token_for(:email_confirmation) }

        user.update!(unconfirmed_email: "cleo@example.com")
        expect(described_class.find_by_token_for(:email_confirmation, tokens[0])).to be_nil

        user.update!(unconfirmed_email: "bell@example.com")
        user.confirm_email_change
        expect(described_class.find_by_token_for(:email_confirmation, tokens[1])).to be_nil

        user.update!(unconfirmed_email: "dana@example.com")
        token = user.generate_token_for(:email_confirmation)
        travel(User::EMAIL_CONFIRMATION_EXPIRES_IN + 1.minute) do
          expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
        end
      end
    end

    describe "#revert_email_change" do
      before { user.update!(unconfirmed_email: "bell@example.com") }

      def revert
        token = user.email_revert_token
        described_class.find_by_email_revert_token(token)&.then { |found, from, to| found.revert_email_change(from:, to:) }
      end

      it "cancels a pending change" do
        expect(revert).to eq(:cancelled)
        expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: nil)
      end

      it "restores the old email after the change and ends every session" do
        token = user.email_revert_token
        user.sessions.create!
        user.confirm_email_change

        found, from, to = described_class.find_by_email_revert_token(token)

        expect(found.revert_email_change(from:, to:)).to eq(:reverted)
        expect(user.reload).to have_attributes(email: "anna@example.com", unconfirmed_email: nil)
        expect(user.sessions).to be_empty
      end

      it "does nothing once the change is cancelled or replaced by another one" do
        token = user.email_revert_token
        user.update!(unconfirmed_email: "cleo@example.com")

        found, from, to = described_class.find_by_email_revert_token(token)

        expect(found.revert_email_change(from:, to:)).to be_nil
        expect(user.reload.unconfirmed_email).to eq("cleo@example.com")
      end

      it "refuses a token older than a week or a forged one" do
        token = user.email_revert_token

        travel(User::EMAIL_REVERT_EXPIRES_IN + 1.minute) do
          expect(described_class.find_by_email_revert_token(token)).to be_nil
        end
        expect(described_class.find_by_email_revert_token("forged")).to be_nil
      end
    end
  end
end
