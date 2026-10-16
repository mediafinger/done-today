require "rails_helper"

RSpec.describe DevConstraint do
  describe ".matches?" do
    it "is true in development" do
      allow(Rails.env).to receive(:development?).and_return(true)

      expect(described_class.matches?(ActionDispatch::TestRequest.create)).to be(true)
    end

    # development-only routes may need gems or config that tests don't load
    it "is false in test" do
      expect(described_class.matches?).to be(false)
    end
  end
end
