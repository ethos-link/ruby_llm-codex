# Security policy

## Supported versions

Security fixes are provided for the latest released version. Because the gem is
pre-1.0, upgrades may include small compatibility changes documented in the
changelog.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's private
vulnerability reporting for this repository. If that is unavailable, email
`devel@ethos-link.com` with:

- the affected version and platform;
- a minimal reproduction or proof of concept;
- the expected security impact;
- any suggested mitigation; and
- whether the issue is already public.

You should receive an acknowledgement within five business days. We will
coordinate validation, remediation, and disclosure with the reporter.

## Security boundaries

This gem starts the locally installed Codex CLI and reuses its existing ChatGPT
authentication. It does not collect, proxy, or store credentials. By default it
runs Codex in a fresh temporary directory, disables interactive approvals and
shell snapshots, uses a read-only sandbox, and does not inherit the parent
process environment for model-generated shell commands.

Applications that override the working directory, sandbox, user configuration,
or environment inheritance assume responsibility for the additional access
granted to Codex.
