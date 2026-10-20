require "rails_helper"

RSpec.describe "Mcp read tools" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }
  let(:secret) { personal_token(member.user, project => "read") }

  before do
    host! AppConf.done_host
    create(:participant, project:, member:)
  end

  def slugs = { org: org.slug, project: project.slug }

  def colleague
    @colleague ||= create(:participant, project:).member
  end

  def log(text, date: Date.current, by: member, status: "doing")
    day = project.days.find_or_create_by!(org:, date:)
    create(:entry, day:, member: by, log: text, status:)
  end

  describe "list_entries" do
    it "lists the own entries, newest first, never a colleague's" do
      log("Older #review", date: Date.current - 2)
      log("Newer #review")
      log("Not mine", by: colleague)

      data = tool_data(call_tool("list_entries", **slugs))

      expect(data["entries"].pluck("log")).to eq([ "Newer #review", "Older #review" ])
      expect(data["entries"].first).to include("date" => Date.current.iso8601, "tags" => [ "review" ], "status" => "doing")
    end

    it "filters by date range, tag and status" do
      log("In range #call", date: Date.new(2026, 3, 10), status: "done")
      log("In range, other tag #mail", date: Date.new(2026, 3, 11))
      log("Out of range #call", date: Date.new(2026, 4, 1))

      data = tool_data(call_tool("list_entries", **slugs, from: "2026-03-01", to: "2026-03-31", tag: "call", status: "done"))

      expect(data["entries"].pluck("log")).to eq([ "In range #call" ])
    end

    it "pages with a cursor" do
      3.times { log("Entry #{it}", date: Date.current - it) }

      first = tool_data(call_tool("list_entries", **slugs, limit: 2))
      second = tool_data(call_tool("list_entries", **slugs, limit: 2, cursor: first["next_cursor"]))

      expect(first["entries"].size).to eq(2)
      expect(second["entries"].pluck("log")).to eq([ "Entry 2" ])
      expect(second["next_cursor"]).to be_nil
    end

    it "refuses a project the token doesn't reach" do
      other = create(:project, org:)
      create(:participant, project: other, member:)

      result = call_tool("list_entries", org: org.slug, project: other.slug)

      expect(result["isError"]).to be(true)
    end

    it "refuses a date it can't read" do
      expect(call_tool("list_entries", **slugs, from: "March")["isError"]).to be(true)
    end
  end

  describe "get_day" do
    it "gives the own entries of the day with their times and issues" do
      log("start@9:00 Planning")
      log("#break for~30m")
      log("start@8:00 Not mine", by: colleague)

      data = tool_data(call_tool("get_day", **slugs, date: Date.current.iso8601))

      expect(data["entries"].size).to eq(2)
      expect(data).to include("day_start" => "09:00", "day_end" => nil, "break_minutes" => 30)
      expect(data["issues"].pluck("code")).to include("missing_end")
    end
  end

  describe "get_summary" do
    it "sums the own time of a month, per day and per tag" do
      log("start@9:00 end@17:00 Worked #dev for~2h", date: Date.new(2026, 3, 2))
      log("start@9:00 end@13:00 Worked", date: Date.new(2026, 3, 3))
      log("start@9:00 end@18:00 Not mine", date: Date.new(2026, 3, 2), by: colleague)

      data = tool_data(call_tool("get_summary", **slugs, month: "2026-03"))

      expect(data).to include("period" => "2026-03", "from" => "2026-03-01", "to" => "2026-03-31", "total_minutes" => 720)
      expect(data["days"]).to eq([ { "date" => "2026-03-02", "total_minutes" => 480 }, { "date" => "2026-03-03", "total_minutes" => 240 } ])
      expect(data["tag_minutes"]).to eq("dev" => 120)
    end
  end

  describe "get_time_issues" do
    it "lists the own time issues of a week, by day" do
      log("start@9:00 Forgot the end", date: Date.new(2026, 3, 2))
      log("end@17:00 Not mine", date: Date.new(2026, 3, 3), by: colleague)

      data = tool_data(call_tool("get_time_issues", **slugs, week: "2026-W10"))

      expect(data.map { it.values_at("date", "code") }).to eq([ [ "2026-03-02", "missing_end" ] ])
    end
  end
end
