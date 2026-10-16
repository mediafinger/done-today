require "rails_helper"

# An archived member keeps their user, their entries and their participations,
#   but has no access to the org any more. Their other orgs are not affected.
#
RSpec.describe "Archived members" do
  let(:project) { create(:project) }
  let(:org) { project.org }
  let(:participant) { create(:participant, project:) }
  let(:member) { participant.member }

  def org_switcher_links
    Nokogiri::HTML(response.body).css("nav details a").pluck("href")
  end

  context "when signing in" do
    before { member.archive! }

    it "still signs the user in" do
      sign_in(member.user)

      expect(response).to redirect_to(root_url)
    end

    it "turns them away from the org" do
      sign_in(member.user)
      get open_path(org.slug, project.slug)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not a member of this org")
    end

    it "still opens their other orgs and lists only those" do
      other_member = create(:member, user: member.user)
      other = create(:participant, member: other_member, project: create(:project, org: other_member.org))
      sign_in(member.user)

      get open_path(other.org.slug, other.project.slug)

      expect(response).to redirect_to(project_path(other.project.slug))

      get settings_path

      expect(org_switcher_links).to include(open_path(other.org.slug))
      expect(org_switcher_links).not_to include(open_path(org.slug))
    end
  end

  context "when archived while the org is open" do
    before do
      sign_in_and_open(participant)
      member.archive!
    end

    it "drops the org from the session" do
      get projects_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Select an org first")
    end

    it "refuses new entries" do
      expect { post entries_path, params: { entry: { date: Time.zone.today.iso8601, log: "Too late" } } }
        .not_to change(Entry, :count)
    end
  end

  it "lets a reactivated member back in" do
    member.archive!
    member.unarchive!
    sign_in_and_open(participant)

    expect(response).to redirect_to(project_path(project.slug))
  end

  context "with a colleague reading the project" do
    before do
      member.update!(name: "Archie")
      create(:entry, member:, day: create(:day, project:, date: Date.new(2026, 3, 2)), log: "Archived work")
      member.archive!
      sign_in_and_open(create(:participant, :owner, project:))
    end

    it "still shows the archived member's entries" do
      get project_path(project.slug)

      expect(response.body).to include("Archived work")
    end

    it "still exports them" do
      get export_csv_project_path(project.slug, month: "2026-03")

      expect(response.body).to include("Archie")
    end
  end
end
