require "rails_helper"

# An action that forgets `authorize!` or `authorized_scope` has already run when the
#   verification fails. Outside production that raises, so specs and CI catch it. In
#   production the user keeps the response they got, and the error is reported.
#
class ForgetfulController < ApplicationController
  allow_unauthenticated_access

  def unchecked
    render plain: "done"
  end
end

RSpec.describe "An action that forgets its authorization" do
  around do |example|
    with_routing do |routes|
      routes.draw { get "unchecked", to: "forgetful#unchecked" }
      example.run
    end
  end

  # the scope check runs first
  it "raises outside production" do
    expect { get "/unchecked" }.to raise_error(ActionPolicy::UnscopedAction)
  end

  context "when running in production" do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it "keeps the response and reports both missed checks" do
      allow(Rails.error).to receive(:report)

      get "/unchecked"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("done")
      expect(Rails.error).to have_received(:report).with(an_instance_of(ActionPolicy::UnauthorizedAction))
      expect(Rails.error).to have_received(:report).with(an_instance_of(ActionPolicy::UnscopedAction))
    end
  end
end
