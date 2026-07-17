# Releasing ruby_llm-codex

Releases are immutable, tag-driven, and published by GitHub Actions through
RubyGems trusted publishing. Maintainers do not need a RubyGems API key.

## One-time repository setup

1. Push `main` to `git@github.com:ethos-link/ruby_llm-codex.git`.
2. In GitHub, create an environment named `release`. Add required reviewers if
   the organization requires a manual publication gate.
3. Protect `main`, require pull requests, and require the Ruby, Commitlint, and
   Changelog checks before merging.
4. In the RubyGems account that will own the gem, create a
   [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers)
   with these exact values:

   | Field | Value |
   | --- | --- |
   | Gem name | `ruby_llm-codex` |
   | GitHub owner | `ethos-link` |
   | Repository | `ruby_llm-codex` |
   | Workflow | `release.yml` |
   | Environment | `release` |

The workflow grants `id-token: write` only to the release job. RubyGems exchanges
that GitHub OIDC identity for short-lived credentials during publication.

## Publish 0.1.0

The initial version and changelog are already committed. After the one-time
setup and a successful CI run on `main`, create and push its annotated tag:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

The tag starts the Release workflow. The regular release task below handles
every subsequent version.

## Later releases

Install [git-cliff](https://git-cliff.org/), start from a clean and current
`main`, and choose the intended version increment:

```bash
git switch main
git pull --ff-only
bundle exec rake 'release:prepare[patch]'
```

Use `minor`, `major`, or an explicit version such as `0.2.0` when appropriate.
The task updates the changelog and version constant, creates the release commit
and annotated tag, and pushes both.

## Verify a release

The Release workflow must complete all of the following:

1. Pass the supported-Ruby test and style matrix.
2. Confirm that the tag matches `RubyLLM::Codex::VERSION`.
3. Find a matching `CHANGELOG.md` section.
4. Build and push the gem to RubyGems.
5. Create the GitHub release from the changelog entry.

Afterward, verify the version on
[RubyGems](https://rubygems.org/gems/ruby_llm-codex) and install it in a clean
environment before announcing the release.

## Failure handling

- If CI fails before publication, fix the failure on a branch. Delete and
  recreate the tag only if RubyGems does not contain that version.
- If RubyGems contains the version, never overwrite or reuse it. Fix forward
  with a new patch release.
- If gem publication succeeds but GitHub release creation fails, create the
  GitHub release for the existing tag using the matching changelog section.
- Never commit a RubyGems API key or add one as a repository secret for this
  workflow.
