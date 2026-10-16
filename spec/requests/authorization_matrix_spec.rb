require "rails_helper"

# Every endpoint against every role, for one project P of one org. Org and project
#   are part of every path, so nothing is selected beforehand.
#
#   anonymous      not signed in
#   no_org         signed in, member of no org
#   archived       deactivated member of the org, was org owner and owner of P
#   outsider       member of another org
#   member         org member, no participation in P
#   observer       participates in P as observer
#   participant    participates in P as participant
#   project_owner  participates in P as owner
#   org_owner      owner of the org, no participation in P
#
# Outcomes: an HTTP status, or
#   :listed / :hidden    a link to P on the page
#   :form / :read_only   the edit page, with or without the new entry field
#   :written             the write went through
#   :to_today            redirected to today in P
#   :to_sign_in          redirected to the sign-in page (nothing written)
#
RSpec.describe "Authorization role matrix" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:colleagues_entry) { create(:entry, day: create(:day, project:), member: create(:participant, project:).member) }
  let(:own_entry) { create(:entry, day: create(:day, project:), member: me) }

  let(:personas) do
    {
      outsider: create(:member),
      member: create(:member, org:),
      observer: create(:participant, :observer, project:).member,
      participant: create(:participant, project:).member,
      project_owner: create(:participant, :owner, project:).member,
      org_owner: create(:member, :owner, org:),
      # after org_owner, so the org keeps an owner
      archived: create(:participant, :owner, project:, member: create(:member, :owner, org:)).member.tap(&:archive!)
    }
  end

  # the personas without access to any org: they are locked out of every page below /:org
  def self.locked_out
    { anonymous: :to_sign_in, no_org: :not_found, archived: :not_found }
  end

  # the persona of the running example, nil for anonymous and no_org
  def me
    personas[RSpec.current_example.metadata[:persona]]
  end

  def sign_in_as(persona)
    case persona
    when :anonymous then nil
    when :no_org then sign_in(create(:user))
    else sign_in(personas.fetch(persona).user)
    end
  end

  # a member of the org who is none of the personas
  def colleague
    colleagues_entry.member
  end

  def colleagues_session
    @colleagues_session ||= colleague.user.sessions.create!(user_agent: "Matrix", ip_address: "127.0.0.1")
  end

  def pending_invitation
    org.invitations.find_or_create_by!(email: "pending@example.com") { it.sent_at = 2.days.ago }
  end

  def link_to_project?
    Nokogiri::HTML(response.body).css("main a").any? { it["href"] == project_path(org, project) }
  end

  def expect_outcome(outcome, written)
    case outcome
    when :written
      expect(instance_exec(&written)).to be(true)
    when :listed, :hidden
      expect(response).to have_http_status(:ok)
      expect(link_to_project?).to be(outcome == :listed)
    when :to_today
      expect(response).to redirect_to(edit_day_path(org, project, Time.zone.today))
    when :to_sign_in
      expect(response).to redirect_to(new_session_path)
      expect(instance_exec(&written)).to be(false) if written
    when :form, :read_only
      expect(response).to have_http_status(:ok)
      expect(response.body.include?(%(id="new-entry"))).to be(outcome == :form)
    else
      expect(response).to have_http_status(outcome)
      expect(instance_exec(&written)).to be(false) if written
    end
  end

  # one example per persona: sign in, send the request, check the outcome
  def self.row(name, outcomes, written: nil, &request)
    describe name do
      outcomes.each do |persona, outcome|
        it "#{persona}: #{outcome}", persona: do
          personas
          sign_in_as(persona)

          instance_exec(&request)

          expect_outcome(outcome, written)
        end
      end
    end
  end

  # Without an org in the path nothing depends on roles. P is the only project of
  #   whoever takes part in it, so / goes straight there.
  row "GET / (today in the only project, or the user's orgs and projects)", {
    anonymous: :to_sign_in, no_org: :hidden, archived: :hidden, outsider: :hidden, member: :hidden, observer: :to_today,
    participant: :to_today, project_owner: :to_today, org_owner: :hidden
  } do
    get root_path
  end

  row "GET /settings", {
    anonymous: :to_sign_in, no_org: :ok, archived: :ok, outsider: :ok, member: :ok, org_owner: :ok
  } do
    get settings_path
  end

  row "GET /session/new", { anonymous: :ok, no_org: :ok, member: :ok } do
    get new_session_path
  end

  # POST /session is how every example signs in
  row "DELETE /session", { anonymous: :to_sign_in, no_org: :to_sign_in, member: :to_sign_in } do
    delete session_path
  end

  row "GET /passwords/new", { anonymous: :ok, member: :ok } do
    get new_password_path
  end

  row "POST /passwords", { anonymous: :to_sign_in, member: :to_sign_in } do
    post passwords_path, params: { email: colleague.user.email }
  end

  # the token decides, not the session
  row "GET /passwords/:token/edit", { anonymous: :ok, member: :ok } do
    get edit_password_path(colleague.user.password_reset_token)
  end

  row "PATCH /passwords/:token", {
    anonymous: :written, member: :written
  }, written: -> { colleague.user.reload.authenticate("a brand new password").present? } do
    patch password_path(colleague.user.password_reset_token),
      params: { password: "a brand new password", password_confirmation: "a brand new password" }
  end

  # another account has to sign out first, see spec/requests/users/invitations_spec.rb
  row "GET /invitations/:token", { anonymous: :ok, no_org: :forbidden, member: :forbidden } do
    get accept_invitation_path(pending_invitation.generate_token_for(:acceptance))
  end

  row "PATCH /invitations/:token", {
    anonymous: :written, no_org: :forbidden, member: :forbidden
  }, written: -> { org.members.joins(:user).exists?(user: { email: "pending@example.com" }) } do
    patch accept_invitation_path(pending_invitation.generate_token_for(:acceptance)),
      params: { user: { name: "Pending", password: "a brand new password", password_confirmation: "a brand new password" } }
  end

  # the account pages only ever act on the signed-in user
  row "GET /user/edit", { anonymous: :to_sign_in, no_org: :ok, member: :ok } do
    get edit_user_path
  end

  row "PATCH /user", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_path, params: { user: { name: "Renamed" } }
  end

  row "GET /user/email/edit", { anonymous: :to_sign_in, no_org: :ok, member: :ok } do
    get edit_user_email_path
  end

  row "PATCH /user/email", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_email_path, params: { user: { email: "renamed@example.com", password_challenge: "correct horse battery staple" } }
  end

  row "GET /user/password/edit", { anonymous: :to_sign_in, no_org: :ok, member: :ok } do
    get edit_user_password_path
  end

  row "PATCH /user/password", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_password_path, params: {
      user: { password: "a brand new password", password_confirmation: "a brand new password", password_challenge: "correct horse battery staple" }
    }
  end

  row "GET /user/sessions", { anonymous: :to_sign_in, no_org: :ok, member: :ok } do
    get user_sessions_path
  end

  row "DELETE /user/sessions/:id of another account", {
    anonymous: :to_sign_in, no_org: :not_found, member: :not_found
  }, written: -> { !Session.exists?(colleagues_session.id) } do
    delete user_session_path(colleagues_session)
  end

  row "DELETE /user/sessions/destroy_others", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    delete destroy_others_user_sessions_path
  end

  row "PATCH /user/display_mode", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_display_mode_path, params: { user: { display_mode: "dark" } }, headers: { "HTTP_REFERER" => root_url }
  end

  row "GET an unknown path", { anonymous: :to_sign_in, no_org: :not_found, member: :not_found } do
    get "/no/such/page/at/all"
  end

  row "GET /:org (its projects)", {
    **locked_out, outsider: :not_found, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed,
    org_owner: :listed
  } do
    get org_path(org)
  end

  row "GET /:org/settings", {
    **locked_out, outsider: :not_found, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed,
    org_owner: :listed
  } do
    get org_settings_path(org)
  end

  row "GET /:org/:project", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get project_path(org, project)
  end

  # a project is only found below the slug of its own org
  row "GET /:own_org/:project of another org", { outsider: :not_found } do
    get project_path(me.org, project)
  end

  row "GET /:org/:project/validate_times", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get validate_times_project_path(org, project)
  end

  row "GET /:org/:project/export_csv", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_csv_project_path(org, project, month: "2026-03")
  end

  row "GET /:org/:project/export_days_csv", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_days_csv_project_path(org, project, month: "2026-03", member_id: colleagues_entry.member_id)
  end

  row "GET /:org/:project/days/:date", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    colleagues_entry # the day exists

    get day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/days/:date/edit", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :read_only, participant: :form, project_owner: :form,
    org_owner: :read_only
  } do
    colleagues_entry # the day exists

    get edit_day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/tags/:tag", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get tag_path(org, project, "handover")
  end

  row "GET /:org/:project/weeks/:week", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get week_path(org, project, "2026-W38")
  end

  row "GET /:org/:project/members/:id/entries", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get member_entries_path(org, project, colleague)
  end

  row "POST /:org/:project/entries", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :written, project_owner: :written,
    org_owner: :forbidden
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH /:org/:project/entries/:id of a colleague", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :forbidden
  }, written: -> { colleagues_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(org, project, colleagues_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  # an observer may have entries from before they became one
  row "PATCH /:org/:project/entries/:id of their own", {
    observer: :forbidden, participant: :written, project_owner: :written
  }, written: -> { own_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(org, project, own_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  row "GET /:org/:project/entries/:id/history", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :ok,
    org_owner: :ok
  } do
    get entry_history_path(org, project, colleagues_entry)
  end

  row "GET /:org/members", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :ok
  } do
    get members_path(org)
  end

  row "PATCH /:org/members/:id", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.roles.include?("owner") } do
    patch member_path(org, colleague), params: { member: { roles: %w[member owner] } }
  end

  row "PATCH /:org/members/:id/deactivate", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.archived? } do
    patch deactivate_member_path(org, colleague)
  end

  row "PATCH /:org/members/:id/reactivate", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { !colleague.reload.archived? } do
    colleague.archive!

    patch reactivate_member_path(org, colleague)
  end

  row "POST /:org/invitations", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { org.invitations.exists?(email: "invited@example.com") } do
    post invitations_path(org), params: { invitation: { email: "invited@example.com", roles: %w[member] } }
  end

  row "PATCH /:org/invitations/:id/resend", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { org.invitations.find_by!(email: "pending@example.com").sent_at > 1.hour.ago } do
    patch resend_invitation_path(org, pending_invitation)
  end

  row "DELETE /:org/invitations/:id", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { !org.invitations.exists?(email: "pending@example.com") } do
    delete invitation_path(org, pending_invitation)
  end

  row "GET /:org/projects/new", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :ok
  } do
    get new_project_path(org)
  end

  row "POST /:org/projects", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { org.projects.exists?(name: "Created by the matrix") } do
    post projects_path(org), params: { project: { name: "Created by the matrix" } }
  end

  row "GET /:org/:project/edit", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :ok,
    org_owner: :ok
  } do
    get edit_project_path(org, project)
  end

  row "PATCH /:org/:project (rename)", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.reload.name == "Renamed by the matrix" } do
    patch project_path(org, project), params: { project: { name: "Renamed by the matrix" } }
  end

  row "PATCH /:org/:project/archive", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.reload.archived? } do
    patch archive_project_path(org, project)
  end

  row "PATCH /:org/:project/unarchive", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { !project.reload.archived? } do
    project.archive!

    patch unarchive_project_path(org, project)
  end

  row "POST /:org/:project/participants", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.participants.exists?(member: personas[:member]) } do
    post participants_path(org, project), params: { participant: { member_id: personas[:member].id, role: "observer" } }
  end

  row "PATCH /:org/:project/participants/:id", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { colleague.participations.find_by!(project:).roles == %w[owner] } do
    patch participant_path(org, project, colleague.participations.find_by!(project:)), params: { participant: { role: "owner" } }
  end

  # the colleague's entries stay, see spec/requests/orgs/participants_spec.rb
  row "DELETE /:org/:project/participants/:id", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { !colleague.participations.exists?(project:) } do
    delete participant_path(org, project, colleague.participations.find_by!(project:))
  end

  # an archived project is read-only for everybody, listed only for those who manage it
  row "GET /:org (its projects) with P archived", {
    **locked_out, outsider: :not_found, member: :hidden, observer: :hidden, participant: :hidden, project_owner: :listed,
    org_owner: :listed
  } do
    project.archive!

    get org_path(org)
  end

  row "GET /:org/:project archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    project.archive!

    get project_path(org, project)
  end

  row "GET /:org/:project/days/:date/edit archived", {
    observer: :read_only, participant: :read_only, project_owner: :read_only, org_owner: :read_only
  } do
    colleagues_entry # the day exists
    project.archive!

    get edit_day_path(org, project, Time.zone.today)
  end

  row "POST /:org/:project/entries archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :forbidden
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    project.archive!

    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH /:org/:project/entries/:id of their own, archived", {
    participant: :forbidden, project_owner: :forbidden
  }, written: -> { own_entry.reload.log == "Changed by the matrix" } do
    own_entry
    project.archive!

    patch entry_path(org, project, own_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  row "GET /:org/:project/export_csv archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    project.archive!

    get export_csv_project_path(org, project, month: "2026-03")
  end

  # Nothing is selected in the session: two tabs on two projects of two orgs
  #   read and write each its own, in any order.
  describe "two projects in parallel" do
    it "keeps each request to the project of its path", persona: :participant do
      membership = create(:member, user: me.user)
      other = create(:participant, member: membership, project: create(:project, org: membership.org)).project
      sign_in(me.user)
      today = Time.zone.today.iso8601

      get edit_day_path(org, project, today)
      get edit_day_path(other.org, other, today)
      post entries_path(org, project), params: { entry: { date: today, log: "Logged in P" } }
      get day_path(org, project, today)
      post entries_path(other.org, other), params: { entry: { date: today, log: "Logged in Q" } }

      expect(Entry.find_by(log: "Logged in P").project).to eq(project)
      expect(Entry.find_by(log: "Logged in Q").project).to eq(other)

      get day_path(org, project, today)

      expect(response.body).to include("Logged in P")
      expect(response.body).not_to include("Logged in Q")
    end
  end
end
