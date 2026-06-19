# Testing TODOs

While this Rails app is configure to run tests , no tests have been written so far. We will implement unit controller specs with RSpec as a first measure.

As the TECHNICAL_DEBT.md file outlines, there are some bugs in the code. When writing a test for a buggy feature, write the test how it should be if there would be no bug and mark it as "pending".

Do not change any code, except creating the tests.  
Please document the progress and any issues like pending tests in a file called TEST_PROGRESS.md.

The Rakefile defines a task `rake ci` which runs a few tools. Run it every time before finishing and fix all the issues.  
Do not cheat by changing the rubocop configuration. It is there to support us!

- [x] Move and clean up org_scope_helper.rb
- [x] Configure rails_helper.rb (Pwned stubs & sign_in helpers)
- [x] Create FactoryBot factories (spec/factories.rb or spec/factories/*.rb)
- [x] Create Model Specs (spec/models/*.rb)
- [x] Create Service & Validator Specs (spec/services/*.rb and spec/validators/*.rb)
- [x] Create Controller Specs (spec/controllers/**/*.rb)
- [x] Create TEST_PROGRESS.md
- [x] Run test suite and verify
- [x] add missing rspec unit specs
- [x] add missing rspec controller specs
- [x] Run test suite and verify
- [x] run `rake ci` and fix any issues