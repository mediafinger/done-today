require "rails_helper"

RSpec.describe "Request id and timeout middlewares" do
  let(:middlewares) { Rails.application.middleware }
  let(:stack) { middlewares.map(&:klass) }

  describe "RequestIdSanitizer" do
    it "cleans the incoming id before Rack::RequestID copies it to the response" do
      expect(stack.index(RequestIdSanitizer)).to eq(stack.index(Rack::RequestID) - 1)
    end

    it "keeps only the characters ActionDispatch::RequestId allows" do
      get "/session/new", headers: { "X-Request-Id" => "req 1<script>alert(1)</script>@proxy" }

      expect(response.headers["X-Request-Id"]).to eq("req1scriptalert1script@proxy")
    end

    it "cuts the id to 255 characters" do
      get "/session/new", headers: { "X-Request-Id" => "a" * 300 }

      expect(response.headers["X-Request-Id"]).to eq("a" * 255)
    end

    it "generates a UUID when nothing usable is left" do
      get "/session/new", headers: { "X-Request-Id" => "<>!" }

      expect(response.headers["X-Request-Id"]).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it "gives the app, the logs and the response the same cleaned id" do
      seen = nil
      allow_any_instance_of(Users::SessionsController).to receive(:new).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance
        seen = [ original.receiver.request.headers["X-Request-Id"], original.receiver.request.request_id ]
        original.call(*args)
      end

      get "/session/new", headers: { "X-Request-Id" => "req 2" }

      expect(seen).to eq([ "req2" ] * 2)
      expect(response.headers["X-Request-Id"]).to eq("req2")
    end
  end

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

    %w[RequestTimeoutException RequestTimeoutError].each do |name|
      it "maps Rack::Timeout::#{name} to 503" do
        expect(ActionDispatch::ExceptionWrapper.status_code_for_exception("Rack::Timeout::#{name}")).to eq(503)
      end
    end

    it "answers a request that runs too long with 503 instead of 500" do
      allow_any_instance_of(Users::SessionsController).to receive(:new) do # rubocop:disable RSpec/AnyInstance
        raise Rack::Timeout::RequestTimeoutException.new({}), "Request ran for longer than 6000ms"
      end

      get "/session/new"

      expect(response).to have_http_status(:service_unavailable)
    end

    it "serves public/503.html for it" do
      status, _headers, body = ActionDispatch::PublicExceptions.new(Rails.public_path)
        .call(Rack::MockRequest.env_for("/503", "HTTP_ACCEPT" => "text/html"))

      expect(status).to eq(503)
      expect(body.join).to include("Error 503")
    end
  end
end
