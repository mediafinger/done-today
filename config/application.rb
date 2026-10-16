require_relative "boot"

# Read ENV variables and make AppConf settings available
require_relative "app_conf"
require_relative "mail_settings"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DoneToday
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Entry dates are plain local dates and clock times are minutes since midnight,
    #   so the zone only decides what "today" means -- never what is stored.
    config.time_zone = AppConf.timezone
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # policies are asked on behalf of the Member, see ApplicationPolicy
    config.action_policy.controller_authorize_current_user = false

    # Middleware configuration:

    # Rack::RequestID ensures that every request has HTTP_X_REQUEST_ID set
    # It needs to reside in the callchain before ActionDispatch::RequestId
    # ActionDispatch::RequestId creates a request_id or uses HTTP_X_REQUEST_ID
    # but it will not change the request header (only sets the response header)
    config.middleware.insert_before(
      ActionDispatch::RequestId,
      ::Rack::RequestID, include_response_header: true, overwrite: false
    )

    # start the timer once the request has its id, start with DEBUG=true for 300 seconds
    config.middleware.insert_after(
      ActionDispatch::RequestId,
      Rack::Timeout, service_timeout: AppConf.rack_timeout # seconds
    )
    Rack::Timeout::Logger.disable # we only log the errors, not the verbose status messages
  end
end
