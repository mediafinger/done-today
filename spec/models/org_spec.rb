require "rails_helper"

RSpec.describe Org do
  describe "slug" do
    # /:org_slug looks orgs up without any scope, so their slugs stay globally unique
    it "numbers the slug when another org has the same one" do
      create(:org, name: "Acme")

      expect(create(:org, name: "acme!").slug).to eq("acme-2")
      expect(create(:org, name: "ACME").slug).to eq("acme-3")
    end

    it "takes the next number after the highest one" do
      create(:org, name: "Acme")
      create(:org, name: "Acme 7")

      expect(create(:org, name: "acme!").slug).to eq("acme-8")
    end

    # numbers compare as numbers, not as text: 22 < 110 < 005000
    it "takes the next number after the highest one, whatever its length" do
      create(:org, name: "Acme")
      create(:org, name: "Acme 22")
      create(:org, name: "Acme 110")
      create(:org, name: "Acme 005000")

      expect(create(:org, name: "acme!").slug).to eq("acme-5001")
    end

    it "ignores slugs that only start like the name" do
      create(:org, name: "Acme")
      create(:org, name: "Acme 9 Labs")

      expect(create(:org, name: "acme!").slug).to eq("acme-2")
    end

    it "is the URL param" do
      expect(create(:org, name: "Acme Inc").to_param).to eq("acme-inc")
    end

    # the slug is the first segment of every org URL, next to /session, /settings, /up, ...
    it "refuses a name that is a top-level path" do
      org = build(:org, name: "Settings")

      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("can't be used, settings is reserved for the app")
    end

    it "refuses the words reserved for projects too" do
      expect(build(:org, name: "Invitations")).not_to be_valid
    end

    it "refuses the words reserved for future pages" do
      expect(%w[Support FAQ Contact Blog Site].map { build(:org, name: it) }).to all(be_invalid)
    end

    # error pages live at /404.html, /500.html, ...
    it "refuses a name that starts with a number of up to 3 digits" do
      org = build(:org, name: "404 Club")

      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("can't start with a number of up to 3 digits")
      expect(%w[1st 42 500].map { build(:org, name: it) }).to all(be_invalid)
    end

    it "allows a name that starts with a longer number" do
      expect(create(:org, name: "2026 Retro").slug).to eq("2026-retro")
    end

    it "refuses a name without a letter or digit" do
      org = build(:org, name: "!!!")

      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("needs at least one letter or digit")
    end

    it "refuses an empty slug set by hand" do
      org = create(:org)

      expect(org.update(slug: "")).to be(false)
      expect(org.errors[:slug]).to be_present
    end

    # /admin and /dev are areas of the app, not orgs
    it "steers clear of the admin and dev areas" do
      expect { create(:org, name: "Admin") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "refuses a reserved word set by hand" do
      org = create(:org)

      expect(org.update(slug: "help")).to be(false)
      expect(org.errors[:slug]).to be_present
    end

    it "refuses a slug set by hand that starts with a number of up to 3 digits" do
      org = create(:org)

      expect(org.update(slug: "404")).to be(false)
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
