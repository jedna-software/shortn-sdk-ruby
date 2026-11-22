# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/*_test.rb"].exclude("test/smoke_test.rb")
  t.warning = true
end

# Live checks against a Shortn instance. Needs SHORTN_API_KEY and
# SHORTN_BASE_URL (and the SHORTN_SMOKE_* fixtures); skipped otherwise.
Rake::TestTask.new(:smoke) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/smoke_test.rb"]
  t.warning = true
end

task default: :test
