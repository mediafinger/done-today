require "rails_helper"

RSpec.describe TagTimes do
  let(:project) { create(:project) }
  let(:anna) { create(:member, org: project.org, name: "anna") }
  let(:bert) { create(:member, org: project.org, name: "Bert") }

  def entry(log, by: anna, date: "2026-10-05", status: "done")
    day = Day.find_or_create_by!(project:, date: Date.parse(date))
    create(:entry, day:, member: by, log:, status:)
  end

  def rows
    described_class.new(project.entries).rows.map do |row|
      [ row.tag, row.minutes, row.members.map { |member, minutes| [ member.name, minutes ] } ]
    end
  end

  it "sums each tag alphabetically, with the time per member by name" do
    entry("#review for~30m")
    entry("#call for~40m", by: bert)
    entry("#call from@10:00 to@11:00")
    entry("#Call for~1h30", date: "2026-10-06")

    expect(rows).to eq([
      [ "call", 190, [ [ "anna", 150 ], [ "Bert", 40 ] ] ],
      [ "review", 30, [ [ "anna", 30 ] ] ]
    ])
  end

  it "leaves out durations that count for no tag, and tags without a duration" do
    entry("#a #b for~1h")
    entry("#break #lunch for~30m")
    entry("for~2h")
    entry("#notes only")

    expect(rows).to be_empty
  end

  it "counts todo entries and archived members" do
    entry("#call for~1h", status: "todo")
    entry("#call for~1h", by: bert)
    bert.update!(archived_at: Time.current)

    expect(rows).to eq([ [ "call", 120, [ [ "anna", 60 ], [ "Bert", 60 ] ] ] ])
  end

  it "sums only the entries it is given" do
    entry("#call for~1h", date: "2026-09-30")
    entry("#call for~2h", date: "2026-10-01")

    october = project.entries.where(days: { date: Date.new(2026, 10, 1).all_month })

    expect(described_class.new(october).rows.map(&:minutes)).to eq([ 120 ])
  end
end
