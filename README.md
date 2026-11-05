# RubyLLM Codex provider

[![Ruby](https://github.com/ethos-link/ruby_llm-codex/actions/workflows/ruby.yml/badge.svg)](https://github.com/ethos-link/ruby_llm-codex/actions/workflows/ruby.yml)
[![Gem Version](https://badge.fury.io/rb/ruby_llm-codex.svg)](https://rubygems.org/gems/ruby_llm-codex)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This adapter lets RubyLLM invoke the official local Codex CLI as a provider. It
supports text completions and structured output through RubyLLM's familiar chat
interface.

Authentication is handled by the Codex CLI using the account configured by
`codex login`; the gem does not accept or store an OpenAI API key.

Responses come from the **Codex agent harness**, not directly from a raw model
API. Codex applies its own base instructions and runtime behavior. RubyLLM system
messages are passed as Codex developer instructions, which is the closest
supported mapping but not an identical wire-level request.

## Requirements

- Ruby 4.0 or newer
- RubyLLM 2.1.1 or newer, below 2.2
- Codex CLI 0.162.1 or newer, available as `codex`
- Linux or macOS (timeout cleanup relies on POSIX process groups)
- A completed ChatGPT login: `codex login`

Install Codex if necessary:

```bash
npm install -g @openai/codex
codex login
```

Check the model list in your installed Codex version before a large run. Model
availability depends on the account and currently installed CLI.

For migration steps from RubyLLM 1.x, see [UPGRADE.md](UPGRADE.md).

## Installation

Add the gem to your application's `Gemfile`:

```ruby
gem "ruby_llm-codex", "~> 0.4.0"
```

Then run `bundle install`. You can also install it directly:

```bash
gem install ruby_llm-codex
```

## Usage

Require the gem and use Codex as an explicit RubyLLM provider:

```ruby
require "ruby_llm-codex"

class SummarySchema < Schematist::Schema
  string :summary
end

response = RubyLLM.chat(model: ENV.fetch("CODEX_MODEL"), provider: :codex)
  .with_instructions("Return a concise summary.")
  .with_schema(SummarySchema)
  .with_thinking(effort: :medium)
  .ask("The text to summarize")

pp response.parsed
```

`response.content` contains the JSON string. Read `response.parsed` for the
structured Hash, and `response.tokens` for token counts.

## Isolation and reproducibility

By default every request:

- runs in a fresh empty temporary directory;
- uses a read-only sandbox;
- disables interactive approvals;
- ignores user Codex configuration while retaining authentication;
- creates an ephemeral Codex session;
- disables Codex shell snapshots, which are unnecessary because this provider
  does not support tools;
- prevents model-generated shell commands from inheriting the parent process
  environment;
- passes RubyLLM's system instruction as Codex developer instructions;
- passes RubyLLM's JSON schema through `--output-schema`.

This prevents local `AGENTS.md`, plugins, MCP servers, repository contents, and
saved session history from quietly affecting a request.

## Configuration

### Per request

To deliberately let Codex inspect a repository or use selected configuration:

```ruby
chat.with_provider_options(
  codex: {
    working_directory: "/path/to/project",
    sandbox: "read-only",
    ignore_user_config: false,
    ephemeral: true,
    timeout: 300,
    shell_environment_inherit: "none"
  }
)
```

### Global

Global configuration is also available:

```ruby
RubyLLM.configure do |config|
  config.codex_cli_path = "/usr/local/bin/codex"
  config.codex_working_directory = nil
  config.codex_profile = nil
  config.codex_home = nil
  config.codex_ignore_user_config = true
  config.codex_ephemeral = true
  config.codex_timeout = 300
  config.codex_shell_environment_inherit = "none"
end
```

Only the nested `codex` namespace is accepted by `with_provider_options`; unsupported
generic provider options raise an error instead of being silently ignored. Use
`with_thinking` for reasoning effort and `with_instructions` for developer
instructions. Those settings, plus `features.shell_snapshot` and
`shell_environment_policy.inherit`, are reserved from the arbitrary
`codex.config` map so their precedence remains unambiguous.

## Deliberate limitations

- Non-streaming chat only.
- Text prompts only; attachments are rejected.
- RubyLLM tools are rejected. Codex remains the generation harness, not a tool
  execution backend for your application.
- Temperature is rejected because this Codex path does not expose it.
- Fresh `codex exec` process per RubyLLM completion. This prioritizes isolation
  and predictable behavior over throughput.
- Multi-turn RubyLLM histories are serialized into a role-labelled transcript.
  One-shot `with_instructions(...).ask(...)` requests have the most direct
  semantic mapping.

If you later need streaming, persistent threads, or high throughput, replace
the process-per-request implementation with a long-running `codex app-server`
client while keeping the same RubyLLM provider surface.

## Troubleshooting

- **`codex` is not found:** install the Codex CLI, run `codex login`, or set
  `RubyLLM.config.codex_cli_path` to its absolute path.
- **A request times out:** increase `codex.timeout` or `CODEX_TIMEOUT` for the
  smoke task. Timed-out process groups are terminated automatically.
- **Codex consumes excessive memory:** use the current gem version. The provider
  explicitly disables Codex shell snapshots, which are unnecessary for its
  completion-only execution and previously caused runaway Bash processes.
- **Local instructions affect output:** keep `ignore_user_config: true` and do
  not set a working directory when you need isolated requests.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By participating, you agree to follow
the [Code of Conduct](CODE_OF_CONDUCT.md). Security reports should follow
[SECURITY.md](SECURITY.md), not a public issue.

## License

MIT License. See [LICENSE](LICENSE).

## Development and releases

Shared tooling uses published [Ethos Gemkit](https://github.com/ethos-link/ethos-gemkit).
Keep the exact Gemfile version and workflow commit pins on the same release.

```sh
bundle install
bundle exec lefthook install
bundle exec rake verify
```

Verification uses a fake Codex executable; it makes no live model requests.
The optional `codex:smoke` task requires your Codex account, an available
`CODEX_MODEL` and a bounded process/memory scope.

Release preparation, publication, registry setup and recovery are documented
in the [Gemkit release guide](https://github.com/ethos-link/ethos-gemkit#releasing-a-gem).
