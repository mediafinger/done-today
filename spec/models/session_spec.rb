require "rails_helper"

RSpec.describe Session do
  # org and project are part of every path, a session only signs a user in
  it "holds no org and no project" do
    expect(described_class.column_names).not_to include("org_id", "project_id")
  end
end
