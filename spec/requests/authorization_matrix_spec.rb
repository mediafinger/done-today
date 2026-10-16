require "rails_helper"

# Every endpoint against every role, for one project P of one org. Org and project
#   are part of every path, so nothing is selected beforehand.
#
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
      org_owner: create(:member, :owner, org:)
    }
  end

  # the persona of the running example
  def me
    personas.fetch(RSpec.current_example.metadata[:persona])
  end

  # a member of the org who is none of the personas
  def colleague
    colleagues_entry.member
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
          sign_in(me.user)

          instance_exec(&request)

          expect_outcome(outcome, written)
        end
      end
    end
  end

  row "GET /:org (its projects)", {
    outsider: :not_found, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed,
    org_owner: :listed
  } do
    get org_path(org)
  end

  row "GET /:org/settings", {
    outsider: :not_found, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed,
    org_owner: :listed
  } do
    get org_settings_path(org)
  end

  row "GET /:org/:project", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get project_path(org, project)
  end

  # a project is only found below the slug of its own org
  row "GET /:own_org/:project of another org", { outsider: :not_found } do
    get project_path(me.org, project)
  end

  row "GET /:org/:project/validate_times", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get validate_times_project_path(org, project)
  end

  row "GET /:org/:project/export_csv", {
    outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_csv_project_path(org, project, month: "2026-03")
  end

  row "GET /:org/:project/export_days_csv", {
    outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_days_csv_project_path(org, project, month: "2026-03", member_id: colleagues_entry.member_id)
  end

  row "GET /:org/:project/days/:date", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    colleagues_entry # the day exists

    get day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/days/:date/edit", {
    outsider: :not_found, member: :not_found, observer: :read_only, participant: :form, project_owner: :form,
    org_owner: :read_only
  } do
    colleagues_entry # the day exists

    get edit_day_path(org, project, Time.zone.today)
  end

  row "GET /:org/:project/tags/:tag", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get tag_path(org, project, "handover")
  end

  row "GET /:org/:project/weeks/:week", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get week_path(org, project, "2026-W38")
  end

  row "GET /:org/:project/members/:id/entries", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get member_entries_path(org, project, colleague)
  end

  row "POST /:org/:project/entries", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :written, project_owner: :written,
    org_owner: :forbidden
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    post entries_path(org, project), params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH /:org/:project/entries/:id of a colleague", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
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
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :ok,
    org_owner: :ok
  } do
    get entry_history_path(org, project, colleagues_entry)
  end

  row "GET /:org/members", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :ok
  } do
    get members_path(org)
  end

  row "PATCH /:org/members/:id", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.roles.include?("owner") } do
    patch member_path(org, colleague), params: { member: { roles: %w[member owner] } }
  end

  row "PATCH /:org/members/:id/deactivate", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { colleague.reload.archived? } do
    patch deactivate_member_path(org, colleague)
  end

  row "PATCH /:org/members/:id/reactivate", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { !colleague.reload.archived? } do
    colleague.archive!

    patch reactivate_member_path(org, colleague)
  end

  row "GET /:org/projects/new", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :ok
  } do
    get new_project_path(org)
  end

  row "POST /:org/projects", {
    outsider: :not_found, member: :forbidden, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
    org_owner: :written
  }, written: -> { org.projects.exists?(name: "Created by the matrix") } do
    post projects_path(org), params: { project: { name: "Created by the matrix" } }
  end

  row "GET /:org/:project/edit", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :ok,
    org_owner: :ok
  } do
    get edit_project_path(org, project)
  end

  row "PATCH /:org/:project (rename)", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.reload.name == "Renamed by the matrix" } do
    patch project_path(org, project), params: { project: { name: "Renamed by the matrix" } }
  end

  row "PATCH /:org/:project/archive", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.reload.archived? } do
    patch archive_project_path(org, project)
  end

  row "PATCH /:org/:project/unarchive", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { !project.reload.archived? } do
    project.archive!

    patch unarchive_project_path(org, project)
  end

  row "POST /:org/:project/participants", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { project.participants.exists?(member: personas[:member]) } do
    post participants_path(org, project), params: { participant: { member_id: personas[:member].id, role: "observer" } }
  end

  row "PATCH /:org/:project/participants/:id", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { colleague.participations.find_by!(project:).roles == %w[owner] } do
    patch participant_path(org, project, colleague.participations.find_by!(project:)), params: { participant: { role: "owner" } }
  end

  # the colleague's entries stay, see spec/requests/orgs/participants_spec.rb
  row "DELETE /:org/:project/participants/:id", {
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :written
  }, written: -> { !colleague.participations.exists?(project:) } do
    delete participant_path(org, project, colleague.participations.find_by!(project:))
  end

  # an archived project is read-only for everybody, listed only for those who manage it
  row "GET /:org (its projects) with P archived", {
    outsider: :not_found, member: :hidden, observer: :hidden, participant: :hidden, project_owner: :listed,
    org_owner: :listed
  } do
    project.archive!

    get org_path(org)
  end

  row "GET /:org/:project archived", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
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
    outsider: :not_found, member: :not_found, observer: :forbidden, participant: :forbidden, project_owner: :forbidden,
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
    outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
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
