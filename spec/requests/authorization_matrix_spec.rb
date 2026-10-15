require "rails_helper"

# Every endpoint against every role, for one project P of one org.
#
#   outsider       member of another org, which is the org they have open
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
  # cells that do not hold yet, with the P1 bullet that fixes them
  def self.gaps = {
    [ "POST /entries", :observer ] => "observer on create",
    [ "GET /entries?mode=edit&project_id=", :observer ] => "observer on create",
    [ "GET /entries?mode=edit&project_id=", :org_owner ] => "observer on create",
    [ "GET /entries?mode=edit&project_id=", :member ] => "project read access",
    [ "GET /entries?project_id=", :member ] => "project read access",
    [ "GET /projects/:slug", :member ] => "project read access",
    [ "GET /projects/:slug/validate_times", :member ] => "project read access",
    [ "GET /projects", :member ] => "project read access",
    [ "GET /settings", :member ] => "project read access"
  }

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

  def link_to_project?
    Nokogiri::HTML(response.body).css("main a").any? { it["href"] == project_path(project.slug) }
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

  # one example per persona: sign in, open the org (and P, where it can be opened),
  #   send the request, check the outcome
  def self.row(name, outcomes, written: nil, &request)
    describe name do
      outcomes.each do |persona, outcome|
        it "#{persona}: #{outcome}", persona:, **{ pending: gaps[[ name, persona ]] }.compact do
          sign_in(me.user)
          get open_path(me.org.slug, project.slug)

          instance_exec(&request)

          expect_outcome(outcome, written)
        end
      end
    end
  end

  row "GET /open/:org", { outsider: :redirect } do
    get open_path(org.slug)

    expect(flash[:alert]).to eq("You are not a member of this org")
  end

  row "GET /projects", {
    outsider: :hidden, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed, org_owner: :listed
  } do
    get projects_path
  end

  row "GET /settings", {
    outsider: :hidden, member: :hidden, observer: :listed, participant: :listed, project_owner: :listed, org_owner: :listed
  } do
    get settings_path
  end

  row "GET /projects/:slug", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get project_path(project.slug)
  end

  row "GET /projects/:slug/validate_times", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get validate_times_project_path(project.slug)
  end

  row "GET /projects/:slug/export_csv", {
    outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_csv_project_path(project.slug, month: "2026-03")
  end

  row "GET /projects/:slug/export_days_csv", {
    outsider: :not_found, member: :not_found, observer: :not_found, participant: :not_found,
    project_owner: :ok, org_owner: :ok
  } do
    get export_days_csv_project_path(project.slug, month: "2026-03", member_id: colleagues_entry.member_id)
  end

  row "GET /entries?project_id=", {
    outsider: :not_found, member: :not_found, observer: :ok, participant: :ok, project_owner: :ok, org_owner: :ok
  } do
    get entries_path(project_id: project.id, mode: "read")
  end

  row "GET /entries?mode=edit&project_id=", {
    outsider: :not_found, member: :not_found, observer: :read_only, participant: :form, project_owner: :form,
    org_owner: :read_only
  } do
    get entries_path(project_id: project.id, mode: "edit")
  end

  # only a participation selects P as the current project, everyone else is sent to pick one
  row "POST /entries", {
    outsider: :redirect, member: :redirect, observer: :forbidden, participant: :written, project_owner: :written,
    org_owner: :redirect
  }, written: -> { Entry.exists?(log: "Logged by the matrix") } do
    post entries_path, params: { entry: { date: Time.zone.today.iso8601, log: "Logged by the matrix" } }
  end

  row "PATCH a colleague's entry", {
    outsider: :redirect, member: :redirect, observer: :forbidden, participant: :forbidden, project_owner: :written,
    org_owner: :redirect
  }, written: -> { colleagues_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(colleagues_entry), params: { entry: { log: "Changed by the matrix" } }
  end

  # an observer may have entries from before they became one
  row "PATCH an own entry", {
    observer: :forbidden, participant: :written, project_owner: :written
  }, written: -> { own_entry.reload.log == "Changed by the matrix" } do
    patch entry_path(own_entry), params: { entry: { log: "Changed by the matrix" } }
  end
end
