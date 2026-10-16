require "rails_helper"

RSpec.describe Session do
  # org and project are part of every path, a session only signs a user in
  it "holds no org and no project" do
    expect(described_class.column_names).not_to include("org_id", "project_id")
  end

  it "belongs to a user" do
    expect(described_class.new).not_to be_valid
  end

  it "is deleted with its user" do
    pending "User#destroy raises: has_one_attached :profile_picture without the Active Storage tables (#79)"
    user = create(:user)
    user.sessions.create!

    expect { user.destroy! }.to change(described_class, :count).by(-1)
  end
end
