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
