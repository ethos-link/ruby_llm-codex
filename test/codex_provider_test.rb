# frozen_string_literal: true

require_relative "test_helper"

class CodexProviderTest < Minitest::Test
  class ResultSchema < RubyLLM::Schema
    string :answer
    integer :score
  end

  CONFIG_OPTIONS = %i[
    codex_cli_path
    codex_working_directory
    codex_profile
    codex_home
    codex_ignore_user_config
    codex_ephemeral
    codex_timeout
    codex_shell_environment_inherit
  ].freeze

  ENVIRONMENT_KEYS = %w[
    FAKE_CODEX_DESCENDANT_MARKER
    FAKE_CODEX_FAIL
    FAKE_CODEX_FALLBACK
    FAKE_CODEX_INVALID_JSON
    FAKE_CODEX_LOG
    FAKE_CODEX_MISSING_OUTPUT
    FAKE_CODEX_MISSING_USAGE
    FAKE_CODEX_SLEEP
    FAKE_CODEX_STDERR
    FAKE_CODEX_VERSION
  ].freeze

  def setup
    @directory = Dir.mktmpdir("fake-codex-")
    @fake_codex = File.join(@directory, "codex")
    @log_path = File.join(@directory, "invocations.jsonl")
    File.write(@fake_codex, fake_codex_program)
    File.chmod(0o755, @fake_codex)
    RubyLLM.config.codex_cli_path = @fake_codex
    ENV["FAKE_CODEX_LOG"] = @log_path
  end

  def teardown
    FileUtils.remove_entry(@directory) if Dir.exist?(@directory)
    CONFIG_OPTIONS.each { |option| RubyLLM.config.public_send("#{option}=", nil) }
    ENVIRONMENT_KEYS.each { |key| ENV.delete(key) }
  end

  def test_provider_is_registered_as_local_and_accepts_explicit_models
    provider = RubyLLM::Provider.resolve(:codex)

    assert_equal RubyLLM::Providers::Codex, provider
    assert provider.local?
    assert provider.assume_models_exist?
    CONFIG_OPTIONS.each { |option| assert_respond_to RubyLLM.config, option }

    chat = RubyLLM.chat(model: "unregistered-codex-model", provider: :codex)
    assert_equal "unregistered-codex-model", chat.model.id
  end

  def test_plain_text_output_and_token_usage_are_returned
    response = RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")

    assert_equal "OK", response.content
    assert_equal "gpt-test", response.model_id
    assert_equal 75, response.input_tokens
    assert_equal 25, response.cached_tokens
    assert_equal 12, response.output_tokens
    assert_equal 3, response.thinking_tokens
    assert_equal 2, invocations.length
    assert_equal "version", invocations.first.fetch("kind")
    assert_equal "exec", invocations.last.fetch("kind")
  end

  def test_schema_class_is_loaded_and_returned_as_a_hash
    response = RubyLLM.chat(model: "gpt-test", provider: :codex)
      .with_schema(ResultSchema)
      .ask("Evaluate this")
    invocation = exec_invocation

    assert_equal({"answer" => "ok", "score" => 7}, response.content)
    assert_equal "object", invocation.dig("schema", "type")
    assert_equal %w[answer score], invocation.dig("schema", "required")
  end

  def test_system_instructions_and_multi_turn_history_are_mapped
    chat = RubyLLM.chat(model: "gpt-test", provider: :codex)
      .with_instructions("Be exact")
    chat.add_message(role: :user, content: "First question")
    chat.add_message(role: :assistant, content: "First answer")
    chat.ask("Second question")
    invocation = exec_invocation

    assert_includes invocation.fetch("configs"), "developer_instructions=\"Be exact\""
    prompt = invocation.fetch("prompt")
    assert_includes prompt, '"role": "user"'
    assert_includes prompt, "First question"
    assert_includes prompt, '"role": "assistant"'
    assert_includes prompt, "Second question"
  end

  def test_provider_options_are_forwarded_with_explicit_precedence
    codex_home = File.join(@directory, "codex-home")
    Dir.mkdir(codex_home)
    RubyLLM.chat(model: "gpt-test", provider: :codex)
      .with_thinking(effort: :medium)
      .with_params(
             codex: {
               working_directory: @directory,
               profile: "experiment",
               codex_home:,
               sandbox: "read-only",
               ignore_user_config: false,
               ephemeral: false,
               shell_environment_inherit: "all",
               config: {"features.example" => true}
             }
           ).ask("Reply OK")
    invocation = exec_invocation

    assert_equal @directory, invocation.fetch("working_directory")
    assert_equal File.expand_path(codex_home), invocation.fetch("codex_home")
    assert_equal "experiment", invocation.fetch("profile")
    assert_equal "read-only", invocation.fetch("sandbox")
    refute invocation.fetch("ignore_user_config")
    refute invocation.fetch("ephemeral")
    assert_includes invocation.fetch("configs"), "features.shell_snapshot=false"
    assert_includes invocation.fetch("configs"), 'shell_environment_policy.inherit="all"'
    assert_includes invocation.fetch("configs"), 'model_reasoning_effort="medium"'
    assert_includes invocation.fetch("configs"), "features.example=true"
  end

  def test_failed_codex_process_raises_provider_error
    ENV["FAKE_CODEX_FAIL"] = "1"

    error = assert_raises(RubyLLM::Providers::Codex::Error) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Fail")
    end

    assert_match(/simulated failure/, error.message)
  end

  def test_old_codex_version_is_rejected_before_exec
    ENV["FAKE_CODEX_VERSION"] = "0.100.0"

    error = assert_raises(RubyLLM::Providers::Codex::Error) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")
    end

    assert_match(/0\.100\.0 is unsupported/, error.message)
    assert_equal ["version"], invocations.map { |invocation| invocation.fetch("kind") }
  end

  def test_malformed_jsonl_raises_provider_error
    ENV["FAKE_CODEX_INVALID_JSON"] = "1"

    error = assert_raises(RubyLLM::Providers::Codex::Error) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")
    end

    assert_match(/invalid JSONL/, error.message)
  end

  def test_agent_event_is_used_when_output_file_is_empty
    ENV["FAKE_CODEX_FALLBACK"] = "1"

    response = RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")

    assert_equal "OK", response.content
  end

  def test_missing_final_output_raises_provider_error
    ENV["FAKE_CODEX_MISSING_OUTPUT"] = "1"

    error = assert_raises(RubyLLM::Providers::Codex::Error) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")
    end

    assert_match(/without a final response/, error.message)
  end

  def test_stderr_is_retained_and_missing_usage_remains_nil
    ENV["FAKE_CODEX_STDERR"] = "1"
    ENV["FAKE_CODEX_MISSING_USAGE"] = "1"

    response = RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply OK")

    assert_equal "diagnostic warning\n", response.raw.fetch(:stderr)
    assert_nil response.input_tokens
    assert_nil response.cached_tokens
    assert_nil response.output_tokens
    assert_nil response.thinking_tokens
  end

  def test_process_timeout_terminates_descendants
    marker = File.join(@directory, "descendant-terminated")
    ENV["FAKE_CODEX_SLEEP"] = "1"
    ENV["FAKE_CODEX_DESCENDANT_MARKER"] = marker
    RubyLLM.config.codex_timeout = 0.5

    error = assert_raises(RubyLLM::Providers::Codex::TimeoutError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Wait")
    end

    assert_match(/timed out after 0.5 seconds/, error.message)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    sleep 0.01 until File.exist?(marker) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    assert File.exist?(marker), "expected the descendant process to receive TERM"
  end

  def test_unsupported_provider_features_are_rejected
    tool = Object.new
    tool.define_singleton_method(:name) { "sample" }

    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).with_tool(tool).ask("Use tool")
    end
    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).with_temperature(0.2).ask("Reply")
    end
    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).with_headers(test: "value").ask("Reply")
    end
    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask("Reply") { |_chunk| nil }
    end
    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      content = RubyLLM::Content.new("Reply", __FILE__)
      RubyLLM.chat(model: "gpt-test", provider: :codex).ask(content)
    end
    assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex).with_thinking(budget: 100).ask("Reply")
    end
  end

  def test_unknown_generic_params_and_reserved_config_keys_are_rejected
    error = assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex)
        .with_params(max_tokens: 10)
        .ask("Reply OK")
    end
    assert_match(/max_tokens/, error.message)

    error = assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex)
        .with_params(codex: {config: {model_reasoning_effort: "high"}})
        .ask("Reply OK")
    end
    assert_match(/model_reasoning_effort/, error.message)

    error = assert_raises(RubyLLM::Providers::Codex::UnsupportedFeatureError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex)
        .with_params(codex: {config: {"features.shell_snapshot" => true}})
        .ask("Reply OK")
    end
    assert_match(/features\.shell_snapshot/, error.message)
  end

  def test_boolean_options_must_be_booleans
    error = assert_raises(ArgumentError) do
      RubyLLM.chat(model: "gpt-test", provider: :codex)
        .with_params(codex: {ephemeral: "false"})
        .ask("Reply OK")
    end

    assert_match(/ephemeral must be true or false/, error.message)
  end

  def test_missing_working_directory_is_rejected
    error = assert_raises(RubyLLM::Providers::Codex::Error) do
      RubyLLM.chat(model: "gpt-test", provider: :codex)
        .with_params(codex: {working_directory: File.join(@directory, "missing")})
        .ask("Reply OK")
    end

    assert_match(/working directory does not exist/, error.message)
  end

  private

  def invocations
    return [] unless File.exist?(@log_path)

    File.readlines(@log_path, chomp: true).map { |line| JSON.parse(line) }
  end

  def exec_invocation
    invocations.reverse.find { |invocation| invocation["kind"] == "exec" }
  end

  def fake_codex_program
    <<~RUBY
      #!#{RbConfig.ruby}
      require "json"
      require "rbconfig"

      def record(payload)
        File.open(ENV.fetch("FAKE_CODEX_LOG"), "a") { |file| file.puts(JSON.generate(payload)) }
      end

      if ARGV == ["--version"]
        record(kind: "version")
        puts "codex-cli \#{ENV.fetch("FAKE_CODEX_VERSION", "0.144.5")}"
        exit
      end

      expected_prefix = ["--ask-for-approval", "never", "exec"]
      abort "invalid global argument order: \#{ARGV.inspect}" unless ARGV.shift(3) == expected_prefix

      parsed = {
        kind: "exec",
        configs: [],
        ignore_user_config: false,
        ephemeral: false,
        working_directory: Dir.pwd,
        codex_home: ENV["CODEX_HOME"]
      }
      until ARGV.empty?
        argument = ARGV.shift
        case argument
        when "--json", "--skip-git-repo-check", "-"
          nil
        when "--ephemeral"
          parsed[:ephemeral] = true
        when "--ignore-user-config"
          parsed[:ignore_user_config] = true
        when "--color", "--sandbox", "--output-last-message", "--model", "--profile",
             "--output-schema", "--config"
          value = ARGV.shift or abort "missing value for \#{argument}"
          case argument
          when "--color" then parsed[:color] = value
          when "--sandbox" then parsed[:sandbox] = value
          when "--output-last-message" then parsed[:output_path] = value
          when "--model" then parsed[:model] = value
          when "--profile" then parsed[:profile] = value
          when "--output-schema" then parsed[:schema_path] = value
          when "--config" then parsed[:configs] << value
          end
        else
          abort "unexpected argument: \#{argument}"
        end
      end

      parsed[:prompt] = STDIN.read
      parsed[:schema] = JSON.parse(File.read(parsed[:schema_path])) if parsed[:schema_path]
      record(parsed)

      if ENV["FAKE_CODEX_FAIL"]
        puts JSON.generate(type: "turn.failed", message: "simulated failure")
        exit 2
      end

      if ENV["FAKE_CODEX_SLEEP"]
        marker = ENV.fetch("FAKE_CODEX_DESCENDANT_MARKER")
        ready = "\#{marker}.ready"
        child = <<~CHILD
          marker = ARGV.fetch(0)
          ready = ARGV.fetch(1)
          trap("TERM") { File.write(marker, "terminated"); exit }
          File.write(ready, "ready")
          sleep 30
        CHILD
        spawn(RbConfig.ruby, "-e", child, marker, ready)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
        sleep 0.01 until File.exist?(ready) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 30
      end

      result = parsed[:schema_path] ? { answer: "ok", score: 7 } : "OK"
      content = result.is_a?(String) ? result : JSON.generate(result)
      unless ENV["FAKE_CODEX_FALLBACK"] || ENV["FAKE_CODEX_MISSING_OUTPUT"]
        File.write(parsed.fetch(:output_path), content)
      end
      puts "not-json" if ENV["FAKE_CODEX_INVALID_JSON"]
      unless ENV["FAKE_CODEX_MISSING_OUTPUT"]
        puts JSON.generate(type: "item.completed", item: { type: "agent_message", text: content })
      end
      event = { type: "turn.completed", model: parsed[:model] }
      unless ENV["FAKE_CODEX_MISSING_USAGE"]
        event[:usage] = {
          input_tokens: 100,
          cached_input_tokens: 25,
          output_tokens: 12,
          reasoning_output_tokens: 3
        }
      end
      puts JSON.generate(event)
      warn "diagnostic warning" if ENV["FAKE_CODEX_STDERR"]
    RUBY
  end
end
