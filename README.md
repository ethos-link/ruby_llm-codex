# RubyLLM Codex provider

This small adapter lets RubyLLM invoke the official local Codex CLI as a
provider. Codex reuses the ChatGPT login stored by `codex login`, so these runs
consume your Codex subscription allowance rather than OpenAI API credits.

The intended use is controlled prompt comparison, especially structured-output
experiments. It is not intended to turn a personal ChatGPT subscription into a
public API.

This measures **Codex harness output**, not a raw model API response. Codex adds
its own base agent instructions and runtime behavior. RubyLLM system messages
are layered in as Codex developer instructions, which is the closest supported
mapping but not an identical wire-level experiment.

## Requirements

- Ruby 3.1.3 or newer
- RubyLLM 1.16.0 or newer, below 2.0
- Codex CLI 0.144.5 or newer, available as `codex`
- Linux or macOS (timeout cleanup relies on POSIX process groups)
- A completed ChatGPT login: `codex login`

Install Codex if necessary:

```bash
npm install -g @openai/codex
codex login
```

Check the model list in your installed Codex version before a large run. Model
availability depends on the account and currently installed CLI.

Run the automated unit tests and the two-request live smoke task with:

```bash
bundle exec rake test
bundle exec rake codex:smoke
```

The smoke task verifies the installed CLI version, then performs one plain-text
completion and one structured-output completion through the real RubyLLM
provider. It consumes Codex subscription allowance and requires a completed
login. Set `CODEX_MODEL`, `CODEX_BIN`, or `CODEX_TIMEOUT` to override its model,
executable, or 300-second request timeout.

For local development, add this project to your application:

```ruby
gem "ruby_llm-codex", path: "/path/to/ruby_llm-codex"
```

Then use it like any explicit RubyLLM provider:

```ruby
require "ruby_llm-codex"

class ResultSchema < RubyLLM::Schema
  string :summary
  integer :score
end

response = RubyLLM.chat(model: "gpt-5.6-luna", provider: :codex)
  .with_instructions("Evaluate the supplied text consistently.")
  .with_schema(ResultSchema)
  .with_thinking(effort: :medium)
  .ask("The text to evaluate")

pp response.content
```

`response.content` is normalized by RubyLLM into the same Hash shape returned
for structured outputs from its other providers.

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
saved session history from quietly affecting a comparison.

To deliberately let Codex inspect a repository or use selected configuration:

```ruby
chat.with_params(
  codex: {
    working_directory: Rails.root.to_s,
    sandbox: "read-only",
    ignore_user_config: false,
    ephemeral: true,
    timeout: 300,
    shell_environment_inherit: "none"
  }
)
```

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

Only the nested `codex` namespace is accepted by `with_params`; unsupported
generic params raise an error instead of being silently ignored. Use
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
  and simple comparisons over throughput.
- Multi-turn RubyLLM histories are serialized into a role-labelled transcript.
  One-shot `with_instructions(...).ask(...)` experiments have the cleanest
  semantic mapping.

If you later need streaming, persistent threads, or high throughput, replace
the process-per-request implementation with a long-running `codex app-server`
client while keeping the same RubyLLM provider surface.

## Development

```bash
git clone https://github.com/ethos-link/ruby_llm-codex.git
cd ruby_llm-codex

bundle install
bundle exec rake
```

The default Rake task runs the unit suite and Standard Ruby. CI runs the same
gate on Ruby 3.1.3, 3.4, and 4.0.3, then validates commit messages and
git-cliff changelog generation.

The authenticated smoke task is intentionally separate because it consumes
Codex subscription allowance:

```bash
bundle exec rake codex:smoke
```

When changing process lifecycle or shell execution, run that task inside a
bounded process and memory scope.

### Git hooks

This repository uses [lefthook](https://lefthook.dev/) and the Ruby
[commitlint](https://github.com/arandilopez/commitlint) gem. Hooks reject direct
commits to `main` or `master`, validate Conventional Commit messages, and run
Standard Ruby.

Install them once per clone:

```bash
bundle exec lefthook install
```

## Release

Releases are tag-driven. Local release commands prepare the changelog, version
commit, and tag; GitHub Actions runs the full test matrix, publishes through
RubyGems trusted publishing, and creates the GitHub release from
`CHANGELOG.md`.

Install [git-cliff](https://git-cliff.org/) locally, check out a clean `main`,
and run one of:

```bash
bundle exec rake 'release:prepare[patch]'
bundle exec rake 'release:prepare[minor]'
bundle exec rake 'release:prepare[major]'
bundle exec rake 'release:prepare[0.2.0]'
```

The task:

1. Prepends the next changelog section from Conventional Commits.
2. Updates `lib/ruby_llm/codex/version.rb`.
3. Commits the release files and creates `vX.Y.Z`.
4. Pushes `main` and the tag to `origin`.

Before the first automated release, configure the gem's RubyGems trusted
publisher with owner `ethos-link`, repository `ruby_llm-codex`, workflow
`release.yml`, and environment `release`. The environment name must match the
protected GitHub environment used by the release job.

## Contributing

Create a non-main branch, keep commits scoped and conventional, run
`bundle exec rake`, and open a pull request against `main`.

## License

MIT License. See [LICENSE](LICENSE).
