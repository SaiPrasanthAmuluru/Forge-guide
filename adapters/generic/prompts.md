# Generic prompts (any agent)

Replace `<TOOLKIT>` with the path to your Forge-guide clone (for example `~/Apps/Forge-guide`).
Start the agent in the project you are working on, not in the toolkit folder. Optional:
`export FORGE_HOME=<TOOLKIT>` in your shell profile so scripts and agents can find it.

## Review a pull request

1. In the project: `<TOOLKIT>/scripts/pr-range.sh <PR number or URL>` (prints base and head).
2. Open a fresh session and paste:

> Use `<TOOLKIT>/review/review-prompt.md` as the review rubric. Base `<sha>`, head `<sha>`.
> Mode: standard. PR description: ...
> Read-only: do not edit, stage or commit anything, and do not ask for permission to read.
> Run `<TOOLKIT>/scripts/review-prep.sh <PR number or URL>` once instead of the scripts one by one.

## Review local changes before committing

1. In the project: `<TOOLKIT>/scripts/local-changes.sh`.
2. Open a fresh session and paste:

> Use `<TOOLKIT>/review/review-prompt.md` to review my uncommitted local changes. Mode: standard.
> Read-only: do not edit, stage or commit anything.

## Generate or change code

> Follow `<TOOLKIT>/AGENTS.md` for this task: <what you want>.
> Fit the existing code, change only what the spec names, and do not stage, commit, push or open a PR (and do not ask whether to).

## Report on a batch of work

> Use `<TOOLKIT>/skills/session-report.md` to write one report of this session. Run
> `<TOOLKIT>/scripts/report-metrics.sh` first for the numbers.

## If the agent cannot run shell commands

Run the script yourself and paste its output into the session, or tell the agent to use
`git diff <base>...<head>` and text search instead. The scripts only speed up triage and the
impact and reuse checks; the rubric works without them, with lower coverage that the review's
Coverage line should state.
