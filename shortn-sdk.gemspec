# frozen_string_literal: true

require_relative "lib/shortn/sdk/version"

Gem::Specification.new do |spec|
  spec.name = "shortn-sdk"
  spec.version = Shortn::SDK::VERSION
  spec.summary = "Ruby SDK for the Shortn Link API."
  spec.description = "Server-side Ruby client for the Shortn Link public API: links, analytics, workspaces, " \
                     "tags, UTM templates, destinations, teams, custom domains, report rules and conversions."
  spec.authors = ["Jedna Software"]
  spec.license = "MIT"
  spec.homepage = "https://shortn.link"
  spec.metadata = {
    "source_code_uri" => "https://github.com/jedna-software/shortn-sdk-ruby",
    "bug_tracker_uri" => "https://github.com/jedna-software/shortn-sdk-ruby/issues",
    "changelog_uri" => "https://github.com/jedna-software/shortn-sdk-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://docs.shortn.link/docs/api/",
    "rubygems_mfa_required" => "true"
  }
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "examples/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
