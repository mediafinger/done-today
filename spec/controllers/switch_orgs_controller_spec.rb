require "rails_helper"

RSpec.describe SwitchOrgsController do
  let(:user) { create(:user) }
  let(:org) { create(:org) }
  let(:project) { create(:project, org: org) }

  before do
    sign_in(user)
  end

  describe "GET #switch_to for org member when project and participation are present" do
    let!(:member) { create(:member, org: org, user: user) }
    let!(:participant) { create(:participant, org: org, project: project, member: member) }

    it "switches both org and project, and redirects to project show" do
      get :switch_to, params: { slug_org: org.slug, slug_project: project.slug }
      expect(response).to redirect_to(project_path(project.slug))
      expect(flash[:notice]).to include("selected")
      session = Session.last
      expect(session.org_id).to eq(org.id)
      expect(session.project_id).to eq(project.id)
    end
  end

  describe "GET #switch_to for org member when project is not present or user is not a participant" do
    let!(:member) { create(:member, org: org, user: user) }

    it "switches org and redirects to projects index" do
      get :switch_to, params: { slug_org: org.slug, slug_project: "nonexistent" }
      expect(response).to redirect_to(projects_path)
      expect(flash[:notice]).to include("selected")
      session = Session.last
      expect(session.org_id).to eq(org.id)
      expect(session.project_id).to be_nil
    end
  end

  describe "GET #switch_to when user is not a member of the org" do
    it "redirects to root path with alert" do
      pending "Fix SwitchOrgsController nil pointer bug on member.participations when user is not a member of the org"
      get :switch_to, params: { slug_org: org.slug, slug_project: project.slug }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not a member of this org")
    end
  end
end
