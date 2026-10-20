require "rails_helper"

# ApplicationController verifies that every action called `authorize!` and
#   `authorized_scope`, or skipped the check explicitly, and raises otherwise.
#   This sends one request per route of the app as an owner of the org and lead of the project (as a member
#   outside the project to ask to join it, as an admin in the admin area), so every action runs to its end and its
#   verification with it.
#
#   A new route needs its params below, or this fails. The engines' routes have no
#   ApplicationController action and are left out.
#
RSpec.describe "Every action is authorized or skips it explicitly" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:me) { create(:participant, :lead, project:, member: create(:member, :owner, org:)).member }
  let(:colleague) { create(:participant, project:).member }
  # asks to join, takes part in no project
  let(:requester) { create(:member, org:) }

  def entry
    create(:entry, day: create(:day, project:, date: Time.zone.today), member: me)
  end

  def invitation
    org.invitations.create!(email: "invited@example.com", role: "member", sent_at: Time.current)
  end

  def guest_invitation
    create(:invitation, :guest, org:, project:)
  end

  # to another org, for the signed-in account
  def my_invitation
    create(:org).invitations.create!(email: me.user.email, role: "member", sent_at: Time.current)
  end

  # a pending email change of the signed-in account
  def changing_email
    me.user.tap { it.update!(unconfirmed_email: "changing@example.com") }
  end

  def path_value(name, controller)
    case [ name, controller ]
    in [ "org_slug", _ ] then org.slug
    in [ "project_slug" | "slug", _ ] then project.slug
    in [ "date", _ ] then Time.zone.today.iso8601
    in [ "week", _ ] then "2026-W38"
    in [ "tag", _ ] then "handover"
    in [ "member_id", _ ] then colleague.id
    in [ "entry_id", _ ] then entry.id
    in [ "path", _ ] then "no/such/page"
    in [ "token", "users/passwords" ] then me.user.password_reset_token
    in [ "token", "users/invitations" ] then my_invitation.generate_token_for(:acceptance)
    in [ "token", "users/user_email_confirmations" ] then changing_email.generate_token_for(:email_confirmation)
    in [ "token", "users/user_email_reverts" ] then changing_email.email_revert_token
    in [ "id", "orgs/members" ] then colleague.id
    in [ "id", "orgs/invitations" ] then invitation.id
    in [ "id", "orgs/guest_invitations" ] then guest_invitation.id
    in [ "id", "orgs/entries" ] then entry.id
    in [ "id", "users/user_sessions" ] then me.user.sessions.last.id
    in [ "id", "users/access_tokens" ] then create(:connection, user: me.user).id
    in [ "id", "orgs/access_requests" ] then create(:access_request, project:, member: requester).id
    in [ "id", "orgs/participants" ] then colleague.participations.find_by!(project:).id
    end
  end

  def request_params(controller, action)
    case "#{controller}##{action}"
    when "users/sessions#create" then { email: me.user.email, password: "correct horse battery staple" }
    when "users/passwords#create" then { email: me.user.email }
    when "users/passwords#update" then { password: "a brand new password", password_confirmation: "a brand new password" }
    when "users/users#update" then { user: { name: "Renamed" } }
    when "users/user_emails#update" then { user: { unconfirmed_email: "renamed@example.com", password_challenge: "correct horse battery staple" } }
    when "users/user_passwords#update"
      { user: { password: "a brand new password", password_confirmation: "a brand new password", password_challenge: "correct horse battery staple" } }
    when "users/display_modes#update" then { user: { display_mode: "dark" } }
    when "users/time_zones#update" then { user: { time_zone: "America/New_York" } }
    when "users/access_tokens#create" then { connection: { name: "Verified" }, expires_in_days: "30", grants: { orgs: { org.id => "read" } } }
    when "orgs/entries#create" then { entry: { date: Time.zone.today.iso8601, log: "Logged" } }
    when "orgs/entries#update" then { entry: { log: "Changed" } }
    when "orgs/members#update" then { member: { role: "owner" } }
    when "orgs/invitations#create" then { invitation: { email: "new@example.com", role: "member" } }
    when "orgs/guest_invitations#create" then { invitation: { email: "guest@example.com", project_role: "participant" } }
    when "orgs/projects#create", "orgs/projects#update" then { project: { name: "Renamed" } }
    when "orgs/projects#export_csv", "orgs/tags#index", "orgs/tag_times#index" then { month: "2026-03" }
    when "orgs/projects#export_days_csv" then { month: "2026-03", member_id: colleague.id }
    when "orgs/participants#create" then { participant: { member_id: create(:member, org:).id, role: "observer" } }
    when "orgs/participants#update" then { participant: { role: "owner" } }
    when "orgs/access_requests#create" then { access_request: { message: "Please" } }
    when "orgs/access_requests#grant" then { access_request: { role: "observer" } }
    else {}
    end
  end

  def signed_in_user(controller, action)
    return create(:user, :admin) if controller.start_with?("admins/")
    return requester.user if "#{controller}##{action}" == "orgs/access_requests#create"

    me.user
  end

  def self.app_routes
    Rails.application.routes.routes.filter_map do |route|
      controller, action = route.defaults.values_at(:controller, :action)
      klass = "#{controller}_controller".camelize.safe_constantize if controller
      next unless klass.is_a?(Class) && klass <= ApplicationController

      [ route.verb.presence || "GET", route.path.spec.to_s.gsub(/\([^()]*\)/, ""), controller, action ]
    end.uniq { |verb, _path, controller, action| [ verb == "PUT" ? "PATCH" : verb, controller, action ] }
  end

  # /dev is routed in development only
  before { allow(DevConstraint).to receive(:matches?).and_return(true) }

  # actions answering in another format too, each one a request of its own
  def self.formats(controller, action)
    { "orgs/tags#index" => %w[csv], "orgs/tag_times#index" => %w[csv] }.fetch("#{controller}##{action}", [])
  end

  app_routes.each do |verb, spec, controller, action|
    [ nil, *formats(controller, action) ].each do |format|
      it "#{verb} #{spec}#{".#{format}" if format} (#{controller}##{action})" do
        sign_in(signed_in_user(controller, action))
        path = spec.gsub(/[:*](\w+)/) { path_value(Regexp.last_match(1), controller).to_s }
        path += ".#{format}" if format

        public_send(verb.downcase, path, params: request_params(controller, action), headers: { "HTTP_REFERER" => root_url })

        expect(response).not_to have_http_status(:not_found) unless action == "error_404"
        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end
end
