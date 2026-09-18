require "rails_helper"
require "rake"

RSpec.describe "time_tracking:backfill" do
  subject(:task) { Rake::Task["time_tracking:backfill"] }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("time_tracking:backfill")
    task.reenable # tasks only run once per process, and the suite may invoke this one twice
  end

  it "refills the columns of entries whose log predates the current grammar" do
    entry = create(:entry, log: "#review from@11:00 to@12:00")
    entry.update_columns(tags: [], from_minutes: nil, to_minutes: nil, duration_minutes: nil)

    expect { task.invoke }.to output(/Updated 1 of 1/).to_stdout

    expect(entry.reload).to have_attributes(
      tags: [ "review" ], from_minutes: 660, to_minutes: 720, duration_minutes: 60
    )
  end

  it "leaves updated_at alone, because nothing the user wrote has changed" do
    entry = create(:entry, log: "#review", updated_at: 3.days.ago)

    expect { task.invoke }.to output.to_stdout

    expect(entry.reload.updated_at).to be_within(1.second).of(3.days.ago)
  end
end
