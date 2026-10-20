require "rails_helper"

RSpec.describe "Users::AccessTokens" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:user) { member.user }

  before do
    create(:participant, project:, member:)
    sign_in(user)
  end

  def page = Nokogiri::HTML(response.body)

  def personal_token(name: "Laptop", **grant)
    create(:connection, user:, name:).tap do |connection|
      create(:connection_grant, connection:, org:, **grant)
      connection.create_access_token!(expires_in: 30.days)
    end
  end

  describe "GET /user/access_tokens" do
    it "lists the user's active tokens with their grants" do
      personal_token(name: "Laptop", access: "write")
      personal_token(name: "Old one").revoke!
      create(:connection, user: create(:user), name: "Stranger's")

      get user_access_tokens_path

      expect(response).to have_http_status(:ok)
      rows = page.css("#access-tokens tbody tr")
      expect(rows.size).to eq(1)
      expect(rows.text).to include("Laptop", org.name)
      expect(response.body).not_to include("Old one", "Stranger's")
    end

    it "marks a grant that has no effect any more" do
      personal_token(project:)
      member.participations.destroy_all

      get user_access_tokens_path

      expect(page.at_css("#access-tokens s")).to be_present
    end

    it "offers the user's orgs and projects to grant, and no others" do
      other_org = create(:org)

      get user_access_tokens_path

      form = page.at_css("form#new-access-token")
      expect(form.at_css("select[name='grants[orgs][#{org.id}]']")).to be_present
      expect(form.at_css("select[name='grants[projects][#{project.id}]']")).to be_present
      expect(form.to_s).not_to include(other_org.id)
    end
  end

  describe "POST /user/access_tokens" do
    def create_token(grants: { projects: { project.id => "write" } }, expires_in_days: "90")
      post user_access_tokens_path, params: { connection: { name: "Claude Code" }, expires_in_days:, grants: }
    end

    it "creates the token and shows its secret once" do
      expect { create_token }.to change(Connection, :count).by(1)

      expect(response).to have_http_status(:created)
      secret = page.at_css("#access-token-secret").text.strip
      connection = Connection.authenticate(secret)
      expect(connection).to have_attributes(user:, name: "Claude Code", oauth_application_id: nil)
      expect(connection.grants).to contain_exactly(have_attributes(org_id: org.id, project_id: project.id, access: "write"))
      expect(connection.access_tokens.sole.expires_in).to eq(90.days.to_i)
    end

    it "keeps the page with the secret out of caches" do
      create_token

      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "grants an org" do
      create_token(grants: { orgs: { org.id => "read" } })

      expect(Connection.last.grants).to contain_exactly(have_attributes(org_id: org.id, project_id: nil, access: "read"))
    end

    it "drops orgs and projects the user doesn't take part in" do
      foreign = create(:project)

      create_token(grants: { orgs: { foreign.org_id => "write" }, projects: { project.id => "read", foreign.id => "write" } })

      expect(Connection.last.grants).to contain_exactly(have_attributes(project_id: project.id))
    end

    it "refuses a token without a grant" do
      expect { create_token(grants: { projects: { project.id => "" } }) }.not_to change(Connection, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses an expiry that isn't offered" do
      expect { create_token(expires_in_days: "3650") }.not_to change(Connection, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /user/access_tokens/:id" do
    it "revokes the token" do
      connection = personal_token

      delete user_access_token_path(connection)

      expect(response).to redirect_to(user_access_tokens_path)
      expect(connection.reload).to be_revoked
    end

    it "can't revoke another user's token" do
      connection = create(:connection)

      delete user_access_token_path(connection)

      expect(response).to have_http_status(:not_found)
      expect(connection.reload).not_to be_revoked
    end
  end

  describe "DELETE /user/access_tokens/destroy_all" do
    it "revokes all of the user's connections and their tokens" do
      tokens = [ personal_token, personal_token ]
      stranger = create(:connection)

      delete destroy_all_user_access_tokens_path

      expect(response).to redirect_to(user_access_tokens_path)
      expect(tokens.map { it.reload.revoked? }).to eq([ true, true ])
      expect(Doorkeeper::AccessToken.where(connection_id: tokens).map(&:revoked?)).to all(be(true))
      expect(stranger.reload).not_to be_revoked
    end
  end

  it "is linked from the account page" do
    get edit_user_path

    expect(page.at_css("a[href='#{user_access_tokens_path}']")).to be_present
  end
end
