require "rails_helper"

RSpec.describe Connection do
  include ActiveSupport::Testing::TimeHelpers

  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:user) { create(:user) }
  let(:connection) { create(:connection, user:) }

  def grant(access = "read", project: nil, org: self.org)
    create(:connection_grant, connection:, org:, project:, access:)
  end

  describe "#access_for" do
    let(:member) { create(:member, org:, user:) }

    def participate(role)
      create(:participant, project:, member:, role:)
    end

    {
      %w[observer read] => :read,
      %w[observer write] => :read,
      %w[participant read] => :read,
      %w[participant write] => :write,
      %w[lead read] => :read,
      %w[lead write] => :write
    }.each do |(role, access), expected|
      it "gives a #{role} with a #{access} grant #{expected} access" do
        participate(role)
        grant(access)

        expect(connection.access_for(project)).to eq(expected)
      end
    end

    %w[guest member manager owner].each do |org_role|
      it "gives a #{org_role} who participates write access" do
        participate("participant")
        member.update!(role: org_role)
        grant("write")

        expect(connection.access_for(project)).to eq(:write)
      end

      it "gives a #{org_role} who doesn't participate no access" do
        create(:participant, project: create(:project, org:), member:) # guests need a project
        member.update!(role: org_role)
        grant("write")

        expect(connection.access_for(project)).to be_nil
      end
    end

    context "with a write grant to a participant" do
      before do
        participate("participant")
        grant("write")
      end

      it "reads only in an archived project" do
        project.archive!

        expect(connection.access_for(project)).to eq(:read)
      end

      it "gives an archived member no access" do
        member.archive!

        expect(connection.access_for(project)).to be_nil
      end

      it "gives no access once the participation is removed" do
        member.participations.destroy_all

        expect(connection.access_for(project)).to be_nil
      end

      it "gives a revoked connection no access" do
        connection.revoke!

        expect(connection.access_for(project)).to be_nil
      end
    end

    context "with a project grant" do
      before { participate("participant") }

      it "covers that project" do
        grant("write", project:)

        expect(connection.access_for(project)).to eq(:write)
      end

      it "doesn't cover another project of the org" do
        grant("write", project: create(:project, org:))

        expect(connection.access_for(project)).to be_nil
      end
    end

    it "doesn't let a grant on another org cover the project" do
      participate("participant")
      grant("write", org: create(:org))

      expect(connection.access_for(project)).to be_nil
    end

    it "takes the strongest grant that covers the project" do
      participate("participant")
      grant("read")
      grant("write", project:)

      expect(connection.access_for(project)).to eq(:write)
    end
  end

  describe "#readable_projects" do
    it "holds the projects access_for gives access to" do
      member = create(:member, org:, user:)
      projects = create_list(:project, 4, org:)
      create(:participant, project: projects[0], member:)
      create(:participant, :observer, project: projects[1], member:)
      create(:participant, project: projects[2], member:)
      grant("read", project: projects[0])
      grant("write", project: projects[1])
      create(:connection_grant, connection:, org: create(:org), access: "write")

      expect(connection.readable_projects).to match_array(Project.all.select { connection.access_for(it) })
      expect(connection.readable_projects).to contain_exactly(projects[0], projects[1])
    end

    it "holds every participated project of an org grant, none once revoked" do
      member = create(:member, org:, user:)
      create(:participant, project:, member:)
      grant("read")

      expect(connection.readable_projects).to contain_exactly(project)

      connection.revoke!
      expect(connection.readable_projects).to be_empty
    end
  end

  describe ".authenticate" do
    let!(:secret) { connection.create_access_token!(expires_in: 1.day) }

    it "finds the connection of a valid secret and notes its use" do
      expect(described_class.authenticate(secret)).to eq(connection)
      expect(connection.reload.last_used_at).to be_within(1.second).of(Time.current)
    end

    it "notes the use at most once a minute" do
      connection.update_column(:last_used_at, 30.seconds.ago)

      expect { described_class.authenticate(secret) }.not_to(change { connection.reload.last_used_at })
    end

    it "stores only a digest of the secret" do
      expect(connection.access_tokens.sole.token).not_to eq(secret)
    end

    it "refuses an unknown, an expired or a revoked secret" do
      expect(described_class.authenticate("done_pat_unknown")).to be_nil

      travel(2.days) { expect(described_class.authenticate(secret)).to be_nil }

      connection.revoke!
      expect(described_class.authenticate(secret)).to be_nil
    end

    it "refuses a secret whose connection is revoked, even with the token still valid" do
      connection.update!(revoked_at: Time.current)

      expect(described_class.authenticate(secret)).to be_nil
    end
  end

  describe "#create_access_token!" do
    it "prefixes a personal access token with done_pat_" do
      expect(connection.create_access_token!(expires_in: 1.day)).to match(/\Adone_pat_[1-9A-HJ-NP-Za-km-z]{44}\z/)
    end

    it "prefixes a token of an OAuth app with done_oat_" do
      app = Doorkeeper::Application.create!(name: "Claude", redirect_uri: "https://claude.ai/callback")
      connection.update!(oauth_application: app)

      expect(connection.create_access_token!(expires_in: 1.hour)).to start_with("done_oat_")
    end
  end

  describe ".revoke_all!" do
    it "revokes the connections of the relation and their tokens, no others" do
      connection.create_access_token!(expires_in: 1.day)
      other = create(:connection)

      user.connections.revoke_all!

      expect(connection.reload).to be_revoked
      expect(connection.access_tokens.sole).to be_revoked
      expect(other.reload).not_to be_revoked
    end
  end

  describe "#revoke!" do
    it "revokes the connection and its tokens" do
      connection.create_access_token!(expires_in: 1.day)

      connection.revoke!

      expect(connection.reload).to be_revoked
      expect(connection.access_tokens.sole).to be_revoked
    end
  end
end
