require "rails_helper"
require "csv"

RSpec.describe "Mcp export_entries" do
  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:, name: "Anna") }
  let(:secret) { personal_token(member.user, project => "read") }

  before do
    host! AppConf.done_host
    create(:participant, project:, member:)
    colleague = create(:participant, project:, member: create(:member, org:, name: "Bert")).member

    { member => "start@9:00 end@17:00 Mine", colleague => "start@9:00 end@18:00 Not mine" }.each do |by, log|
      create(:entry, day: project.days.find_or_create_by!(org:, date: Date.new(2026, 3, 2)), member: by, log:)
    end
  end

  def export(**arguments)
    tool_data(call_tool("export_entries", org: org.slug, project: project.slug, **arguments))
  end

  it "exports the own days of a month" do
    data = export(month: "2026-03")

    expect(data["filename"]).to end_with(".csv")
    rows = CSV.parse(data["csv"], headers: true)
    expect(rows.map { it.to_h.slice("member", "date", "hours") }).to eq([ { "member" => "Anna", "date" => "2026-03-02", "hours" => "8.0" } ])
  end

  it "exports the own total of a month" do
    rows = CSV.parse(export(month: "2026-03", per: "month")["csv"], headers: true)

    expect(rows.map { it.to_h.slice("member", "month", "hours") }).to eq([ { "member" => "Anna", "month" => "2026-03", "hours" => "8.0" } ])
  end

  it "refuses a month it can't read" do
    expect(call_tool("export_entries", org: org.slug, project: project.slug, month: "March")["isError"]).to be(true)
  end
end
