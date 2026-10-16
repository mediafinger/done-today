require "rails_helper"

# Who may do what is covered by spec/requests/authorization_matrix_spec.rb,
#   this is what an org owner or a project lead sees and changes.
#
RSpec.describe "Managing projects" do
  let(:org) { create(:org) }
  let(:owner) { create(:member, :owner, org:) }
  let(:project) { create(:project, org:, name: "Website") }
  let(:participant) { create(:participant, project:) }

  def page
    Nokogiri::HTML(response.body)
  end

  def links
    page.css("main a").pluck("href")
  end

  before { sign_in(owner.user) }

  describe "GET /:org/projects/new" do
    it "offers a form for the name" do
      get new_project_path(org)

      expect(response).to have_http_status(:ok)
      expect(page.at_css("form")["action"]).to eq(projects_path(org))
      expect(page.at_css("input[name='project[name]']")).to be_present
    end

    it "is linked from the org's projects for an org owner" do
      get org_path(org)

      expect(links).to include(new_project_path(org))
    end

    it "is not linked for anyone else" do
      sign_in(participant.member.user)

      get org_path(org)

      expect(links).not_to include(new_project_path(org))
    end
  end

  describe "POST /:org/projects" do
    it "creates the project and continues on its settings" do
      expect { post projects_path(org), params: { project: { name: "Shop" } } }.to change(org.projects, :count).by(1)

      shop = org.projects.find_by!(name: "Shop")
      expect(shop.slug).to eq("shop")
      expect(response).to redirect_to(edit_project_path(org, shop))
      expect(flash[:notice]).to eq("Created Shop")
    end

    it "refuses a name the org already uses" do
      project

      expect { post projects_path(org), params: { project: { name: "Website" } } }.not_to change(Project, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name has already been taken")
    end

    it "refuses a blank name" do
      post projects_path(org), params: { project: { name: " " } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can&#39;t be blank")
    end

    # /:org/members is the member list, a project there would be unreachable
    it "refuses a name that is an org-level page" do
      expect { post projects_path(org), params: { project: { name: "Members" } } }.not_to change(Project, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can&#39;t be used, members is reserved for the app")
    end

    it "refuses a name without a letter or digit" do
      post projects_path(org), params: { project: { name: "%%" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name needs at least one letter or digit")
    end
  end

  describe "GET /:org/:project/edit" do
    it "offers to rename and to archive the project" do
      get edit_project_path(org, project)

      expect(response).to have_http_status(:ok)
      expect(page.at_css("input[name='project[name]']")["value"]).to eq("Website")
      expect(page.css("form").pluck("action")).to include(archive_project_path(org, project))
    end

    it "is linked from the project page for those who manage it" do
      get project_path(org, project)

      expect(links).to include(edit_project_path(org, project))
    end

    it "is not linked from the project page for a participant" do
      sign_in(participant.member.user)

      get project_path(org, project)

      expect(links).not_to include(edit_project_path(org, project))
    end

    it "offers to unarchive an archived project" do
      project.archive!

      get edit_project_path(org, project)

      expect(page.css("form").pluck("action")).to include(unarchive_project_path(org, project))
      expect(page.css("form").pluck("action")).not_to include(archive_project_path(org, project))
    end
  end

  describe "PATCH /:org/:project" do
    it "renames the project and keeps its slug, so links keep working" do
      patch project_path(org, project), params: { project: { name: "Shop" } }

      expect(project.reload.name).to eq("Shop")
      expect(project.slug).to eq("website")
      expect(response).to redirect_to(edit_project_path(org, project))
      expect(flash[:notice]).to eq("Renamed Website to Shop")
    end

    it "lets a project lead rename it" do
      project_lead = create(:participant, :lead, project:).member
      sign_in(project_lead.user)

      patch project_path(org, project), params: { project: { name: "Shop" } }

      expect(project.reload.name).to eq("Shop")
    end

    it "refuses a name the org already uses" do
      create(:project, org:, name: "Shop")

      patch project_path(org, project), params: { project: { name: "Shop" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name has already been taken")
      expect(project.reload.name).to eq("Website")
    end

    it "does not take a slug" do
      patch project_path(org, project), params: { project: { name: "Shop", slug: "shop" } }

      expect(project.reload.slug).to eq("website")
    end
  end

  describe "PATCH /:org/:project/archive" do
    let!(:entry) { create(:entry, day: create(:day, project:), member: participant.member, log: "Shipped it") }

    it "archives the project and keeps its entries" do
      patch archive_project_path(org, project)

      expect(project.reload).to be_archived
      expect(Entry.exists?(entry.id)).to be(true)
      expect(response).to redirect_to(project_path(org, project))
      expect(flash[:notice]).to eq("Archived Website, its entries stay readable")
    end

    it "keeps the project readable for its participants, read-only" do
      project.archive!
      sign_in(participant.member.user)

      get project_path(org, project)
      expect(response.body).to include("Shipped it", "Archived on #{Time.zone.today}")

      get edit_day_path(org, project, Time.zone.today)
      expect(response).to have_http_status(:ok)
      expect(page.at_css("#new-entry")).to be_nil
    end

    it "hides the project from the switcher, from / and from the settings" do
      project.archive!
      sign_in(participant.member.user)

      get root_path
      expect(page.css("a").pluck("href")).not_to include(project_path(org, project))

      get org_settings_path(org)
      expect(page.css("a").pluck("href")).not_to include(project_path(org, project))
    end

    it "lists the project as archived for those who manage it" do
      project.archive!

      get org_path(org)

      expect(page.at_css("#archived-projects").css("a").pluck("href")).to include(project_path(org, project))
      expect(page.at_css("#active-projects").css("a").pluck("href")).not_to include(project_path(org, project))
    end

    it "lists the project nowhere for a participant" do
      project.archive!
      sign_in(participant.member.user)

      get org_path(org)

      expect(links).not_to include(project_path(org, project))
      expect(page.at_css("#archived-projects")).to be_nil
    end

    it "still exports the project" do
      project.archive!

      get export_csv_project_path(org, project, month: Time.zone.today.strftime("%Y-%m"))

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end
  end

  describe "PATCH /:org/:project/unarchive" do
    it "makes the project writable again" do
      project.archive!

      patch unarchive_project_path(org, project)

      expect(project.reload).not_to be_archived
      expect(response).to redirect_to(project_path(org, project))
      expect(flash[:notice]).to eq("Unarchived Website")
    end
  end
end
