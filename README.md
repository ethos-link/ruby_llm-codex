# RubyLLM Codex

Use the local Codex CLI as a RubyLLM provider for text and structured output.

For Ruby applications using RubyLLM with the local Codex generation harness. This is an independent adapter. It supports non-streaming text and structured output; attachments, RubyLLM tools and temperature are rejected. It does not offer a raw model API request path.

[Project and full documentation](https://www.ethos-link.com/opensource/ruby-llm-codex) · [RubyGems](https://rubygems.org/gems/ruby_llm-codex) · [Changelog](CHANGELOG.md)

## Requirements

Ruby 4.0 or newer; RubyLLM 2.1.1 or newer, below 2.2; Codex CLI 0.162.1 or newer on PATH; Linux or macOS. Complete `codex login` and select a model available to that account.

## Installation

```sh
gem install ruby_llm-codex
```

## Quick start

```ruby
require "ruby_llm-codex"

response = RubyLLM.chat(
  model: ENV.fetch("CODEX_MODEL"), provider: :codex
).ask("Reply with a short greeting.")

puts response.content
```

Set `CODEX_MODEL` to a model available in your installed Codex CLI. After login, the request starts a local `codex exec` process and prints its text response. It uses the Codex account’s access and usage limits; the gem does not accept an OpenAI API key.

See the [full documentation](https://www.ethos-link.com/opensource/ruby-llm-codex) for configuration, workflows, operational details and limitations.
For existing installations, read [UPGRADE.md](UPGRADE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

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
in the [Gemkit release guide](https://www.ethos-link.com/opensource/ethos-gemkit#releasing-a-gem).

## About Ethos Link

[Ethos Link](https://www.ethos-link.com) is a software company founded by
[Paulo Fidalgo](https://www.fidalgo.pt). We publish these Ruby tools alongside
our business products:

- [Reviato](https://www.reviato.com): private customer feedback and public review analysis.
- [Nuntio](https://www.nuntiohq.com): prepare, review and schedule social posts.
- [EthosPlaces](https://www.ethos.place): find places, opening hours and contact details.

## License

MIT. See [LICENSE](LICENSE).
