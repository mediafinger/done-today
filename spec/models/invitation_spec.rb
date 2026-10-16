require "rails_helper"

RSpec.describe Invitation do
  include ActiveSupport::Testing::TimeHelpers

  let(:org) { create(:org) }
  let(:invitation) { create(:invitation, org:, email: "ada@example.com") }

  describe "validations" do
    it "stores the email normalized" do
      expect(create(:invitation, email: " Ada@Example.COM ").email).to eq("ada@example.com")
    end

    it "refuses a role that is no org role" do
      expect(build(:invitation, role: "participant")).not_to be_valid
    end

    it "refuses an email that is already an active member of the org" do
      create(:member, org:, user: create(:user, email: "ada@example.com"))

      invitation = build(:invitation, org:, email: "ada@example.com")

      expect(invitation).not_to be_valid
      expect(invitation.errors.full_messages).to include("ada@example.com is already a member")
    end

    it "accepts the email of a member of another org" do
      create(:member, user: create(:user, email: "ada@example.com"))

      expect(build(:invitation, org:, email: "ada@example.com")).to be_valid
    end

    it "refuses a second pending invitation for the same email and org" do
      invitation

      expect(build(:invitation, org:, email: "ada@example.com")).not_to be_valid
    end

    it "accepts a new invitation once the previous one was accepted" do
      invitation.update!(accepted_at: Time.current)

      expect(build(:invitation, org:, email: "ada@example.com")).to be_valid
    end
  end

  describe "guest invitations" do
    let(:project) { create(:project, org:) }

    it "need a project and a project role" do
      invitation = build(:invitation, org:, role: "guest")

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names).to include(:project, :project_role)
    end

    it "refuse a project of another org" do
      expect(build(:invitation, :guest, org:, project: create(:project))).not_to be_valid
    end

    it "refuse an archived project" do
      expect(build(:invitation, :guest, org:, project: create(:project, org:).tap(&:archive!))).not_to be_valid
    end

    # guests never lead a project
    it "refuse the project role lead" do
      expect(build(:invitation, :guest, org:, project:, project_role: "lead")).not_to be_valid
    end

    it "keep members and owners out of a project" do
      expect(build(:invitation, org:, project:, project_role: "participant")).not_to be_valid
    end

    it "accept somebody who is already active in the org, but not yet in the project" do
      member = create(:member, :guest, org:)
      create(:participant, member:, project: create(:project, org:))

      expect(build(:invitation, :guest, org:, project:, email: member.user.email)).to be_valid
    end

    it "refuse somebody who already participates in the project" do
      member = create(:participant, project:).member

      invitation = build(:invitation, :guest, org:, project:, email: member.user.email)

      expect(invitation).not_to be_valid
      expect(invitation.errors[:base]).to include("#{member.user.email} already participates in #{project.name}")
    end
  end

  describe "the acceptance token" do
    let(:token) { invitation.generate_token_for(:acceptance) }

    it "finds the invitation" do
      expect(described_class.find_by_token_for(:acceptance, token)).to eq(invitation)
    end

    it "expires after #{described_class::EXPIRES_IN.inspect}" do
      token

      travel(described_class::EXPIRES_IN + 1.second) do
        expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
      end
    end

    it "is used up once the invitation is accepted" do
      token
      invitation.accept!(create(:user, email: "ada@example.com"))

      expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
    end

    it "dies when the invitation is resent" do
      token

      travel(1.minute) { invitation.update!(sent_at: Time.current) }

      expect(described_class.find_by_token_for(:acceptance, token)).to be_nil
      expect(described_class.find_by_token_for(:acceptance, invitation.generate_token_for(:acceptance))).to eq(invitation)
    end

    it "refuses a tampered token" do
      tampered = token.sub(/.\z/) { it == "A" ? "B" : "A" }

      expect(described_class.find_by_token_for(:acceptance, tampered)).to be_nil
    end

    it "refuses another purpose's token" do
      user = create(:user)

      expect(described_class.find_by_token_for(:acceptance, user.generate_token_for(:password_reset))).to be_nil
    end
  end

  describe "#accept!" do
    let(:user) { create(:user, email: "ada@example.com", name: "Ada Lovelace") }

    it "creates the member with the invited role" do
      invitation.update!(role: "owner")

      member = invitation.accept!(user)

      expect(member).to have_attributes(org:, user:, role: "owner", name: "Ada Lovelace")
      expect(invitation.reload).to be_accepted
    end

    it "reactivates an archived member of the same user instead of adding a second one" do
      archived = create(:member, org:, user:, role: "owner")
      create(:member, :owner, org:)
      archived.archive!

      expect(invitation.accept!(user)).to eq(archived)
      expect(archived.reload).to have_attributes(archived_at: nil, role: "member")
    end

    it "leaves the role of a member who joined after the invitation was sent" do
      invitation
      member = create(:member, :owner, org:, user:)

      expect(invitation.accept!(user)).to eq(member)
      expect(member.reload.role).to eq("owner")
      expect(invitation.reload).to be_accepted
    end

    describe "of a guest" do
      let(:project) { create(:project, org:) }
      let(:invitation) { create(:invitation, :guest, org:, project:, project_role: "observer", email: "ada@example.com") }

      it "creates the guest together with their participation" do
        member = invitation.accept!(user)

        expect(member).to have_attributes(role: "guest", archived_at: nil)
        expect(member.participations.sole).to have_attributes(project:, role: "observer")
      end

      it "reactivates an archived member as guest of the project" do
        create(:member, :owner, org:)
        archived = create(:member, org:, user:).tap(&:archive!)

        expect(invitation.accept!(user)).to eq(archived)
        expect(archived.reload).to have_attributes(role: "guest", archived_at: nil, projects: [ project ])
      end

      # never a downgrade: an internal only gains the project
      it "adds the project to an active member, who keeps their role" do
        member = create(:member, org:, user:)
        invitation

        invitation.accept!(user)

        expect(member.reload).to have_attributes(role: "member", projects: [ project ])
      end
    end

    it "refuses an account with another email" do
      expect { invitation.accept!(create(:user)) }.to raise_error(ArgumentError)
    end

    it "accepts only once" do
      invitation.accept!(user)

      expect { described_class.find(invitation.id).accept!(user) }.to raise_error(described_class::AlreadyAccepted)
    end
  end

  it "is deleted with its org" do
    create(:invitation, org:, invited_by: create(:member, :owner, org:))

    expect { org.destroy! }.to change(described_class, :count).by(-1)
  end
end
