# Cleans an incoming X-Request-Id with the rule of ActionDispatch::RequestId, so the
#   request header, `request.request_id`, the logs and the response carry the same id.
#   Rack::RequestID generates one when nothing usable is left.
#
class RequestIdSanitizer
  HEADER = "HTTP_X_REQUEST_ID".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if env.key?(HEADER)
      request_id = env[HEADER].to_s.gsub(/[^\w\-@]/, "")[0, 255]
      request_id.empty? ? env.delete(HEADER) : env[HEADER] = request_id
    end

    @app.call(env)
  end
end
