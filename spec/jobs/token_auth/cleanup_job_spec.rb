require "rails_helper"

RSpec.describe TokenAuth::CleanupJob do
  def application(registered:)
    Doorkeeper::Application.create!(name: "AI app", redirect_uri: "https://ai.example/callback", confidential: false, created_at: registered)
  end

  it "runs every hour, in development too (config/recurring.yml)" do
    %w[production development].each do |env|
      expect(Rails.application.config_for(:recurring, env:)[:token_auth_cleanup])
        .to include(class: described_class.name, schedule: "every hour")
    end
  end

  describe "registered apps" do
    it "deletes those nobody authorized within a day" do
      abandoned = application(registered: 25.hours.ago)
      fresh = application(registered: 1.hour.ago)

      described_class.perform_now

      expect(Doorkeeper::Application.all).to contain_exactly(fresh)
      expect { abandoned.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps those a user authorized, also after the connection was revoked" do
      app = application(registered: 2.days.ago)
      create(:token_auth_connection, oauth_application: app, revoked_at: 1.day.ago)

      described_class.perform_now

      expect(Doorkeeper::Application.all).to contain_exactly(app)
    end
  end

  describe "connected apps" do
    let(:app) { application(registered: 1.year.ago) }

    it "revokes those unused for 90 days, with their tokens" do
      unused = create(:token_auth_connection, oauth_application: app, last_used_at: 91.days.ago)
      token = unused.access_tokens.create!(resource_owner_id: unused.user_id, application: app, expires_in: 3600)

      described_class.perform_now

      expect(unused.reload).to be_revoked
      expect(token.reload).to be_revoked
    end

    it "counts from the connection when it was never used" do
      never_used = create(:token_auth_connection, oauth_application: app, created_at: 91.days.ago)
      recent = create(:token_auth_connection, oauth_application: app)

      described_class.perform_now

      expect(never_used.reload).to be_revoked
      expect(recent.reload).not_to be_revoked
    end

    it "keeps personal access tokens, they expire on their own" do
      personal = create(:token_auth_connection, last_used_at: 1.year.ago)

      described_class.perform_now

      expect(personal.reload).not_to be_revoked
    end
  end
end
