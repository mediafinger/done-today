require "rails_helper"
require "rake"

RSpec.describe "done:org:create" do
  subject(:task) { Rake::Task["done:org:create"] }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("done:org:create")
    ActionMailer::Base.deliveries.clear
  end

  def run(**env)
    env = env.transform_keys(&:to_s)
    ENV.update(env)
    task.reenable # tasks only run once per process
    task.invoke
  ensure
    env.each_key { ENV.delete(it) }
  end

  context "with a new email" do
    it "creates the org and invites the email as its owner, and prints the link" do
      expect { run(NAME: "Acme", OWNER_EMAIL: "Ada@Example.com", OWNER_NAME: "Ada") }
        .to output(%r{Created Acme at /acme.*Invited ada@example.com as owner.*/invitations/}m).to_stdout

      org = Org.find_by!(name: "Acme")
      expect(org.invitations.sole).to have_attributes(email: "ada@example.com", name: "Ada", role: "owner")
      expect(org.members).to be_empty
      expect(User.exists?(email: "ada@example.com")).to be(false)
    end

    it "mails the link" do
      expect { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com") }.to output.to_stdout

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "ada@example.com" ] ])
    end

    it "prints a link that finds the invitation" do
      output = capture_stdout { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com") }
      token = output[%r{/invitations/(\S+)}, 1]

      expect(Invitation.find_by_token_for(:acceptance, CGI.unescape(token))).to eq(Org.find_by!(name: "Acme").invitations.sole)
    end

    it "sends a new link when run again, keeping the name" do
      expect { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com", OWNER_NAME: "Ada") }.to output.to_stdout
      expect { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com") }.to output(/Acme exists at/).to_stdout

      expect(Org.find_by!(name: "Acme").invitations.sole.name).to eq("Ada")
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end
  end

  context "with an existing account" do
    let!(:ada) { create(:user, email: "ada@example.com") }

    it "makes the account an owner right away, without a mail" do
      expect { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com") }.to output(/ada@example.com is an owner of Acme/).to_stdout

      expect(Org.find_by!(name: "Acme").members.sole).to have_attributes(user: ada, role: "owner")
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "promotes or reactivates them in an existing org" do
      org = create(:org, name: "Acme")
      create(:member, :owner, org:)
      member = create(:member, org:, user: ada).tap(&:archive!)

      expect { run(NAME: "Acme", OWNER_EMAIL: "ada@example.com") }.to output(/Acme exists/).to_stdout

      expect(member.reload).to have_attributes(role: "owner", archived_at: nil)
      expect(Org.where(name: "Acme").count).to eq(1)
    end
  end

  it "refuses without NAME or OWNER_EMAIL" do
    expect { run(NAME: "Acme") }.to raise_error(SystemExit).and output(/OWNER_EMAIL/).to_stderr

    expect(Org.exists?(name: "Acme")).to be(false)
  end

  it "creates nothing for an invalid email" do
    expect { run(NAME: "Acme", OWNER_EMAIL: "not an email") }.to raise_error(SystemExit).and output(/valid email/).to_stderr

    expect(Org.exists?(name: "Acme")).to be(false)
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
