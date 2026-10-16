require "rails_helper"

# /dev is routed in development only (DevConstraint), so these specs pretend to run there.
RSpec.describe "Dev area" do
  context "when running in development" do
    before { allow(DevConstraint).to receive(:matches?).and_return(true) }

    it "is open without signing in" do
      get dev_home_path

      expect(response).to have_http_status(:ok)
    end

    it "is open when signed in" do
      sign_in(create(:user))

      get dev_home_path

      expect(response).to have_http_status(:ok)
    end
  end

  it "is not routed outside of development" do
    sign_in(create(:user))

    get "/dev"

    expect(response).to have_http_status(:not_found)
  end
end
