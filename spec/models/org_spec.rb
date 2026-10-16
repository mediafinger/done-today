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
  it "deletes its members and projects together with their entries when destroyed" do
    participant = create(:participant)
    create(:entry, member: participant.member, day: create(:day, project: participant.project))

    participant.org.destroy!

    expect([ Member.count, Entry.count, Participant.count, Day.count, Project.count ]).to all(be_zero)
  end

  # regression: `dependent: :destroy` raised ActiveRecord::ReadOnlyRecord on the read-only histories
  it "deletes its record histories when destroyed" do
    history = create(:record_history)

    history.org.destroy!

    expect(RecordHistory.count).to be_zero
  end

  describe "validations" do
    it "needs a name, unique across orgs" do
      create(:org, name: "Acme")

      expect(build(:org, name: "")).not_to be_valid
      expect(build(:org, name: "Acme")).not_to be_valid
    end
  end

  it "derives the slug from the name" do
    expect(create(:org, name: "Acme & Sons GmbH").slug).to eq("acme-sons-gmbh")
  end

  it "keeps the slug when renamed, so links keep working" do
    org = create(:org, name: "Acme")

    org.update!(name: "Acme Corp")

    expect(org.reload.slug).to eq("acme")
  end
end
