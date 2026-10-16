require "rails_helper"

# Internals ask to join a project they do not take part in, its leads decide.
#   Who may do what is covered by spec/requests/authorization_matrix_spec.rb.
#
RSpec.describe "Access requests" do
  let(:org) { create(:org, name: "Acme") }
  let(:project) { create(:project, org:, name: "Website") }
  let(:lead) { create(:participant, :lead, project:, member: create(:member, org:, name: "Pat")).member }
  let(:carl) { create(:member, org:, name: "Carl") }

  def page
    Nokogiri::HTML(response.body)
  end

  def project_item
    page.at_css("#active-projects ##{ActionView::RecordIdentifier.dom_id(project)}")
  end

  def request_access(message: "Need the invoices")
    post access_requests_path(org, project), params: { access_request: { message: } }
  end

  describe "POST /:org/:project/access_requests" do
    before do
      lead
      sign_in(carl.user)
    end

    it "stores the request and mails the project's leads" do
      expect { request_access }.to have_enqueued_mail(AccessRequestsMailer, :requested)

      expect(project.access_requests.sole).to have_attributes(member: carl, message: "Need the invoices", status: "pending")
      expect(response).to redirect_to(org_path(org))
      expect(flash[:notice]).to eq("Asked to join Website")
    end

    it "refuses a second pending request" do
      request_access

      expect { request_access }.not_to have_enqueued_mail(AccessRequestsMailer, :requested)

      expect(flash[:alert]).to eq("You already asked to join Website")
      expect(project.access_requests.count).to eq(1)
    end

    it "is rate limited" do
      allow(Orgs::AccessRequestsController.cache_store).to receive(:increment).and_return(11)

      expect { request_access }.not_to have_enqueued_mail(AccessRequestsMailer, :requested)

      expect(response).to redirect_to(org_path(org))
      expect(flash[:alert]).to eq("Too many requests, try again later")
    end
  end

  describe "GET /:org (its projects)" do
    before do
      lead
      sign_in(carl.user)
    end

    it "offers a member to ask to join a project they cannot read" do
      get org_path(org)

      expect(project_item.at_css("form")["action"]).to eq(access_requests_path(org, project))
      expect(project_item.text).to include("ask the project lead Pat, an org manager or owner to join")
    end

    it "shows a pending request instead of the form" do
      create(:access_request, project:, member: carl)

      get org_path(org)

      expect(project_item.at_css("form")).to be_nil
      expect(project_item.text).to include("asked to join on #{Time.zone.today}")
    end

    it "offers the form again after a decline" do
      create(:access_request, project:, member: carl).decline!(by: lead)

      get org_path(org)

      expect(project_item.at_css("form")).to be_present
    end
  end

  describe "deciding" do
    let(:access_request) { create(:access_request, project:, member: carl, message: "Need the invoices") }

    before { sign_in(lead.user) }

    it "lists the pending requests of active members on the project's edit page" do
      access_request
      create(:access_request, project:, member: create(:member, org:, name: "Gone")).member.archive!

      get edit_project_path(org, project)

      rows = page.css("#access-requests tbody tr")
      expect(rows.map { it.at_css("td").text }).to eq([ "Carl" ])
      expect(rows.first.text).to include("Need the invoices")
    end

    it "shows no requests section without pending requests" do
      get edit_project_path(org, project)

      expect(page.at_css("#access-requests")).to be_nil
    end

    describe "PATCH /:org/:project/access_requests/:id/grant" do
      it "adds the member with the chosen role" do
        patch grant_access_request_path(org, project, access_request), params: { access_request: { role: "observer" } }

        expect(project.participants.find_by!(member: carl).role).to eq("observer")
        expect(access_request.reload).to have_attributes(status: "granted", decided_by: lead)
        expect(response).to redirect_to(edit_project_path(org, project))
        expect(flash[:notice]).to eq("Added Carl as observer")
      end

      it "refuses a role that does not exist" do
        patch grant_access_request_path(org, project, access_request), params: { access_request: { role: "admin" } }

        expect(flash[:alert]).to be_present
        expect(access_request.reload).to be_pending
      end

      it "is a 404 for a decided request" do
        access_request.decline!(by: lead)

        patch grant_access_request_path(org, project, access_request), params: { access_request: { role: "participant" } }

        expect(response).to have_http_status(:not_found)
      end

      it "is a 404 for a deactivated member's request" do
        access_request
        carl.archive!

        patch grant_access_request_path(org, project, access_request), params: { access_request: { role: "participant" } }

        expect(response).to have_http_status(:not_found)
        expect(project.participants.where(member: carl)).to be_empty
      end
    end

    describe "PATCH /:org/:project/access_requests/:id/decline" do
      it "declines the request" do
        patch decline_access_request_path(org, project, access_request)

        expect(access_request.reload).to have_attributes(status: "declined", decided_by: lead)
        expect(project.participants.where(member: carl)).to be_empty
        expect(flash[:notice]).to eq("Declined the request of Carl")
      end
    end
  end
end
