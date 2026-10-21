require "rails_helper"

RSpec.describe "Mcp write tools" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:access) { "write" }
  let(:secret) { personal_token(member.user, project => access) }

  before do
    host! AppConf.done_host
    create(:participant, :lead, project:, member:)
  end

  def slugs = { org: org.slug, project: project.slug }

  def entry_on(date, by: member)
    create(:entry, day: project.days.find_or_create_by!(org:, date:), member: by, log: "Wrote some code")
  end

  describe "create_entry" do
    it "creates an own entry for today, todo by default, with a history through the connection" do
      data = tool_data(call_tool("create_entry", **slugs, log: "#review the checkout PR"))

      entry = Entry.find(data.dig("entry", "id"))
      expect(entry).to have_attributes(member:, log: "#review the checkout PR", status: "todo", tags: [ "review" ])
      expect(entry.day.date).to eq(Time.zone.today)
      expect(RecordHistory.find_by!(record_id: entry.id).connection_id).to eq(member.user.token_auth_connections.sole.id)
    end

    it "reports the markup it couldn't read, and saves the entry all the same" do
      data = tool_data(call_tool("create_entry", **slugs, log: "start@25:00 Early bird"))

      expect(data["issues"].pluck("code")).to include("invalid_time")
      expect(Entry.count).to eq(1)
    end

    it "keeps a past day locked unless asked to unlock it" do
      yesterday = (Time.zone.today - 1).iso8601

      expect(call_tool("create_entry", **slugs, log: "Logged late", date: yesterday)["isError"]).to be(true)
      expect(call_tool("create_entry", **slugs, log: "Logged late", date: yesterday, unlocked: true)["isError"]).to be(false)
    end

    it "answers an invalid entry with its errors" do
      result = call_tool("create_entry", **slugs, log: "   ")

      expect(result["isError"]).to be(true)
      expect(result.dig("content", 0, "text")).to include("Log")
    end

    it "creates the entry once for the same idempotency key" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      ids = Array.new(2) { tool_data(call_tool("create_entry", **slugs, log: "Only once", idempotency_key: "k1")).dig("entry", "id") }

      expect(ids.uniq.size).to eq(1)
      expect(Entry.count).to eq(1)
    end

    context "with a read grant" do
      let(:access) { "read" }

      it "refuses to write" do
        expect(call_tool("create_entry", **slugs, log: "Not allowed")["isError"]).to be(true)
        expect(Entry.count).to eq(0)
      end
    end

    it "refuses an observer, whatever the grant" do
      member.participations.sole.update!(role: "observer")

      expect(call_tool("create_entry", **slugs, log: "Not allowed")["isError"]).to be(true)
    end
  end

  describe "update_entry" do
    def entry
      @entry ||= entry_on(Time.zone.today)
    end

    def update(**arguments)
      call_tool("update_entry", id: entry.id, updated_at: entry.updated_at.iso8601(6), **arguments)
    end

    it "changes the log and the status of an own entry" do
      data = tool_data(update(log: "Wrote more code", status: "done"))

      expect(entry.reload).to have_attributes(log: "Wrote more code", status: "done")
      expect(data.dig("entry", "updated_at")).to eq(entry.updated_at.iso8601(6))
    end

    it "refuses when the entry changed since it was read" do
      stale = entry.updated_at.iso8601(6)
      entry.update!(log: "Changed in the meantime", updated_at: entry.updated_at + 1.second)

      result = call_tool("update_entry", id: entry.id, updated_at: stale, log: "Overwritten?")

      expect(result["isError"]).to be(true)
      expect(entry.reload.log).to eq("Changed in the meantime")
    end

    it "can't touch a colleague's entry, not even as the lead" do
      colleagues = entry_on(Time.zone.today, by: create(:participant, project:).member)

      result = call_tool("update_entry", id: colleagues.id, updated_at: colleagues.updated_at.iso8601(6), log: "Mine now")

      expect(result["isError"]).to be(true)
      expect(colleagues.reload.log).to eq("Wrote some code")
    end

    it "keeps a past day locked unless asked to unlock it" do
      entry = entry_on(Time.zone.today - 1)
      read = entry.updated_at.iso8601(6)

      expect(call_tool("update_entry", id: entry.id, updated_at: read, status: "done")["isError"]).to be(true)
      expect(call_tool("update_entry", id: entry.id, updated_at: read, status: "done", unlocked: true)["isError"]).to be(false)
    end
  end

  describe "the syntax guide" do
    it "is a resource" do
      mcp("resources/list")
      uri = mcp_result["resources"].sole["uri"]

      mcp("resources/read", { uri: })

      expect(mcp_result.dig("contents", 0, "text")).to include("start@", "for~", "#break")
    end
  end
end
