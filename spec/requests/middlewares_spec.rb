require "rails_helper"

RSpec.describe "Request id and timeout middlewares" do
  let(:middlewares) { Rails.application.middleware }
  let(:stack) { middlewares.map(&:klass) }

  describe "Rack::RequestID" do
    it "sets HTTP_X_REQUEST_ID right before ActionDispatch::RequestId reads it" do
      expect(stack.index(Rack::RequestID)).to eq(stack.index(ActionDispatch::RequestId) - 1)
    end

    it "keeps an incoming request id" do
      expect(middlewares.find { it.klass == Rack::RequestID }.args)
        .to eq([ { include_response_header: true, overwrite: false } ])
    end

    it "answers with the request id the client sent" do
      get "/session/new", headers: { "X-Request-Id" => "req-from-proxy-1" }

      expect(response.headers["X-Request-Id"]).to eq("req-from-proxy-1")
    end

    it "generates a UUID when the client sent none" do
      get "/session/new"

      expect(response.headers["X-Request-Id"]).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it "passes the same id to the app as request header and request_id" do
      seen = nil
      allow_any_instance_of(Users::SessionsController).to receive(:new).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance
        seen = [ original.receiver.request.headers["X-Request-Id"], original.receiver.request.request_id ]
        original.call(*args)
      end

      get "/session/new"

      expect(seen.first).to be_present
      expect(seen).to eq([ response.headers["X-Request-Id"] ] * 2)
    end
  end

  describe "Rack::Timeout" do
    it "starts right after the request id is set" do
      expect(stack.index(Rack::Timeout)).to eq(stack.index(ActionDispatch::RequestId) + 1)
    end

    it "takes the timeout from AppConf" do
      expect(middlewares.find { it.klass == Rack::Timeout }.args).to eq([ { service_timeout: AppConf.rack_timeout } ])
    end
  end
end
