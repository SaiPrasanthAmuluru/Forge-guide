# CI adapters (any host, any agent)

`scripts/ci-review.sh` is the one piece that does the work. A host template only wires it into a
CI system. The runner:

1. writes a review request (rubric path, base and head, what to run),
2. pipes it to **your agent command** (`FORGE_AGENT_CMD`: reads stdin, prints the review),
3. refuses to post anything that lacks the `Reviewed:` header,
4. posts the result as a pull request comment on GitHub, Azure DevOps, GitLab or Bitbucket.

| Host | Template | Comment goes to | Credential |
|---|---|---|---|
| Azure DevOps | `azure-pipelines.yml` | PR thread (REST `pullRequests/<id>/threads`) | `System.AccessToken` (needs "Contribute to pull requests") |
| GitLab | `gitlab-ci.yml` | MR note | `GITLAB_TOKEN` project access token, `api` scope |
| Bitbucket Cloud | `bitbucket-pipelines.yml` | PR comment | `BITBUCKET_TOKEN` repo access token, PR write |
| GitHub | `github-actions.yml` | PR comment | the job's `github.token` |

## What your agent command must do

Read the request on stdin and print only the finished Markdown review. It runs in the checkout, so
it must be allowed to read files, run read-only git commands and the toolkit scripts, and nothing
else (no edits, no pushes). Set that restriction with your agent's own permission settings.
Example values for `FORGE_AGENT_CMD` (an agent in non-interactive print mode with read-only tools)
are in your agent's documentation; keep the credential in a secret variable, never in the YAML.

## What the runner does for safety

- The agent runs with the host tokens (`GH_TOKEN`, `GITHUB_TOKEN`, `SYSTEM_ACCESSTOKEN`,
  `GITLAB_TOKEN`, `BITBUCKET_TOKEN`) removed from its environment, because it reads untrusted PR
  content. Only the posting step uses them.
- It posts only if the first non-blank line of the output starts with `Reviewed: `.
- Templates clone Forge-guide at the release tag `v0.1.1`. Create that tag in Forge-guide before
  using them (`git tag v0.1.1 && git push origin v0.1.1`), or change it to `main` to track latest.
- The comment carries a hidden marker. On the next push the runner finds its earlier comment by
  that marker and edits it in place; if the lookup or the edit fails it posts a new comment
  instead. `FORGE_REVIEW_MODE=new` always posts a new one. The lookup reads the first 100
  comments and is checked only against a mock server, so confirm it on your host (Azure DevOps
  first: it also needs "Contribute to pull requests" to edit).

## Test before trusting

The runner's request building, output refusal and comment posting were tested against a local mock
server for all four hosts; the templates and the real host APIs have not been run end to end.
Try one throwaway PR per host. `ci-review.sh --dry-run` prints the request without running anything.

The diff is sent to whatever model your agent command uses, so enable this only on repositories
where that is allowed.
