require "rails_helper"

RSpec.describe Org do
  describe "slug" do
    # /:org_slug looks orgs up without any scope, so their slugs stay globally unique
    it "gets a suffix when another org has the same slug" do
      create(:org, name: "Acme")
      other = create(:org, name: "acme!")

      expect(other.slug).to match(/\Aacme-\d+\z/)
    end

    it "is the URL param" do
      expect(create(:org, name: "Acme Inc").to_param).to eq("acme-inc")
    end

    # the slug is the first segment of every org URL, next to /session, /settings, /up, ...
    it "steers clear of the top-level paths" do
      expect(create(:org, name: "Settings").slug).to match(/\Asettings-\d+\z/)
    end

    it "refuses a reserved word set by hand" do
      org = create(:org)

      expect(org.update(slug: "help")).to be(false)
      expect(org.errors[:slug]).to be_present
    end
  end

  # deleting a whole tenant stays possible on purpose, unlike deleting one member
  it "deletes its members together with their entries when destroyed" do
    participant = create(:participant)
    create(:entry, member: participant.member, day: create(:day, project: participant.project))

    participant.org.destroy!

    expect([ Member.count, Entry.count, Participant.count ]).to all(be_zero)
  end
end
