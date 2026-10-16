require "rails_helper"

RSpec.describe AdminConstraint do
  def request_signed_in_as(user)
    ActionDispatch::TestRequest.create.tap do |request|
      request.cookie_jar.signed[:session_id] = user.sessions.create!.id if user
    end
  end

  describe ".matches?" do
    it "is true for the session of an admin" do
      expect(described_class.matches?(request_signed_in_as(create(:user, :admin)))).to be(true)
    end

    it "is false for the session of a user who is no admin" do
      expect(described_class.matches?(request_signed_in_as(create(:user)))).to be(false)
    end

    it "is false without a session" do
      expect(described_class.matches?(request_signed_in_as(nil))).to be(false)
    end

    it "is false for a session that no longer exists" do
      request = request_signed_in_as(create(:user, :admin))
      Session.delete_all

      expect(described_class.matches?(request)).to be(false)
    end
  end
end
