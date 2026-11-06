# Forge-guide plugin (Claude Code)

Bundles the seven task skills (`forge-*`), the read-only `forge-reviewer` subagent and the PR gate
hook. It does not bundle the scripts, playbooks or rules: those stay in the Forge-guide clone, so
there is one copy. The plugin finds them through `FORGE_HOME`.

```bash
git clone https://github.com/SaiPrasanthAmuluru/Forge-guide ~/Apps/Forge-guide
~/Apps/Forge-guide/install.sh --profile        # sets FORGE_HOME, checks the scripts
```

Then in Claude Code:

```bash
/plugin marketplace add SaiPrasanthAmuluru/Forge-guide
/plugin install forge-guide@forge-guide
```

Upgrade: `git pull` in the clone, then `/plugin marketplace update forge-guide`. Plugins cannot set
permissions, so merge the read-only block from `adapters/claude-code/settings.json` into
`~/.claude/settings.json` yourself (replace `<TOOLKIT>`).

The files here are copies made by `adapters/claude-code/sync-plugin.sh` from `adapters/claude-code/skills/` and
`forge-reviewer.md`; CI fails if they drift. Edit the originals, then run the script.
