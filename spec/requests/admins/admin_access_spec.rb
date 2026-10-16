require "rails_helper"

# Only admins are routed to /admin, everyone else gets what an unknown path answers (AdminConstraint).
RSpec.describe "Admin area" do
  let(:admin_paths) { %w[ /admin /admin/mission_control_jobs ] }

  def expect_status_for_all(status)
    admin_paths.each do |path|
      get path
      expect(response).to have_http_status(status), "#{path} answered #{response.status}"
    end
  end

  it "sends to the sign-in page when not signed in, like an unknown path" do
    admin_paths.each do |path|
      get path
      expect(response).to redirect_to(new_session_path)
    end
  end

  it "is not found for a user who is no admin" do
    sign_in(create(:member, :owner).user)

    expect_status_for_all(:not_found)
  end

  it "is open to admins" do
    sign_in(create(:user, :admin))

    expect_status_for_all(:ok)
  end

  # AdminPolicy is the second gate, should the route constraint ever let a request through
  it "is not found for a user who is no admin even when routed" do
    allow(AdminConstraint).to receive(:matches?).and_return(true)
    sign_in(create(:user))

    expect_status_for_all(:not_found)
    expect(response.body).to include("Page not found")
  end
end
