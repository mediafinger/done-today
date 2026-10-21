require "rails_helper"

# Every endpoint against every role, for one project P of one org. Org and project
#   are part of every path, so nothing is selected beforehand.
#
#   anonymous      not signed in
#   no_org         signed in, member of no org
#   archived       deactivated member of the org, was org owner and lead of P
#   outsider       member of another org
#   member         org member, no participation in P
#   observer       participates in P as observer
#   participant    participates in P as participant
#   project_lead   participates in P as lead
#   org_owner      owner of the org, no participation in P
#   org_manager    manager of the org, no participation in P
#   guest          external, participates in P as participant
#   outside_guest  external, participates in another project of the org
#   admin          signed in as an admin (users.admin), member of no org
#
# A row that names no outcome for guest takes participant's, for outside_guest member's,
#   for org_manager org_owner's.
#
# Outcomes: an HTTP status, or
#   :listed / :hidden    a link to P on the page, or none and not its name either
#   :named               P's name on the list of projects, without a link
#   :form / :read_only   the edit page, with or without the new entry field
#   :written             the write went through
#   :to_today            redirected to today in P
#   :to_sign_in          redirected to the sign-in page (nothing written)
#
RSpec.describe "Authorization role matrix" do
  # created once for all examples; refind/reload hands each example a fresh copy
  let_it_be(:org, refind: true) { create(:org) }
  let_it_be(:project, refind: true) { create(:project, org:) }
  let(:colleagues_entry) { create(:entry, day: create(:day, project:), member: create(:participant, project:).member) }
  let(:own_entry) { create(:entry, day: create(:day, project:), member: me) }

  let_it_be(:persona_records) do
    {
      outsider: create(:member),
      member: create(:member, org:),
      observer: create(:participant, :observer, project:).member,
      participant: create(:participant, project:).member,
      project_lead: create(:participant, :lead, project:).member,
      org_owner: create(:member, :owner, org:),
      org_manager: create(:member, :manager, org:),
      guest: create(:participant, project:, member: create(:member, :guest, org:)).member,
      outside_guest: create(:participant, project: create(:project, org:), member: create(:member, :guest, org:)).member,
      # after org_owner, so the org keeps an owner
      archived: create(:participant, :lead, project:, member: create(:member, :owner, org:)).member.tap(&:archive!)
    }
  end

  def personas
    @personas ||= persona_records.transform_values(&:reload)
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
    when :admin then sign_in(create(:user, :admin))
    else sign_in(personas.fetch(persona).user)
    end
  end

  # a member of the org who is none of the personas
  def colleague
    colleagues_entry.member
  end

  def colleague_changing_email
    colleague.user.tap { it.update!(unconfirmed_email: "changing@example.com") }
  end

  def colleagues_session
    @colleagues_session ||= colleague.user.sessions.create!(user_agent: "Matrix", ip_address: "127.0.0.1")
  end

  def colleagues_connection
    @colleagues_connection ||= create(:connection, user: colleague.user)
  end

  def pending_invitation(role: "member")
    org.invitations.find_or_create_by!(email: "pending@example.com") { it.assign_attributes(role:, sent_at: 2.days.ago) }
  end

  # an owner besides the org_owner persona, so either of them may step down
  def other_owner
    @other_owner ||= create(:member, :owner, org:)
  end

  def pending_guest_invitation
    create(:invitation, :guest, org:, project:, email: "guest@example.com", sent_at: 2.days.ago)
  end

  # of a member who is none of the personas
  def pending_participation_request
    @pending_participation_request ||= create(:participation_request, project:, member: create(:member, org:))
  end

  def link_to_project?
    Nokogiri::HTML(response.body).css("main a").any? { it["href"] == project_path(org, project) }
  end

  def project_named?
    Nokogiri::HTML(response.body).at_css("main ##{ActionView::RecordIdentifier.dom_id(project)}").present?
  end

  def expect_outcome(outcome, written)
    case outcome
    when :written
      expect(instance_exec(&written)).to be(true)
    when :listed, :hidden
      expect(response).to have_http_status(:ok)
      expect(link_to_project?).to be(outcome == :listed)
      expect(project_named?).to be(false) if outcome == :hidden
    when :named
      expect(response).to have_http_status(:ok)
      expect([ link_to_project?, project_named? ]).to eq([ false, true ])
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
    defaults = { guest: outcomes[:participant], outside_guest: outcomes[:member], org_manager: outcomes[:org_owner] }
    outcomes = defaults.compact.merge(outcomes)

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
  #   whoever takes part in it, so / goes straight there. outside_guest lands in their own project.
  row "GET / (today in the only project, or the user's orgs and projects)", {
    anonymous: :to_sign_in, no_org: :hidden, archived: :hidden, outsider: :hidden, member: :hidden,
    outside_guest: :found, observer: :to_today, participant: :to_today, project_lead: :to_today, org_owner: :hidden
  } do
    get root_path
  end

  row "GET /settings", {
    anonymous: :to_sign_in, no_org: :ok, archived: :ok, outsider: :ok, member: :ok, org_owner: :ok
  } do
    get settings_path
  end

  row "GET /impressum", { anonymous: :ok, no_org: :ok, member: :ok } do
    get imprint_path
  end

  row "GET /datenschutz", { anonymous: :ok, no_org: :ok, member: :ok } do
    get privacy_path
  end

  row "GET /help", { anonymous: :ok, no_org: :ok, member: :ok } do
    get help_path
  end

  # only admins are routed to /admin, everyone else gets what an unknown path answers
  row "GET /admin", {
    anonymous: :to_sign_in, no_org: :not_found, archived: :not_found, member: :not_found, org_owner: :not_found, admin: :ok
  } do
    get admin_home_path
  end

  # development only, see spec/requests/devs/dev_area_spec.rb
  row "GET /dev", { anonymous: :ok, no_org: :ok, member: :ok, admin: :ok } do
    allow(DevConstraint).to receive(:matches?).and_return(true)
    get dev_home_path
  end

  # Mission Control inherits from AdminController
  row "GET /admin/mission_control_jobs", {
    anonymous: :to_sign_in, no_org: :not_found, archived: :not_found, member: :not_found, org_owner: :not_found, admin: :ok
  } do
    get "/admin/mission_control_jobs"
  end

  # signed in already: off to / or to changing the password
  row "GET /session/new", { anonymous: :ok, no_org: :found, member: :found } do
    get new_session_path
  end

  # POST /session is how every example signs in
  row "DELETE /session", { anonymous: :to_sign_in, no_org: :to_sign_in, member: :to_sign_in } do
    delete session_path
  end

  row "GET /passwords/new", { anonymous: :ok, member: :found } do
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
    patch user_email_path, params: { user: { unconfirmed_email: "renamed@example.com", password_challenge: "correct horse battery staple" } }
  end

  row "DELETE /user/email", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    delete user_email_path
  end

  # the token decides, not the session: a colleague's link changes the colleague's email
  row "GET /user/email/confirmations/:token", { anonymous: :ok, member: :ok } do
    get user_email_confirmation_path(colleague_changing_email.generate_token_for(:email_confirmation))
  end

  row "PATCH /user/email/confirmations/:token", {
    anonymous: :written, member: :written
  }, written: -> { colleague.user.reload.email == "changing@example.com" } do
    patch user_email_confirmation_path(colleague_changing_email.generate_token_for(:email_confirmation))
  end

  row "GET /user/email/reverts/:token", { anonymous: :ok, member: :ok } do
    get user_email_revert_path(colleague_changing_email.email_revert_token)
  end

  row "PATCH /user/email/reverts/:token", {
    anonymous: :written, member: :written
  }, written: -> { colleague.user.reload.unconfirmed_email.nil? } do
    patch user_email_revert_path(colleague_changing_email.email_revert_token)
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

  row "GET /user/access_tokens", { anonymous: :to_sign_in, no_org: :ok, member: :ok } do
    get user_access_tokens_path
  end

  row "POST /user/access_tokens", { anonymous: :to_sign_in, no_org: :unprocessable_content, member: :created } do
    post user_access_tokens_path, params: { connection: { name: "Matrix" }, expires_in_days: "30", grants: { orgs: { org.id => "read" } } }
  end

  row "DELETE /user/access_tokens/:id of another account", {
    anonymous: :to_sign_in, no_org: :not_found, member: :not_found
  }, written: -> { colleagues_connection.reload.revoked? } do
    delete user_access_token_path(colleagues_connection)
  end

  row "DELETE /user/access_tokens/destroy_all", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    delete destroy_all_user_access_tokens_path
  end

  row "PATCH /user/display_mode", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_display_mode_path, params: { user: { display_mode: "dark" } }, headers: { "HTTP_REFERER" => root_url }
  end

  row "PATCH /user/time_zone", { anonymous: :to_sign_in, no_org: :found, member: :found } do
    patch user_time_zone_path, params: { user: { time_zone: "America/New_York" } }
  end

  row "GET an unknown path", { anonymous: :to_sign_in, no_org: :not_found, member: :not_found } do
    get "/no/such/page/at/all"
  end

  # internals know every project, reading it takes a participation
  row "GET /:org (its projects)", {
    **locked_out, outsider: :not_found, member: :named, outside_guest: :hidden, observer: :listed, participant: :listed, project_lead: :listed,
    org_owner: :listed
  } do
    get org_path(org)
  end

  row "GET /:org/settings", {
    **locked_out, outsider: :not_found, member: :hidden, observer: :listed, participant: :listed, project_lead: :listed,
    org_owner: :listed
  } do
    get org_settings_path(org)
  end

  # every project's tag times, everyone's: org managers and owners only
  row "GET /:org/tags", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :ok
  } do
    get org_tags_path(org, month: "2026-10")
  end

  row "GET /:org/tags of one member", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :ok
  } do
    get org_tags_path(org, month: "2026-10", member_id: colleague.id)
  end

  row "GET /:org/tags.csv", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :ok
  } do
    get org_tags_path(org, month: "2026-10", format: :csv)
  end

  row "GET /:org/:project", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get project_path(org, project)
  end

  # a project is only found below the slug of its own org
  row "GET /:own_org/:project of another org", { outsider: :not_found } do
    get project_path(me.org, project)
  end

  row "GET /:org/:project/validate_times", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get validate_times_project_path(org, project)
  end

  row "GET /:org/:project/export_csv", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_lead: :ok, org_owner: :ok
  } do
    get export_csv_project_path(org, project, month: "2026-03")
  end

  row "GET /:org/:project/export_days_csv", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_lead: :ok, org_owner: :ok
  } do
    get export_days_csv_project_path(org, project, month: "2026-03", member_id: colleagues_entry.member_id)
  end

  row "GET /:org/:project/days/:date", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    colleagues_entry # the day exists

    get day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/days/:date/edit", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :read_only, participant: :form, project_lead: :form,
    org_owner: :read_only
  } do
    colleagues_entry # the day exists

    get edit_day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/tags", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get tags_path(org, project, month: "2026-10")
  end

  row "GET /:org/:project/tags.csv", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get tags_path(org, project, month: "2026-10", format: :csv)
  end

  row "GET /:org/:project/tags/:tag", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get tag_path(org, project, "handover")
  end

  row "GET /:org/:project/weeks/:week", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get week_path(org, project, "2026-W38")
  end

  row "GET /:org/:project/members/:id/entries", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    get member_entries_path(org, project, colleague)
  end

  row "POST /:org/:project/entries", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :written, project_lead: :written,
    org_owner: :forbidden
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH /:org/:project/entries/:id of a colleague", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :forbidden
  }, written: -> { colleagues_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(org, project, colleagues_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  # an observer may have entries from before they became one
  row "PATCH /:org/:project/entries/:id of their own", {
    observer: :forbidden, participant: :written, project_lead: :written
  }, written: -> { own_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(org, project, own_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  row "GET /:org/:project/entries/:id/history", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :ok,
    org_owner: :ok
  } do
    get entry_history_path(org, project, colleagues_entry)
  end

  # read-only for internals, guests only see their projects
  row "GET /:org/members", {
    **locked_out, outsider: :not_found, member: :ok, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok,
    guest: :forbidden, outside_guest: :forbidden
  } do
    get members_path(org)
  end

  # managers do everything owners do, except giving or taking the owner role
  row "PATCH /:org/members/:id (to owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { colleague.reload.owner? } do
    patch member_path(org, colleague), params: { member: { role: "owner" } }
  end

  row "PATCH /:org/members/:id (to manager)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.manager? } do
    patch member_path(org, colleague), params: { member: { role: "manager" } }
  end

  row "PATCH /:org/members/:id of an owner (to member)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { other_owner.reload.member? } do
    patch member_path(org, other_owner), params: { member: { role: "member" } }
  end

  row "PATCH /:org/members/:id/deactivate of an owner", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { other_owner.reload.archived? } do
    patch deactivate_member_path(org, other_owner)
  end

  row "PATCH /:org/members/:id/reactivate of an owner", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { !other_owner.reload.archived? } do
    other_owner.archive!

    patch reactivate_member_path(org, other_owner)
  end

  row "PATCH /:org/members/:id/deactivate", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.archived? } do
    patch deactivate_member_path(org, colleague)
  end

  row "PATCH /:org/members/:id/reactivate", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { !colleague.reload.archived? } do
    colleague.archive!

    patch reactivate_member_path(org, colleague)
  end

  row "POST /:org/invitations", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { org.invitations.exists?(email: "invited@example.com") } do
    post invitations_path(org), params: { invitation: { email: "invited@example.com", role: "member" } }
  end

  row "POST /:org/invitations (as owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { org.invitations.exists?(email: "invited@example.com") } do
    post invitations_path(org), params: { invitation: { email: "invited@example.com", role: "owner" } }
  end

  # turning a pending owner invitation into a member one takes the owner role as well
  row "POST /:org/invitations (to member, pending as owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { org.invitations.find_by!(email: "pending@example.com").member? } do
    pending_invitation(role: "owner")

    post invitations_path(org), params: { invitation: { email: "pending@example.com", role: "member" } }
  end

  row "PATCH /:org/invitations/:id/resend", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { org.invitations.find_by!(email: "pending@example.com").sent_at > 1.hour.ago } do
    patch resend_invitation_path(org, pending_invitation)
  end

  row "PATCH /:org/invitations/:id/resend (as owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { org.invitations.find_by!(email: "pending@example.com").sent_at > 1.hour.ago } do
    patch resend_invitation_path(org, pending_invitation(role: "owner"))
  end

  row "DELETE /:org/invitations/:id", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { !org.invitations.exists?(email: "pending@example.com") } do
    delete invitation_path(org, pending_invitation)
  end

  row "DELETE /:org/invitations/:id (as owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { !org.invitations.exists?(email: "pending@example.com") } do
    delete invitation_path(org, pending_invitation(role: "owner"))
  end

  # accepting reactivates the deactivated owner with the invited role, which takes their owner role
  row "POST /:org/invitations (to member, a deactivated owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { org.invitations.exists?(email: personas[:archived].user.email) } do
    post invitations_path(org), params: { invitation: { email: personas[:archived].user.email, role: "member" } }
  end

  row "PATCH /:org/invitations/:id/resend (to a deactivated owner)", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { org.invitations.find_by!(email: personas[:archived].user.email).sent_at > 1.hour.ago } do
    invitation = org.invitations.create!(email: personas[:archived].user.email, role: "member", sent_at: 2.days.ago)

    patch resend_invitation_path(org, invitation)
  end

  row "GET /:org/projects/new", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :ok
  } do
    get new_project_path(org)
  end

  row "POST /:org/projects", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { org.projects.exists?(name: "Created by the matrix") } do
    post projects_path(org), params: { project: { name: "Created by the matrix" } }
  end

  row "GET /:org/:project/edit", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :ok,
    org_owner: :ok
  } do
    get edit_project_path(org, project)
  end

  row "PATCH /:org/:project (rename)", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.reload.name == "Renamed by the matrix" } do
    patch project_path(org, project), params: { project: { name: "Renamed by the matrix" } }
  end

  row "PATCH /:org/:project (require times)", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.reload.times_required? } do
    patch project_path(org, project), params: { project: { times_required: "1" } }
  end

  row "PATCH /:org/:project/archive", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.reload.archived? } do
    patch archive_project_path(org, project)
  end

  row "PATCH /:org/:project/unarchive", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { !project.reload.archived? } do
    project.archive!

    patch unarchive_project_path(org, project)
  end

  # org and project leads invite guests to the project
  row "POST /:org/:project/guest_invitations", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.invitations.exists?(email: "guest@example.com") } do
    post guest_invitations_path(org, project), params: { invitation: { email: "guest@example.com", project_role: "participant" } }
  end

  row "PATCH /:org/:project/guest_invitations/:id/resend", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.invitations.find_by!(email: "guest@example.com").sent_at > 1.hour.ago } do
    patch resend_guest_invitation_path(org, project, pending_guest_invitation)
  end

  row "DELETE /:org/:project/guest_invitations/:id", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { !project.invitations.exists?(email: "guest@example.com") } do
    delete guest_invitation_path(org, project, pending_guest_invitation)
  end

  # a project lead or manager reactivating a deactivated owner as guest would take their owner role
  row "POST /:org/:project/guest_invitations (a deactivated owner)", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written, org_manager: :forbidden
  }, written: -> { project.invitations.exists?(email: personas[:archived].user.email) } do
    post guest_invitations_path(org, project),
      params: { invitation: { email: personas[:archived].user.email, project_role: "participant" } }
  end

  # bringing back a deactivated internal is up to the org's managers and owners
  row "POST /:org/:project/guest_invitations (a deactivated member)", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :written
  }, written: -> { project.invitations.exists?(email: "deactivated@example.com") } do
    create(:member, org:, user: create(:user, email: "deactivated@example.com")).archive!

    post guest_invitations_path(org, project), params: { invitation: { email: "deactivated@example.com", project_role: "participant" } }
  end

  # nobody invites guests to an archived project
  row "POST /:org/:project/guest_invitations with P archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :forbidden
  }, written: -> { project.invitations.exists? } do
    project.archive!

    post guest_invitations_path(org, project), params: { invitation: { email: "guest@example.com", project_role: "participant" } }
  end

  row "POST /:org/:project/participants", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.participants.exists?(member: personas[:member]) } do
    post participants_path(org, project), params: { participant: { member_id: personas[:member].id, role: "observer" } }
  end

  row "PATCH /:org/:project/participants/:id", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { colleague.participations.find_by!(project:).lead? } do
    patch participant_path(org, project, colleague.participations.find_by!(project:)), params: { participant: { role: "lead" } }
  end

  # the colleague's entries stay, see spec/requests/orgs/participants_spec.rb
  row "DELETE /:org/:project/participants/:id", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { !colleague.participations.exists?(project:) } do
    delete participant_path(org, project, colleague.participations.find_by!(project:))
  end

  # internals ask to join a project they cannot read, guests only know their own projects
  row "POST /:org/:project/participation_requests", {
    **locked_out, outsider: :not_found, member: :written, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :forbidden, outside_guest: :not_found
  }, written: -> { project.participation_requests.exists? } do
    post participation_requests_path(org, project), params: { participation_request: { message: "Please" } }
  end

  row "POST /:org/:project/participation_requests with P archived", {
    **locked_out, outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :forbidden, outside_guest: :not_found
  }, written: -> { project.participation_requests.exists? } do
    project.archive!

    post participation_requests_path(org, project)
  end

  # those who manage P decide, as they add participants
  row "PATCH /:org/:project/participation_requests/:id/grant", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { project.participants.exists?(member: pending_participation_request.member) } do
    patch grant_participation_request_path(org, project, pending_participation_request), params: { participation_request: { role: "observer" } }
  end

  row "PATCH /:org/:project/participation_requests/:id/decline", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :written,
    org_owner: :written
  }, written: -> { pending_participation_request.reload.declined? } do
    patch decline_participation_request_path(org, project, pending_participation_request)
  end

  # an archived project is read-only for everybody, listed only for those who manage it
  row "GET /:org (its projects) with P archived", {
    **locked_out, outsider: :not_found, member: :hidden, observer: :hidden, participant: :hidden, project_lead: :listed,
    org_owner: :listed
  } do
    project.archive!

    get org_path(org)
  end

  row "GET /:org/:project archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_lead: :ok, org_owner: :ok
  } do
    project.archive!

    get project_path(org, project)
  end

  row "GET /:org/:project/days/:date/edit archived", {
    observer: :read_only, participant: :read_only, project_lead: :read_only, org_owner: :read_only
  } do
    colleagues_entry # the day exists
    project.archive!

    get edit_day_path(org, project, Time.zone.today)
  end

  row "POST /:org/:project/entries archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_lead: :forbidden,
    org_owner: :forbidden
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    project.archive!

    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH /:org/:project/entries/:id of their own, archived", {
    participant: :forbidden, project_lead: :forbidden
  }, written: -> { own_entry.reload.log == "Changed by the matrix" } do
    own_entry
    project.archive!

    patch entry_path(org, project, own_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  row "GET /:org/:project/export_csv archived", {
    **locked_out, outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_lead: :ok, org_owner: :ok
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
