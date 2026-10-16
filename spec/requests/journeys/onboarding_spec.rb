require "rails_helper"

# From `rake done:org:create` to the first month export, through the app only.
#
RSpec.describe "Onboarding a team" do
  let(:password) { "correct horse battery staple" }

  def accept(invitation, name:)
    delete session_path if cookies[:session_id].present?

    patch accept_invitation_path(invitation.generate_token_for(:acceptance)),
      params: { user: { name:, password:, password_confirmation: password } }
  end

  def invitation_to(email)
    Invitation.pending.find_by!(email:)
  end

  it "takes the owner and a colleague from an invitation to an exported month" do
    setup = OrgSetup.call(name: "Acme", owner_email: "olivia@example.com", owner_name: "Olivia")
    org = setup.org

    # the owner signs up from the emailed link and lands in the empty org
    accept(setup.invitation, name: "Olivia")
    expect(response).to redirect_to(org_path(org))
    follow_redirect!
    expect(response.body).to include("Acme has no projects yet")

    # creates a project and invites a colleague
    post projects_path(org), params: { project: { name: "Website" } }
    project = org.projects.find_by!(name: "Website")
    expect(response).to redirect_to(edit_project_path(org, project))

    expect { post invitations_path(org), params: { invitation: { email: "ada@example.com", name: "Ada", role: "member" } } }
      .to have_enqueued_mail(InvitationsMailer, :invite)

    # the colleague signs up, knows the project exists, but cannot open it yet
    accept(invitation_to("ada@example.com"), name: "Ada")
    ada = org.members.joins(:user).find_by!(users: { email: "ada@example.com" })
    get project_path(org, project)
    expect(response).to have_http_status(:not_found)

    # the owner adds her to the project
    sign_in(User.find_by!(email: "olivia@example.com"))
    post participants_path(org, project), params: { participant: { member_id: ada.id, role: "participant" } }
    expect(project.participants.find_by!(member: ada).role).to eq("participant")

    # she logs her day, with time and tags
    sign_in(ada.user)
    today = Time.zone.today
    post entries_path(org, project), params: { entry: { date: today.iso8601, log: "Built the #landing page from@09:00 to@12:30" } }
    entry = ada.entries.sole
    expect(entry).to have_attributes(tags: [ "landing" ], duration_minutes: 210)

    get edit_day_path(org, project, today)
    expect(response.body).to include("Built the")

    # she cannot export everybody's month, the owner can
    get export_csv_project_path(org, project, month: today.strftime("%Y-%m"))
    expect(response).to have_http_status(:not_found)

    sign_in(User.find_by!(email: "olivia@example.com"))
    get export_csv_project_path(org, project, month: today.strftime("%Y-%m"))
    expect(response.media_type).to eq("text/csv")
    expect(response.body).to include("Ada")
  end
end
