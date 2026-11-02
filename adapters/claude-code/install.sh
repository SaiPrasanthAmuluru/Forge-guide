#!/usr/bin/env bash
# install.sh (Claude Code) - copy the skill wrappers and the read-only reviewer into ~/.claude.
# Run the toolkit's top-level install.sh first so FORGE_HOME is set. The plugin is the other
# route (see plugin/README.md); use one or the other, not both. Changes only ~/.claude/skills
# and ~/.claude/agents; settings.json is left for you to merge. Bash 3.2 / BSD safe.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.claude/skills" "$HOME/.claude/agents"
cp -R "$here"/skills/forge-* "$HOME/.claude/skills/"
cp "$here/forge-reviewer.md" "$HOME/.claude/agents/"
echo "copied the skill wrappers to ~/.claude/skills and forge-reviewer to ~/.claude/agents"
echo "Next: merge $here/settings.json into ~/.claude/settings.json (replace <TOOLKIT> with your toolkit path)."
