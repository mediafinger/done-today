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
      expect(project_item.text).to include("ask Pat to join")
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
end
