require "rails_helper"

# /dev is routed in development and test only (Rails.env.local?), letter_opener_web is mounted in development.
RSpec.describe "Dev area" do
  it "is open without signing in" do
    get dev_home_path

    expect(response).to have_http_status(:ok)
  end

  it "is open when signed in" do
    sign_in(create(:user))

    get dev_home_path

    expect(response).to have_http_status(:ok)
  end

  it "is not routed outside of development and test" do
    allow(Rails.env).to receive(:local?).and_return(false)
    sign_in(create(:user))

    get "/dev"

    expect(response).to have_http_status(:not_found)
  end
end
