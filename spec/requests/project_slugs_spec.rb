require "rails_helper"

RSpec.describe "Project slugs" do
  describe "GET /open/:slug_org/:slug_project" do
    it "opens the project of the given org when another org has a project with the same slug" do
      create(:project, org: create(:org), name: "Website")
      project = create(:project, name: "Website")
      participant = create(:participant, project:)

      sign_in_and_open(participant)

      expect(project.slug).to eq("website")
      expect(response).to redirect_to(project_path("website"))
      expect(Session.last.project).to eq(project)
    end
  end
end
