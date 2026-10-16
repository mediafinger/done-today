require "rails_helper"

RSpec.describe "Project slugs" do
  describe "GET /:org_slug/:project_slug" do
    it "opens the project of the given org when another org has a project with the same slug" do
      other = create(:project, org: create(:org), name: "Website")
      project = create(:project, name: "Website")
      participant = create(:participant, project:)
      sign_in(participant.member.user)

      get project_path(project.org, "website")

      expect([ project.slug, other.slug ]).to eq(%w[website website])
      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@project)).to eq(project)
    end
  end
end
