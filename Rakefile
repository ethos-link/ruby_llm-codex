# frozen_string_literal: true

require "bundler/setup"
require "ethos/gemkit/rake"
require "open3"
require "ruby_llm-codex"

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
      .with_provider_options(**request_options)
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
      .with_provider_options(**request_options)
      .with_schema(schema)
      .with_thinking(effort: :low)
      .ask("Return the requested smoke-test status.")
    unless structured.parsed == {"status" => "ok"}
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
