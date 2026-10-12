# Upgrade Guide

## RubyLLM 2.1

This provider now requires RubyLLM `~> 2.1.1` and Codex CLI 0.162.1 or newer.
RubyLLM 1.x and 2.0 are no longer supported. Upgrade the CLI with
`npm install -g @openai/codex` and check `codex --version`.

Host applications must:

- Replace `with_params(codex: ...)` with `with_provider_options(codex: ...)`.
- Replace `RubyLLM::Schema` with `Schematist::Schema`.
- Read structured results through `response.parsed`; `response.content` is
  now a JSON string.
- Read the model ID from `response.model` and usage from `response.tokens`:
  `input`, `output`, `cache_read`, and `thinking`. Input excludes cached tokens;
  output includes thinking tokens. Unreported counts remain `nil`.

Plain Ruby consumers can update directly after adapting these calls. Rails
hosts using RubyLLM persistence must complete the
[2.0 upgrade](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md)
on 2.0, including cleanup, before following the
[2.1 upgrade](https://rubyllm.com/upgrading/). On Rails below 8.1.4, pin `json`
to `< 3` before updating.

Each Codex invocation records successful or failed usage attempts in RubyLLM.
Timeouts cover process exit and pipe draining, including descendants that keep
output pipes open after the CLI exits. Process-group cleanup remains bounded.
