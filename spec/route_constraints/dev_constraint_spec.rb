require "rails_helper"

RSpec.describe DevConstraint do
  describe ".matches?" do
    it "is true in development and test" do
      expect(described_class.matches?).to be(true)
    end

    it "is false in any other environment" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(described_class.matches?(ActionDispatch::TestRequest.create)).to be(false)
    end
  end
end
