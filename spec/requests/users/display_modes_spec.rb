require "rails_helper"

RSpec.describe "Users::DisplayModes" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  # regression: `redirect_to request.referrer` raised on a nil referrer
  it "redirects to a fallback when the request has no referrer" do
    patch dark_mode_path

    expect(response).to redirect_to(root_path)
  end

  it "redirects back to the referrer" do
    patch dark_mode_path, headers: { "HTTP_REFERER" => "http://www.example.com/settings" }

    expect(response).to redirect_to("http://www.example.com/settings")
  end

  it "does not follow a referrer from another host" do
    patch dark_mode_path, headers: { "HTTP_REFERER" => "https://evil.example.org/" }

    expect(response).to redirect_to(root_path)
  end
end
