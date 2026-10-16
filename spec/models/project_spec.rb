require "rails_helper"

RSpec.describe Project do
  describe "slug" do
    let(:org) { create(:org) }

    it "is the parameterized name" do
      expect(create(:project, org:, name: "Website").slug).to eq("website")
    end

    it "lets two orgs each have the same slug" do
      ours = create(:project, org:, name: "Website")
      theirs = create(:project, org: create(:org), name: "Website")

      expect([ ours.slug, theirs.slug ]).to eq(%w[website website])
    end

    it "gets a suffix when the slug is taken within the same org" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "website!")

      expect(other.slug).to match(/\Awebsite-\d+\z/)
    end

    it "is unique per org in the database" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "Shop")

      expect { other.update_column(:slug, "website") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "is validated per org" do
      create(:project, org:, name: "Website")
      other = create(:project, org:, name: "Shop")
      other.slug = "website"

      expect(other).not_to be_valid
      expect(other.errors[:slug]).to be_present
    end

    it "is the URL param" do
      expect(create(:project, name: "Web Site").to_param).to eq("web-site")
    end

    # /:org/members and /:org/settings sit where /:org/:project would
    it "steers clear of the org-level paths" do
      expect(create(:project, name: "Members").slug).to match(/\Amembers-\d+\z/)
    end

    it "refuses a reserved word set by hand" do
      project = create(:project)

      expect(project.update(slug: "settings")).to be(false)
      expect(project.errors[:slug]).to be_present
    end

    # the slug is in every URL of the project, bookmarks and shared links keep working
    it "stays when the project is renamed" do
      project = create(:project, name: "Website")

      project.update!(name: "Shop")

      expect(project.reload.slug).to eq("website")
    end
  end

  describe "#archive! and #unarchive!" do
    let(:project) { create(:project) }

    it "moves the project between the active and the archived scope" do
      project.archive!

      expect(project.reload).to be_archived
      expect(described_class.active).not_to include(project)
      expect(described_class.archived).to include(project)

      project.unarchive!

      expect(project.reload).not_to be_archived
      expect(described_class.active).to include(project)
    end

    it "keeps the first archived_at when archived twice" do
      project.update!(archived_at: 2.days.ago.round)
      first = project.archived_at

      project.archive!

      expect(project.reload.archived_at).to eq(first)
    end

    it "keeps days, entries and participants" do
      participant = create(:participant, project:)
      entry = create(:entry, day: create(:day, project:), member: participant.member)

      project.archive!

      expect(Entry.exists?(entry.id)).to be(true)
      expect(Participant.exists?(participant.id)).to be(true)
    end
  end

  # regression: `has_many :days, dependent: :destroy` and `Day has_many :entries, dependent: :destroy`
  #   deleted a project's whole history
  describe "destroying" do
    let(:project) { create(:project) }
    let!(:entry) { create(:entry, day: create(:day, project:), member: create(:participant, project:).member) }

    it "refuses while the project has days and keeps their entries" do
      expect { project.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

      expect(described_class.exists?(project.id)).to be(true)
      expect(Day.exists?(entry.day_id)).to be(true)
      expect(Entry.exists?(entry.id)).to be(true)
      expect(project.participants.count).to eq(1)
    end

    it "is refused by the database too, when callbacks are skipped" do
      expect { described_class.transaction(requires_new: true) { described_class.where(id: project.id).delete_all } }
        .to raise_error(ActiveRecord::InvalidForeignKey)

      expect(Entry.exists?(entry.id)).to be(true)
    end

    it "works for a project without days, and takes its participants along" do
      other = create(:participant).project

      expect { other.destroy! }.to change(described_class, :count).by(-1).and change(Participant, :count).by(-1)
    end
  end
end
