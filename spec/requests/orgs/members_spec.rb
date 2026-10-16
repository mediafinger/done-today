require "rails_helper"

# Who may do what is covered by spec/requests/authorization_matrix_spec.rb,
#   this is what an org owner sees and changes.
#
RSpec.describe "Orgs::Members" do
  let(:org) { create(:org) }
  let(:owner) { create(:member, :owner, org:, name: "Olivia") }
  let(:colleague) { create(:member, org:, name: "Carl") }

  def page
    Nokogiri::HTML(response.body)
  end

  def row_of(member)
    page.at_css("##{ActionView::RecordIdentifier.dom_id(member)}")
  end

  before { sign_in(owner.user) }

  describe "GET /:org/members" do
    it "lists the active members with email and role" do
      colleague

      get members_path(org)

      expect(row_of(colleague).text).to include("Carl", colleague.user.email)
      expect(row_of(colleague).css("option[selected]").pluck("value")).to eq(%w[member])
      expect(row_of(owner).css("option[selected]").pluck("value")).to eq(%w[owner])
    end

    it "gives each row's role select its own id" do
      colleague

      get members_path(org)

      ids = page.css("#active-members select").pluck("id")
      expect(ids.size).to eq(2)
      expect(ids.uniq.size).to eq(ids.size)
    end

    it "lists the deactivated members apart, to reactivate them" do
      archived = create(:member, org:, name: "Ada").tap(&:archive!)

      get members_path(org)

      expect(page.at_css("#archived-members").text).to include("Ada")
      expect(page.at_css("#active-members").text).not_to include("Ada")
      expect(row_of(archived).at_css("form")["action"]).to eq(reactivate_member_path(org, archived))
    end

    it "does not list members of other orgs" do
      create(:member, name: "Stranger")

      get members_path(org)

      expect(response.body).not_to include("Stranger")
    end

    it "is linked from the settings page" do
      get org_settings_path(org)

      expect(page.css("a").pluck("href")).to include(members_path(org))
    end
  end

  it "is not linked from the settings page of a member who is not an owner" do
    sign_in(colleague.user)

    get org_settings_path(org)

    expect(page.css("a").pluck("href")).not_to include(members_path(org))
  end

  describe "PATCH /:org/members/:id" do
    it "makes a member an owner and back" do
      patch member_path(org, colleague), params: { member: { role: "owner" } }

      expect(response).to redirect_to(members_path(org))
      expect(flash[:notice]).to eq("Updated the role of Carl")
      expect(colleague.reload.role).to eq("owner")

      patch member_path(org, colleague), params: { member: { role: "member" } }

      expect(colleague.reload.role).to eq("member")
    end

    it "refuses an unknown role" do
      patch member_path(org, colleague), params: { member: { role: "wizard" } }

      expect(response).to redirect_to(members_path(org))
      expect(flash[:alert]).to include("wizard")
      expect(colleague.reload.role).to eq("member")
    end

    it "refuses to take the role" do
      patch member_path(org, colleague), params: { member: { role: "" } }

      expect(flash[:alert]).to be_present
      expect(colleague.reload.role).to eq("member")
    end

    it "refuses to demote the last owner" do
      patch member_path(org, owner), params: { member: { role: "member" } }

      expect(response).to redirect_to(members_path(org))
      expect(flash[:alert]).to eq("#{org.name} needs at least one active owner")
      expect(owner.reload.role).to eq("owner")
    end

    it "lets an owner step down when another one is left, and sends them away" do
      create(:member, :owner, org:)

      patch member_path(org, owner), params: { member: { role: "member" } }

      expect(owner.reload.role).to eq("member")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /:org/members/:id/deactivate" do
    it "archives the member and keeps their entries" do
      project = create(:project, org:)
      create(:participant, project:, member: colleague)
      entry = create(:entry, member: colleague, day: create(:day, project:))

      patch deactivate_member_path(org, colleague)

      expect(response).to redirect_to(members_path(org))
      expect(flash[:notice]).to eq("Deactivated Carl, their entries stay")
      expect(colleague.reload).to be_archived
      expect(Entry.exists?(entry.id)).to be(true)
      expect(colleague.participations.count).to eq(1)
    end

    it "refuses to deactivate the last owner" do
      patch deactivate_member_path(org, owner)

      expect(flash[:alert]).to eq("#{org.name} needs at least one active owner")
      expect(owner.reload).not_to be_archived
    end

    it "lets an owner deactivate themselves when another one is left" do
      create(:member, :owner, org:)

      patch deactivate_member_path(org, owner)

      expect(owner.reload).to be_archived
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /:org/members/:id/reactivate" do
    it "gives the member access back" do
      colleague.archive!

      patch reactivate_member_path(org, colleague)

      expect(response).to redirect_to(members_path(org))
      expect(flash[:notice]).to eq("Reactivated Carl")
      expect(colleague.reload).not_to be_archived
    end
  end
end
