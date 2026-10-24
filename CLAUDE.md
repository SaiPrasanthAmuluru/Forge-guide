# Project instructions

@AGENTS.md

## Claude Code notes

The rules above are the whole workflow; this file only adds what is specific to Claude Code.

- Read the token readout with `/cost` (or `/context`) before and after each task for the ledger.
- The read-only reviewer is the `forge-reviewer` subagent (`adapters/claude-code/forge-reviewer.md`);
  its fresh context counts as the independent pass. Call it with
  `forge-reviewer: review <base>..<head>`.
- `adapters/claude-code/settings.json` registers `scripts/pr-gate.sh` as a PreToolUse hook that
  stops the agent from opening PRs (the developer decides); merge it into `~/.claude/settings.json`
  and export `FORGE_HOME` (see `adapters/claude-code/README.md`).
