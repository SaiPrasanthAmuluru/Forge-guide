# GitHub Actions adapter

Two workflows, both optional. For a host- and agent-neutral setup (GitHub, Azure DevOps, GitLab,
Bitbucket) use `adapters/ci/` instead; this folder is the vendor-action alternative.

- `.github/workflows/checks.yml` (in this repo, already active): parses every script, checks the
  executable bits, runs `scripts/neutrality-check.sh`, and rejects long dashes. No secrets, so it
  also runs on fork PRs.
- `pr-review.yml` (this folder): a template. Copy it to `.github/workflows/forge-review.yml` in
  any repository to get an automatic review comment on each opened or updated pull request. It
  checks out Forge-guide next to the project, so nothing is copied into the project.

## Token exposure in this variant

The agent in `pr-review.yml` is allowed `gh pr comment`, so it holds a token that can write to the
PR while it reads untrusted PR content. That is by design here. If you want the agent kept away
from any write token, use `adapters/ci/`: `scripts/ci-review.sh` runs the agent with the host
tokens removed from its environment, then posts the comment itself in the same run.

## Setup for the review workflow

1. Save a model credential as a repo secret (`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`,
   or an API key; check that your plan allows using it in CI).
2. Settings > Actions > General > Workflow permissions: Read and write.
3. Copy `pr-review.yml` to `.github/workflows/forge-review.yml` and commit it.
4. Open a throwaway PR and watch the Actions tab. The review appears as one comment that is
   updated on each push.

Pin `ref:` to a tag or commit SHA once Forge-guide has one. PRs from forks are skipped because
GitHub withholds secrets from them. The diff goes to the model provider you configure, so use this
only on repositories where that is allowed.
