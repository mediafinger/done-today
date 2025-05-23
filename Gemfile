source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.0.2"

gem "active_storage_validations", "~> 2.0" # To validate uploaded files # TODO: update to 2.x
gem "bcrypt", "~> 3.1.7" # Use Active Model has_secure_password
gem "faker", "~> 3.4"
gem "freezolite", "~> 0.5" # Freeze your strings
gem "importmap-rails" # Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "kamal", require: false # Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "mission_control-jobs", "~> 1.0" # dashboard for SolidQueue jobs
gem "pg", "~> 1.1" # Use postgresql as the database for Active Record
gem "propshaft" # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "puma", ">= 5.0" # Use the Puma web server [https://github.com/puma/puma]
gem "pwned", "~> 2.4" # Pwned checks if a password has been found in huge data breaches [https://github.com/philnash/pwned]
gem "rack-requestid", "~> 0.2" # always set a request_id with this middleware
gem "rack-timeout", "~> 0.7", require: "rack/timeout/base" # set a custom timeout in the middleware
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "stimulus-rails" # Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "thruster", require: false # Add HTTP asset caching/compression and X-Sendfile acceleration to Puma
gem "turbo-rails" # Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "active_record_doctor", "~> 1.14", require: false
  gem "amazing_print", "~> 1.8"
  gem "bundler-audit", "~> 0.9"
  gem "factory_bot-awesome_linter", "~> 1.0"
  gem "factory_bot_rails", "~> 6.2"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails-omakase", require: false # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  # gem "rubocop-capybara"
  gem "rubocop-factory_bot"
  gem "rubocop-faker"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "rubocop-rspec_rails"
end

group :development do
  gem "letter_opener", "~> 1.10" # Preview mail in the browser instead of sending
  gem "web-console" # Use console on exceptions pages [https://github.com/rails/web-console]
end
