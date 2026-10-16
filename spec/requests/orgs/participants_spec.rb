require "rails_helper"

# Who may do what is covered by spec/requests/authorization_matrix_spec.rb,
#   this is what an org owner or a project owner sees and changes.
#
RSpec.describe "Orgs::Participants" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:owner) { create(:member, :owner, org:) }
  let(:carl) { create(:member, org:, name: "Carl") }
  let(:anna) { create(:participant, project:, member: create(:member, org:, name: "Anna")) }

  def page
    Nokogiri::HTML(response.body)
  end

  def candidates
    page.css("#new-participant select[name='participant[member_id]'] option").map(&:text)
  end

  def row_of(participant)
    page.at_css("##{ActionView::RecordIdentifier.dom_id(participant)}")
  end

  before { sign_in(owner.user) }

  describe "GET /:org/:project/edit" do
    it "lists the participants with their role" do
      anna

      get edit_project_path(org, project)

      expect(row_of(anna).text).to include("Anna")
      expect(row_of(anna).at_css("select option[selected]")["value"]).to eq("participant")
    end

    it "offers the active members of the org who do not take part yet" do
      anna
      carl
      create(:member, org:, name: "Dora").tap(&:archive!)
      create(:member, name: "Stranger")

      get edit_project_path(org, project)

      expect(candidates).to include("Carl", owner.name)
      expect(candidates).not_to include("Anna", "Dora", "Stranger")
    end

    it "marks a deactivated participant" do
      create(:member, :owner, org:)
      anna.member.archive!

      get edit_project_path(org, project)

      expect(row_of(anna).text).to include("Anna (deactivated)")
    end
  end

  describe "POST /:org/:project/participants" do
    it "adds a member with a role" do
      post participants_path(org, project), params: { participant: { member_id: carl.id, role: "observer" } }

      expect(project.participants.find_by!(member: carl).roles).to eq(%w[observer])
      expect(response).to redirect_to(edit_project_path(org, project))
      expect(flash[:notice]).to eq("Added Carl as observer")
    end

    it "lets an org owner add themselves, to log time in the project" do
      post participants_path(org, project), params: { participant: { member_id: owner.id, role: "owner" } }

      expect(ProjectPolicy.new(project, member: owner).apply(:create_entry?)).to be(true)
    end

    it "refuses an unknown role" do
      post participants_path(org, project), params: { participant: { member_id: carl.id, role: "wizard" } }

      expect(project.participants.exists?(member: carl)).to be(false)
      expect(flash[:alert]).to include("wizard")
    end

    it "refuses someone who already takes part" do
      post participants_path(org, project), params: { participant: { member_id: anna.member_id, role: "owner" } }

      expect(anna.reload.roles).to eq(%w[participant])
      expect(flash[:alert]).to be_present
    end

    it "does not add a deactivated member" do
      carl.archive!

      post participants_path(org, project), params: { participant: { member_id: carl.id, role: "participant" } }

      expect(response).to have_http_status(:not_found)
      expect(project.participants.exists?(member: carl)).to be(false)
    end

    it "does not add a member of another org" do
      stranger = create(:member)

      post participants_path(org, project), params: { participant: { member_id: stranger.id, role: "participant" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /:org/:project/participants/:id" do
    it "changes the role" do
      patch participant_path(org, project, anna), params: { participant: { role: "owner" } }

      expect(anna.reload.roles).to eq(%w[owner])
      expect(response).to redirect_to(edit_project_path(org, project))
      expect(flash[:notice]).to eq("Anna is now owner")
    end

    it "does not touch a participant of another project" do
      elsewhere = create(:participant, project: create(:project, org:))

      patch participant_path(org, project, elsewhere), params: { participant: { role: "owner" } }

      expect(response).to have_http_status(:not_found)
      expect(elsewhere.reload.roles).to eq(%w[participant])
    end

    it "sends a project owner who stepped down to the project page" do
      me = create(:participant, :owner, project:)
      sign_in(me.member.user)

      patch participant_path(org, project, me), params: { participant: { role: "participant" } }

      expect(response).to redirect_to(project_path(org, project))
    end
  end

  describe "DELETE /:org/:project/participants/:id" do
    it "removes the participant and keeps their entries in the project" do
      create(:entry, day: create(:day, project:), member: anna.member, log: "Work by Anna")

      delete participant_path(org, project, anna)

      expect(Participant.exists?(anna.id)).to be(false)
      expect(response).to redirect_to(edit_project_path(org, project))
      expect(flash[:notice]).to eq("Removed Anna, their entries stay")

      get project_path(org, project)

      expect(response.body).to include("Work by Anna")
    end

    it "takes the access of the removed member" do
      delete participant_path(org, project, anna)
      sign_in(anna.member.user)

      get project_path(org, project)

      expect(response).to have_http_status(:not_found)
    end

    it "sends a project owner who removed themselves to the org" do
      me = create(:participant, :owner, project:)
      sign_in(me.member.user)

      delete participant_path(org, project, me)

      expect(response).to redirect_to(org_path(org))
    end
  end
end
