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
  spec.homepage = "https://github.com/ethos-link/ruby_llm-codex"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  repo = "https://github.com/ethos-link/ruby_llm-codex"
  branch = "main"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => repo,
    "bug_tracker_uri" => "#{repo}/issues",
    "changelog_uri" => "#{repo}/blob/#{branch}/CHANGELOG.md",
    "documentation_uri" => "#{repo}/blob/#{branch}/README.md",
    "funding_uri" => "https://www.reviato.com/",
    "github_repo" => "ssh://github.com/ethos-link/ruby_llm-codex",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    allowed_prefixes = %w[lib/].freeze
    allowed_files = %w[CHANGELOG.md LICENSE README.md].freeze
    git_files = `git ls-files -z 2>/dev/null`.split("\x0")
    candidates = git_files.empty? ? Dir.glob("lib/**/*", File::FNM_DOTMATCH) + allowed_files : git_files

    candidates.select do |file|
      next false unless File.file?(file)

      allowed_files.include?(file) || allowed_prefixes.any? { |prefix| file.start_with?(prefix) }
    end.uniq
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", ">= 1.16", "< 2.0"

  spec.add_development_dependency "minitest", "~> 5"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "standard", "~> 1.0"
end
