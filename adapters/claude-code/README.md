# Claude Code adapter

Optional files. Everything else in the toolkit works without them.

- `forge-reviewer.md` - a read-only reviewer subagent (tools: Read, Grep, Glob, Bash; model set
  explicitly, raise it for `strict` reviews of auth, session or persistence work). Install it for
  all projects:

  ```
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

  ```
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
   ```
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
