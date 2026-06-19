require "rails_helper"

RSpec.describe Session, type: :model do
  describe "associations" do
    it "has expected associations" do
      org_assoc = Session.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)
      expect(org_assoc.options[:optional]).to be true

      proj_assoc = Session.reflect_on_association(:project)
      expect(proj_assoc.macro).to eq(:belongs_to)
      expect(proj_assoc.options[:optional]).to be true

      user_assoc = Session.reflect_on_association(:user)
      expect(user_assoc.macro).to eq(:belongs_to)
    end
  end
end
