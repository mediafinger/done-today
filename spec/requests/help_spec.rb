require "rails_helper"

RSpec.describe "Help" do
  def page_text
    Nokogiri::HTML(response.body).at_css("main").text.squish
  end

  describe "GET /help" do
    it "is readable without signing in" do
      get help_path

      expect(response).to have_http_status(:ok)
    end

    it "is readable when signed in" do
      sign_in(create(:user))

      get help_path

      expect(response).to have_http_status(:ok)
    end

    it "shows every syntax example the parser is checked against" do
      get help_path

      logs = (SyntaxGuide::EXAMPLES + SyntaxGuide::NOT_MARKUP).map(&:log)

      expect(page_text).to include(*logs)
      expect(page_text).to include(SyntaxGuide::DAY_TOTAL)
    end

    it "explains that time tracking is optional" do
      get help_path

      expect(Nokogiri::HTML(response.body).at_css("main #times-optional")).to be_present
    end
  end

  describe "the navigation guide" do
    def help_link
      Nokogiri::HTML(response.body).at_css("nav a[href='#{help_path}']")
    end

    it "is linked from the nav before signing in" do
      get new_session_path

      expect(help_link).to be_present
    end

    it "is linked from the nav once signed in" do
      participant = create(:participant)
      sign_in(participant.member.user)

      get edit_day_path(participant.org, participant.project, Time.zone.today)

      expect(help_link).to be_present
    end

    it "explains the settings button and the org | project switcher" do
      get help_path

      guide = Nokogiri::HTML(response.body).at_css("main #navigation").text.squish

      expect(guide).to include("⚙", "Settings", "👤", "Account", "org | project", "projects you take part in")
      expect(guide).to include("managers and owners of the org, and leads of the project")
      expect(guide).not_to include("owners of the project")
    end
  end

  describe "the cheat sheet next to the entry field" do
    let(:participant) { create(:participant) }
    let(:org) { participant.org }
    let(:project) { participant.project }

    before { sign_in(participant.member.user) }

    def cheat_sheet
      Nokogiri::HTML(response.body).at_css("#editable-entries details#syntax-help")
    end

    it "folds the syntax up below the new entry field" do
      get edit_day_path(org, project, Time.zone.today)

      expect(cheat_sheet).to be_present
      expect(cheat_sheet.at_css("summary").text).to include("#tag", "for~")
      expect(cheat_sheet.text).to include(*SyntaxGuide::EXAMPLES.map(&:log))
      expect(cheat_sheet.at_css("a[href='#{help_path}']")).to be_present
    end

    it "is left out on a locked past day, which has no entry field" do
      get edit_day_path(org, project, Time.zone.yesterday)

      expect(cheat_sheet).to be_nil
    end
  end
end
