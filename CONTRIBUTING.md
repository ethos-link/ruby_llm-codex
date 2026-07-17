# Contributing

Thank you for helping improve `ruby_llm-codex`.

## Before opening a change

- Use an issue for user-visible behavior changes or proposals that need design
  agreement.
- Use [GitHub's private vulnerability reporting](SECURITY.md) for security
  issues; do not disclose them publicly.
- Keep the adapter's scope narrow: non-streaming RubyLLM chat through the local
  Codex CLI, with isolation and reproducibility as defaults.

## Development setup

```bash
git clone git@github.com:ethos-link/ruby_llm-codex.git
cd ruby_llm-codex
bundle install
bundle exec lefthook install
bundle exec rake
```

The authenticated smoke test is separate because it invokes the real Codex CLI
and consumes subscription allowance:

```bash
bundle exec rake codex:smoke
```

Run it inside an appropriate process and memory boundary when changing process
lifecycle, timeout, or shell configuration behavior.

## Pull requests

1. Create a branch; hooks reject direct commits to `main` and `master`.
2. Add focused tests for behavior changes.
3. Run `bundle exec rake` and any relevant live smoke coverage.
4. Use Conventional Commits, including a meaningful body for non-trivial work.
5. Update `README.md` and `CHANGELOG.md` when user-facing behavior changes.
6. Open a pull request against `main` and explain the behavior, risks, and
   verification performed.

Do not include generated gems from `pkg/`, credentials, Codex session data, or
unrelated formatting changes.

## Releases

Only maintainers publish releases. See [docs/releasing.md](docs/releasing.md) for
the controlled release procedure.
