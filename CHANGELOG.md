# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-17

### Added

- Add a local Codex CLI provider for RubyLLM plain-text and structured-output
  requests.
- Add isolated execution defaults, timeout handling, and process-group cleanup.
- Add live smoke coverage for plain-text and structured-output requests.
- Add CI, Conventional Commit checks, changelog validation, and tag-driven
  RubyGems trusted publishing.
- Document installation, configuration, limitations, troubleshooting,
  contribution, security, and release procedures.

### Fixed

- Disable unnecessary Codex shell snapshots to prevent Bash process explosions
  during completion-only runs.
- Align the documented Ruby requirement, CI matrix, syntax target, and locked
  development dependencies on Ruby 3.3 or newer.
- Generalize documentation examples and live smoke configuration for public
  reuse.
