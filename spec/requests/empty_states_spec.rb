require "rails_helper"

# What a page says when it has nothing to list, instead of an empty list.
#
RSpec.describe "Empty states" do
  let(:org) { create(:org, name: "Acme") }
  let(:project) { create(:project, org:, name: "Website") }
  let(:member) { create(:member, org:) }
  let(:participant) { create(:participant, project:, member:) }

  def main_text
    Nokogiri::HTML(response.body).at_css("main").text.squish
  end

  describe "an org without projects" do
    it "tells a member to ask an owner" do
      sign_in(member.user)

      get org_path(org)

      expect(main_text).to include("Acme has no projects yet. Ask an owner of Acme to add one.")
    end

    it "does not tell an org owner to ask an owner" do
      sign_in(create(:member, :owner, org:).user)

      get org_path(org)

      expect(main_text).to include("Acme has no projects yet")
      expect(main_text).not_to include("Ask an owner")
    end
  end

  describe "a project without entries" do
    before { sign_in(participant.member.user) }

    it "says so on each view of the project page" do
      %w[days weeks months].each do |view|
        get project_path(org, project, view:)

        expect(main_text).to include("Nothing has been logged in Website yet")
      end
    end
  end

  describe "a project the user does not take part in" do
    # an org owner who takes part in another project only
    let(:own) { create(:participant, member: create(:member, :owner, org:), project: create(:project, org:)) }

    before { sign_in(own.member.user) }

    it "explains why no entries can be added there" do
      get project_path(org, project)

      expect(main_text).to include("You do not take part in Website", "Ask a lead of the project to add you.")
    end

    it "does not say so on a project the user takes part in" do
      get project_path(org, own.project)

      expect(main_text).not_to include("You do not take part")
    end
  end

  describe "a day without entries" do
    before { sign_in(participant.member.user) }

    it "invites to log the first entry of the day" do
      get edit_day_path(org, project, Time.zone.today)

      expect(Nokogiri::HTML(response.body).at_css("#no-entries-yet").text).to include("You have not logged anything on this day yet")
    end

    it "drops the invitation once the first entry is in" do
      post entries_path(org, project, format: :turbo_stream), params: { entry: { date: Time.zone.today, log: "Wrote a spec" } }

      expect(response.body).to include(%(<turbo-stream action="remove" target="no-entries-yet">))
    end

    it "does not invite once the day has an entry" do
      create(:entry, day: create(:day, project:), member:)

      get edit_day_path(org, project, Time.zone.today)

      expect(response.body).not_to include("no-entries-yet")
    end

    it "says a locked past day stayed empty" do
      get edit_day_path(org, project, Time.zone.yesterday)

      expect(main_text).to include("You did not log anything on this day")
    end

    it "says nobody logged anything when reading the day" do
      get day_path(org, project, Time.zone.today)

      expect(main_text).to include("Nobody has logged anything on this day yet")
    end

    it "says nobody logged anything in the week" do
      get week_path(org, project, Time.zone.today.strftime("%G-W%V"))

      expect(main_text).to include("Nobody has logged anything in this week")
    end

    it "says no entries carry the tag" do
      get tag_path(org, project, "handover")

      expect(main_text).to include("No entries are tagged #handover yet")
    end

    it "says a member has not logged anything yet" do
      get member_entries_path(org, project, member)

      expect(main_text).to include("#{member.name} has not logged anything yet")
    end
  end

  describe "an observer on the edit page" do
    let(:participant) { create(:participant, :observer, project:, member:) }

    before { sign_in(participant.member.user) }

    it "explains that they read along instead of offering an entry field" do
      get edit_day_path(org, project, Time.zone.today)

      expect(main_text).to include("You can read the entries of Website, but not add any")
      expect(main_text).to include("Nobody has logged anything on this day yet")
      expect(response.body).not_to include("new-entry")
    end
  end
end
