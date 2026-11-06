# Claude Code adapter

Optional files. Everything else in the toolkit works without them.

- `forge-reviewer.md` - a read-only reviewer subagent (tools: Read, Grep, Glob, Bash; model set
  explicitly, raise it for `strict` reviews of auth, session or persistence work). Install it for
  all projects:

  ```bash
  mkdir -p ~/.claude/agents
  cp <TOOLKIT>/adapters/claude-code/forge-reviewer.md ~/.claude/agents/
  ```

  Then call it with `forge-reviewer: review <base>..<head>` (or `review my uncommitted changes`).
  It finds the toolkit through `FORGE_HOME`, so add `export FORGE_HOME=<TOOLKIT>` to your shell
  profile.

- `settings.json` - registers `scripts/pr-gate.sh` as a PreToolUse hook that stops the agent from
  opening a pull request by itself (the developer decides). Merge its `hooks` block into
  `~/.claude/settings.json`, then check `/hooks`. `FORGE_ALLOW_PR=on` lets one session through.

- `skills/forge-*/SKILL.md` - one thin wrapper per workflow file in `skills/` (new feature, bug fix,
  refactor, API integration, spec builder, build context, session report), so Claude Code can
  load them as skills by name. Each wrapper only points at the toolkit file, so the workflow stays
  in one place. Install for all projects:

  ```bash
  mkdir -p ~/.claude/skills
  cp -R <TOOLKIT>/adapters/claude-code/skills/forge-* ~/.claude/skills/
  ```

  They read the toolkit through `FORGE_HOME`, as the reviewer does.

`CLAUDE.md` in the repo root only imports `AGENTS.md` and adds Claude Code notes, for the case
where Claude Code is pointed at this repo directly.

## Faster reviews, fewer prompts

A review only reads, so it should not need approvals. Two things caused the waiting:

1. **Many small commands.** Each script ran as its own command, one after another. Use
   `scripts/review-prep.sh <PR number|URL|branch>` once (`--local`, `--unpushed`): it runs triage,
   impact scan, reuse scan and playbook index at the same time and prints one report.
2. **Prompts for reads.** `settings.json` now has a read-only `permissions` block. Replace
   `<TOOLKIT>` (in `allow` and `additionalDirectories`) with your absolute toolkit path, e.g.
   `/Users/you/Apps/Forge-guide`, and merge it into `~/.claude/settings.json`. It allows Read, Grep,
   Glob, read-only git and the toolkit scripts, and lets the agent read the toolkit folder.

Still prompts, by design: edits, `git commit/add/push`, and commands chained with pipes, `&&` or
`$(...)` (allow-rules match one command). The agent rules say not to commit or push unasked.
`pr-range.sh` fetches the PR into private refs under `refs/forge/` (nothing in your branches).

## Install options

- **Script:** `adapters/claude-code/install.sh` copies the skill wrappers and reviewer into `~/.claude`.
  Run the toolkit's `./install.sh --profile` first to set `FORGE_HOME`.
- **Plugin:** `plugin/` bundles the wrappers, reviewer and PR gate hook for `/plugin install`
  (see `plugin/README.md`). Use one route, not both. `sync-plugin.sh` keeps its copies in step with
  the files above; CI checks it.
Both need the Forge-guide clone, because the scripts and rules are read from it.

## Scheduled reviews on your own machine (no CI, no repo secrets)

`scripts/review-poll.sh` checks your repos for open, non-draft PRs whose latest commit has not been
reviewed, runs the agent on each, and saves the review under `~/.forge/reviews/`. It never comments
unless you pass `--post`. It uses your own signed-in `claude` and `gh`, so there is no API key and
nothing is added to the repos. It only runs while the Mac is awake and you are logged in.

1. `mkdir -p ~/.forge`, then list the repos in `~/.forge/repos.txt`, one per line:
   `owner/repo /absolute/path/to/local/clone`
2. Put the agent command on one line in `~/.forge/agent-cmd` (replace `<TOOLKIT>` with the absolute
   toolkit path):

   ```bash
   claude -p --model sonnet --max-turns 40 --allowedTools "Read Grep Glob Bash(git diff:*) Bash(git log:*) Bash(git show:*) Bash(git grep:*) Bash(git rev-parse:*) Bash(git merge-base:*) Bash(git fetch:*) Bash(<TOOLKIT>/scripts/review-prep.sh:*) Bash(<TOOLKIT>/scripts/pr-range.sh:*) Bash(<TOOLKIT>/scripts/playbook.sh:*)"
   ```

