# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

if Rails.env.local?
  require "active_record_doctor"
  require "active_record_doctor/rake/task"
  require "bundler/audit/task"
  require "rspec/core/rake_task"
  require "rubocop/rake_task"

  # setup task bundle:audit
  Bundler::Audit::Task.new

  # setup task active_record_doctor
  ActiveRecordDoctor::Rake::Task.new do |task|
    # Add project-specific Rake dependencies that should be run before running active_record_doctor.
    task.deps = [ :environment ]

    # A path to your active_record_doctor configuration file.
    task.config_path = Rails.root.join(".active_record_doctor.rb")

    # A Proc called right before running detectors that should ensure your Active
    # Record models are preloaded and a database connection is ready.
    task.setup = -> { Rails.application.eager_load! }
  end

  # setup db:doctor, using the rake task defined above
  # running on the development DB to not interfere other tasks on the test DB on GitHub Actions CI
  namespace :db do
    desc "Check the integrity of the database schema"
    task doctor: :environment do
      puts "DB Doctor is running..."
      # Rake::Task["active_record_doctor"].invoke
      puts `RAILS_ENV=development bundle exec rake active_record_doctor` # to make it work on GitHub Actions CI
      check_status = $?.exitstatus # rubocop:disable Style/SpecialGlobalVars
      exit check_status unless check_status.zero?
    end
  end

  namespace :factory_bot do
    desc "Verify that all FactoryBot factories are valid"
    task awesome_lint: :environment do
      puts "Building all factories (but currently no traits) to ensure they are valid"
      abort unless FactoryBot::AwesomeLinter.lint! traits: false, strategy: :build
    end
  end

  # setup task rspec
  RSpec::Core::RakeTask.new(:rspec) do |t|
    t.exclude_pattern = "**/{system,controllers}/**/*_spec.rb" # skipping the slow system specs
  end

  RSpec::Core::RakeTask.new(:ui) do |t|
    t.pattern = "**/{system,controllers}/**/*_spec.rb" # run only the slow system specs
  end

  RuboCop::RakeTask.new do |task|
    task.requires << "rubocop-rails"
  end

  # NOTE: `rake ci` does not run the system specs, run `rake ui` to run only the system specs
  #
  task ci: %w[zeitwerk:check rubocop db:doctor factory_bot:awesome_lint rspec bundle:audit:update bundle:audit]

  task default: :ci

  multitask cui: %i[ci ui] # run `rake ci` and `rake ui` in parallel, the complete test suite
end
