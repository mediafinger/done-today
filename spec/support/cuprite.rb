require "capybara/cuprite"

# System specs run in headless Chrome through Cuprite. HEADLESS=0 opens the window.
#   A JavaScript error on the page fails the example.
#
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [ 1280, 900 ], options: {
      headless: ENV["HEADLESS"] != "0",
      js_errors: true,
      process_timeout: 20,
      browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
    }
  end
end
