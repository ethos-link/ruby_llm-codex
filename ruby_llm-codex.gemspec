# frozen_string_literal: true

require_relative "lib/ruby_llm/codex/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-codex"
  spec.version = RubyLLM::Codex::VERSION
  spec.authors = ["Paulo Fidalgo", "Ethos Link"]
  spec.email = ["devel@ethos-link.com"]
  spec.summary = "Use a local, ChatGPT-authenticated Codex CLI as a RubyLLM provider"
  spec.description = <<~TEXT.strip
    A RubyLLM provider that invokes the official Codex CLI, reuses local ChatGPT
    authentication, and maps RubyLLM structured-output schemas to Codex output
    schemas.
  TEXT
  spec.homepage = "https://www.ethos-link.com/opensource/ruby-llm-codex"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"

  repo = "https://github.com/ethos-link/ruby_llm-codex"
  branch = "main"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => repo,
    "bug_tracker_uri" => "#{repo}/issues",
    "changelog_uri" => "#{repo}/blob/#{branch}/CHANGELOG.md",
    "documentation_uri" => spec.homepage,
    "funding_uri" => "https://www.reviato.com/",
    "github_repo" => "ssh://github.com/ethos-link/ruby_llm-codex",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    (Dir["lib/**/*"] + ["CHANGELOG.md", "LICENSE", "README.md", "UPGRADE.md"]).select { |file| File.file?(file) }.uniq.sort
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", "~> 2.1.1"

  spec.add_development_dependency "minitest", "~> 5"
end