3. Try it by hand first: `<TOOLKIT>/scripts/review-poll.sh --dry-run`, then without `--dry-run`.
4. Schedule it: copy `launchd/com.forgeguide.review-poll.plist` (edit `<TOOLKIT>`) to
   `~/Library/LaunchAgents/` and `launchctl load` it. `launchd` is used instead of cron because it
   runs in your login session, where `claude` and `gh` can read their saved sign-ins.
5. Background `git fetch` cannot type a key passphrase: load the key once with
   `ssh-add --apple-use-keychain ~/.ssh/<key>` (or use an HTTPS remote).

`--max N` caps reviews per run so one burst of PRs cannot use up your plan limit. The command
syntax for `--allowedTools` is untested here; if reviews come back empty, read `~/.forge/poll.log`.

Disk use: one small file per reviewed commit (about 15 KB) in `~/.forge/reviews/`. Each run checks
the PR's status with `gh`: a merged or closed PR's reviews are deleted once it has been closed for 2
days (`FORGE_CLOSED_DAYS`), an open PR keeps only its 2 newest reviews, and anything older than 30
days (`FORGE_KEEP_DAYS`) goes regardless. `poll.log` stays under about 1 MB. Without network, only the
age rule runs.

## Watching active PRs and getting notified (any host, no CLI)

`scripts/pr-watch.sh` uses only `git ls-remote` on your clone, so it works with Azure DevOps and
GitHub through the git login you already have, with no `az`, `gh` or token. It tells you (macOS
notification and `~/.forge/watch.log`) when a PR is new or has new commits, and forgets a PR when it
completes. It posts nothing.

1. `~/.forge/watch-repos.txt`, one line per repo: `label /absolute/path/to/clone`.
2. Try it: `<TOOLKIT>/scripts/pr-watch.sh --dry-run`. The first real run only records the PRs that
   already exist, so you are not flooded.
3. Schedule it: copy `launchd/com.forgeguide.pr-watch.plist` to `~/Library/LaunchAgents/`, replace
   `<TOOLKIT>` and `<HOME>`, `launchctl load` it (every 10 minutes while you are logged in).
4. Reviews are on demand by default: when a notification arrives, run `forge-reviewer: review PR <n>`.
   `--review` (add it as a string element in the plist arguments, optionally `--max N`) runs your `~/.forge/agent-cmd` on
   each new or updated PR and saves the review under `~/.forge/reviews/`. That reads every PR in the
   repo, not only yours, and uses your plan: prefer a Sonnet command in `agent-cmd`, and leave it
   off for busy repos.
Background `git ls-remote` cannot type a passphrase or a password: use an HTTPS remote with the
keychain helper or an SSH key loaded with `ssh-add --apple-use-keychain`. A PR with merge conflicts
has no merge ref, so it will not be listed.

### Reading PR comments on Azure DevOps (optional, needs one token)

Git has the code but not the PR description or review threads, so without this a review cannot see
what others already said and says "Existing comments: not run - no thread access". `scripts/pr-threads.sh <PR>`
reads them from Azure DevOps, read-only, and the reviewer and `pr-watch.sh --review` use it
automatically when a token exists.

1. In Azure DevOps: User settings > Personal access tokens > New token, scope **Code (Read)** only,
   shortest expiry you can live with. Check that your organisation allows personal tokens.
2. Save it in the macOS Keychain (it prompts for the value, so it never lands in shell history):
   `security add-generic-password -a "$USER" -s forge-azure-pat -w`
3. Test inside the work clone: `<TOOLKIT>/scripts/pr-threads.sh <a PR number>`. It should print the
   title, description and threads.
4. Add `"Bash(<TOOLKIT>/scripts/pr-threads.sh:*)"` to `permissions.allow` in `~/.claude/settings.json`.
The token can read code and PRs in that project, nothing else. It needs `curl` and `python3`
(both are on a Mac with the developer tools installed). The script was tested against a fake
server only; check it once on a real PR.

### Review cost on big PRs

Reading is most of a review's cost. `review-prep.sh` caps full reading at 1500 changed lines by default
(`FORGE_READ_BUDGET=3000` raises it, `0` removes it). HIGH-risk files are always kept; the rest are
listed under NOT REACHED and named in the review as not reviewed, and you can ask for a second pass
on them. The reviewer reads the diff in batches, not whole files. To measure, note the "tool uses,
tokens, time" on the agent's finished line before and after.
