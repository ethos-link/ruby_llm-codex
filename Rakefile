# frozen_string_literal: true

require "bundler/gem_tasks"
require "open3"
require "rake/testtask"
require "rubygems/version"
require "standard/rake"
require_relative "lib/ruby_llm-codex"
require_relative "lib/ruby_llm/codex/version"

VERSION_PATH = File.expand_path("lib/ruby_llm/codex/version.rb", __dir__)
VALID_RELEASE_TARGETS = %w[major minor patch].freeze

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

def current_branch
  `git branch --show-current`.strip
end

def clean_worktree?
  system("git diff --quiet") && system("git diff --cached --quiet")
end

def release_tag(version)
  "v#{version}"
end

def release_version(target)
  target = target.to_s.strip
  if target.empty?
    raise ArgumentError, "Provide patch, minor, major, or an explicit X.Y.Z version."
  end

  return target if target.match?(/\A\d+\.\d+\.\d+\z/)

  unless VALID_RELEASE_TARGETS.include?(target)
    message = "Invalid release target #{target.inspect}. Use " \
      "#{VALID_RELEASE_TARGETS.join(", ")} or X.Y.Z."
    raise ArgumentError, message
  end

  major, minor, patch = RubyLLM::Codex::VERSION.split(".").map(&:to_i)

  case target
  when "major" then "#{major + 1}.0.0"
  when "minor" then "#{major}.#{minor + 1}.0"
  when "patch" then "#{major}.#{minor}.#{patch + 1}"
  end
end

def validate_release_version!(version, current)
  if Gem::Version.new(version) <= Gem::Version.new(current)
    raise ArgumentError, "Release version #{version} must be newer than current version #{current}."
  end

  tag = release_tag(version)
  raise ArgumentError, "Release tag #{tag} already exists locally." if local_release_tag_exists?(tag)
  raise ArgumentError, "Release tag #{tag} already exists on origin." if remote_release_tag_exists?(tag)
end

def local_release_tag_exists?(tag)
  system("git", "rev-parse", "--quiet", "--verify", "refs/tags/#{tag}", out: File::NULL)
end

def remote_release_tag_exists?(tag)
  output = `#{remote_release_tag_command(tag)} 2>&1`
  status = $?

  return true if status.success?
  return false if status.exitstatus == 2

  raise "Could not check origin for #{tag}: #{output.strip}"
end

def remote_release_tag_command(tag)
  "git ls-remote --exit-code --tags origin refs/tags/#{tag}"
end

def update_version_file(version)
  File.write(
    VERSION_PATH,
    <<~RUBY
      # frozen_string_literal: true

      module RubyLLM
        module Codex
          VERSION = "#{version}"
        end
      end
    RUBY
  )
end

def changelog_command(version)
  [
    "git-cliff", "-c", "cliff.toml", "--unreleased", "--tag",
    release_tag(version), "--prepend", "CHANGELOG.md"
  ]
end

def update_changelog(version)
  success = system(*changelog_command(version))
  raise "git-cliff failed. Install git-cliff and verify cliff.toml." unless success

  return unless system("git", "diff", "--quiet", "--", "CHANGELOG.md")

  raise "git-cliff did not update CHANGELOG.md. Ensure there are Conventional Commits since the last tag."
end

Rake::Task["release"].clear if Rake::Task.task_defined?("release")

desc "Publishing is handled by CI. Use release:prepare[...] instead."
task :release do
  abort "Use `bundle exec rake 'release:prepare[patch]'` (or minor/major/X.Y.Z). Publishing runs in GitHub Actions."
end

namespace :release do
  desc "Prepare a release: update changelog/version, commit, tag, and push."
  task :prepare, [:target] do |_task, args|
    branch = current_branch
    abort "Release must run on main. Current branch: #{branch.inspect}." unless branch == "main"
    abort "Release requires a clean working tree." unless clean_worktree?

    version = release_version(args[:target])
    validate_release_version!(version, RubyLLM::Codex::VERSION)
    update_changelog(version)
    update_version_file(version)

    tag = release_tag(version)
    sh "git add CHANGELOG.md lib/ruby_llm/codex/version.rb"
    sh %(LEFTHOOK=0 git commit -m "chore(release): prepare v#{version}")
    sh %(git tag -a #{tag} -m "Release #{tag}")
    sh "git push origin main"
    sh "git push origin #{tag}"
  rescue ArgumentError, RuntimeError => e
    abort e.message
  end
end

namespace :codex do
  desc "Run live plain-text and structured-output smoke tests through Codex CLI"
  task :smoke do
    cli_path = ENV.fetch("CODEX_BIN", "codex")
    model = ENV["CODEX_MODEL"]
    raise "Set CODEX_MODEL to a model available in your Codex account" if model.nil? || model.empty?
    timeout = Float(ENV.fetch("CODEX_TIMEOUT", RubyLLM::Providers::Codex::DEFAULT_TIMEOUT))
    version_output, version_status = Open3.capture2e(cli_path, "--version")
    raise "Could not run #{cli_path.inspect}: #{version_output.strip}" unless version_status.success?

    version = version_output[/\d+\.\d+\.\d+/]
    raise "Could not parse Codex CLI version from: #{version_output.strip}" unless version

    minimum = RubyLLM::Providers::Codex::MINIMUM_CLI_VERSION
    if Gem::Version.new(version) < Gem::Version.new(minimum)
      raise "Codex CLI #{version} is unsupported; version #{minimum} or newer is required"
    end

    RubyLLM.config.codex_cli_path = cli_path
    request_options = {codex: {timeout:}}

    marker = "RUBY_LLM_CODEX_SMOKE_OK"
    plain = RubyLLM.chat(model:, provider: :codex)
      .with_params(**request_options)
      .with_thinking(effort: :low)
      .ask("Reply with exactly #{marker} and nothing else.")
    raise "Plain-text smoke test returned #{plain.content.inspect}" unless plain.content.strip == marker

    schema = {
      name: "ruby_llm_codex_smoke",
      strict: true,
      schema: {
        type: "object",
        properties: {status: {type: "string", enum: ["ok"]}},
        required: ["status"],
        additionalProperties: false
      }
    }
    structured = RubyLLM.chat(model:, provider: :codex)
      .with_params(**request_options)
      .with_schema(schema)
      .with_thinking(effort: :low)
      .ask("Return the requested smoke-test status.")
    unless structured.content == {"status" => "ok"}
      raise "Structured-output smoke test returned #{structured.content.inspect}"
    end

    puts "Codex CLI #{version} (minimum #{minimum})"
    puts "RubyLLM #{RubyLLM::VERSION}"
    puts "Plain-text completion: ok"
    puts "Structured-output completion: ok"
  rescue Errno::ENOENT => e
    raise "Could not execute Codex CLI at #{cli_path.inspect}: #{e.message}"
  end
end

task default: %i[test standard]
