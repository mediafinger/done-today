require "rails_helper"

RSpec.describe Org do
  describe "slug" do
    # /open/:slug_org looks orgs up without any scope, so their slugs stay globally unique
    it "gets a suffix when another org has the same slug" do
      create(:org, name: "Acme")
      other = create(:org, name: "acme!")

      expect(other.slug).to match(/\Aacme-\d+\z/)
    end
  end
end
