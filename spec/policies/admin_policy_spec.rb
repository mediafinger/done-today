require "rails_helper"

RSpec.describe AdminPolicy do
  def may_access?(user)
    described_class.new(:admin, user:).apply(:access?)
  end

  it "lets admins into the admin area" do
    expect(may_access?(create(:user, :admin))).to be(true)
  end

  it "keeps everyone else out" do
    expect(may_access?(create(:user))).to be(false)
  end

  it "keeps a missing user out" do
    expect(may_access?(nil)).to be(false)
  end
end
