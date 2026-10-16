require "rails_helper"

# Members and owners are internals, guests are externals: they see only their
#   own projects and are listed apart. Who may do what is covered by the matrix.
#
RSpec.describe "Org guests" do
  let(:org) { create(:org) }
  let(:owner) { create(:member, :owner, org:, name: "Olivia") }
  let(:website) { create(:project, org:, name: "Website") }
  let(:shop) { create(:project, org:, name: "Shop") }
  let(:carl) { create(:member, org:, name: "Carl") }

  def guest_of(project, name)
    create(:participant, project:, member: create(:member, :guest, org:, name:)).member
  end

  def gina
    @gina ||= guest_of(website, "Gina")
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def project_item(project)
    page.at_css("#active-projects ##{ActionView::RecordIdentifier.dom_id(project)}")
  end

  describe "GET /:org (its projects)" do
    before do
      create(:participant, :owner, project: shop, member: owner)
      create(:participant, project: website, member: carl)
    end

    it "lists every project to a member, linking those they may read, naming the owners of the others" do
      sign_in(carl.user)

      get org_path(org)

      expect(project_item(website).at_css("a")["href"]).to eq(project_path(org, website))
      expect(project_item(shop).at_css("a")).to be_nil
      expect(project_item(shop).text).to include("Shop", "ask Olivia to join")
    end

    it "lists only their own projects to a guest" do
      sign_in(gina.user)

      get org_path(org)

      expect(project_item(website)).to be_present
      expect(project_item(shop)).to be_nil
    end
  end

  describe "GET /:org/members" do
    before do
      owner
      carl
      gina
    end

    it "shows a member the directory read-only, guests apart with their projects" do
      sign_in(carl.user)

      get members_path(org)

      expect(response).to have_http_status(:ok)
      expect(page.css("#active-members tr td:first-child").map(&:text)).to eq([ "Carl (you)", "Olivia" ])
      expect(page.at_css("#guests").text).to include("Gina", "Website")
      expect(page.css("form")).to be_empty
    end

    it "lets an owner change a guest's role like any other" do
      sign_in(owner.user)

      get members_path(org)

      expect(page.at_css("#guests select[name='member[role]'] option[selected]")["value"]).to eq("guest")
    end

    it "refuses a guest" do
      sign_in(gina.user)

      get members_path(org)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /:org/members/:id" do
    before { sign_in(owner.user) }

    it "makes a participating member a guest and back" do
      create(:participant, project: website, member: carl)

      patch member_path(org, carl), params: { member: { role: "guest" } }

      expect(carl.reload).to be_guest

      patch member_path(org, carl), params: { member: { role: "member" } }

      expect(carl.reload).to be_member
    end

    it "refuses to make a member without a project a guest" do
      patch member_path(org, carl), params: { member: { role: "guest" } }

      expect(flash[:alert]).to eq("Role guest has to participate in a project first")
      expect(carl.reload).to be_member
    end
  end

  describe "the participants of a project" do
    def project_owner
      @project_owner ||= create(:participant, :owner, project: shop, member: create(:member, org:, name: "Pat")).member
    end

    def hugo
      @hugo ||= guest_of(website, "Hugo")
    end

    def candidates
      page.css("#new-participant select[name='participant[member_id]'] optgroup").to_h do |group|
        [ group["label"], group.css("option").map(&:text) ]
      end
    end

    before do
      owner
      carl
      hugo
      create(:participant, project: shop, member: gina)
    end

    it "offers a project owner the members and only the guests of their own projects" do
      sign_in(project_owner.user)

      get edit_project_path(org, shop)

      expect(candidates).to eq("Members" => [ "Carl", "Olivia" ])
    end

    it "offers an org owner every guest, apart from the members" do
      sign_in(owner.user)

      get edit_project_path(org, shop)

      expect(candidates).to eq("Members" => [ "Carl", "Olivia" ], "Guests (external)" => [ "Hugo" ])
    end

    it "marks guests in the list of participants" do
      sign_in(owner.user)

      get edit_project_path(org, shop)

      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(gina.participations.find_by!(project: shop))}").text)
        .to include("Gina (guest)")
    end

    it "turns away a project owner adding a guest of another project" do
      sign_in(project_owner.user)

      post participants_path(org, shop), params: { participant: { member_id: hugo.id, role: "participant" } }

      expect(response).to have_http_status(:not_found)
      expect(shop.participants.exists?(member: hugo)).to be(false)
    end

    it "refuses to make a guest a project owner" do
      sign_in(owner.user)

      post participants_path(org, shop), params: { participant: { member_id: hugo.id, role: "owner" } }

      expect(flash[:alert]).to eq("Roles owner is not a project role for guests")
      expect(shop.participants.exists?(member: hugo)).to be(false)
    end
  end
end
