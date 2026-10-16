require "rails_helper"

# Who may do what is covered by spec/requests/authorization_matrix_spec.rb,
#   this is what a manager sees: everything an owner sees, without the owner role.
#
RSpec.describe "Org managers" do
  let(:org) { create(:org) }
  let!(:owner) { create(:member, :owner, org:, name: "Olivia") }
  let(:manager) { create(:member, :manager, org:, name: "Mia") }
  let(:colleague) { create(:member, org:, name: "Carl") }

  def page
    Nokogiri::HTML(response.body)
  end

  def row_of(record)
    page.at_css("##{ActionView::RecordIdentifier.dom_id(record)}")
  end

  before { sign_in(manager.user) }

  describe "GET /:org/members" do
    before do
      colleague
      get members_path(org)
    end

    it "offers every role but owner for a member" do
      expect(row_of(colleague).css("select option").pluck("value")).to eq(%w[guest member manager])
      expect(row_of(colleague).at_css("form[action='#{deactivate_member_path(org, colleague)}']")).to be_present
    end

    it "shows an owner's role without a way to change or deactivate them" do
      expect(row_of(owner).text).to include("owner")
      expect(row_of(owner).css("form")).to be_empty
    end

    it "invites as anything but owner" do
      expect(page.css("#new-invitation select#invitation_role option").pluck("value")).to eq(%w[guest member manager])
    end
  end

  it "lists an owner's pending invitation without resend or revoke" do
    invitation = org.invitations.create!(email: "boss@example.com", role: "owner")

    get members_path(org)

    expect(row_of(invitation).text).to include("boss@example.com", "owner")
    expect(row_of(invitation).css("form")).to be_empty
  end

  it "lists the other pending invitations with resend and revoke" do
    invitations = [ org.invitations.create!(email: "carl@example.com", role: "manager"), create(:invitation, :guest, org:) ]

    get members_path(org)

    invitations.each do |invitation|
      expect(row_of(invitation).css("form").pluck("action"))
        .to eq([ resend_invitation_path(org, invitation), invitation_path(org, invitation) ])
    end
  end

  it "shows a deactivated owner without reactivating them" do
    archived = create(:member, :owner, org:, name: "Ada").tap(&:archive!)

    get members_path(org)

    expect(row_of(archived).text).to include("Ada")
    expect(row_of(archived).css("form")).to be_empty
  end

  it "makes a member a manager" do
    patch member_path(org, colleague), params: { member: { role: "manager" } }

    expect(response).to redirect_to(members_path(org))
    expect(colleague.reload).to be_manager
  end

  it "sends a manager who stepped down away, like an owner" do
    patch member_path(org, manager), params: { member: { role: "member" } }

    expect(response).to redirect_to(root_path)
    expect(manager.reload).to be_member
  end

  it "opens the new project form" do
    get new_project_path(org)

    expect(response).to have_http_status(:ok)
  end

  context "with an owner signed in" do
    before { sign_in(owner.user) }

    it "offers the owner role" do
      colleague

      get members_path(org)

      expect(row_of(colleague).css("select option").pluck("value")).to eq(%w[guest member manager owner])
      expect(page.css("#new-invitation select#invitation_role option").pluck("value")).to eq(%w[guest member manager owner])
    end
  end
end
