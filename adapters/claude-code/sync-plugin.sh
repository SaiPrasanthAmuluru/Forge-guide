#!/usr/bin/env bash
# sync-plugin.sh - copy the Claude Code skill wrappers and reviewer into the plugin folder so the
# plugin and the manual-install files never drift. `--check` only compares (used by CI).
# The plugin lives at adapters/claude-code/plugin/. Bash 3.2 / BSD safe.
set -eu
src="$(cd "$(dirname "$0")" && pwd)"; dst="$src/plugin"
if [ "${1:-}" = "--check" ]; then
  diff -r "$src/skills" "$dst/skills" >/dev/null && diff "$src/forge-reviewer.md" "$dst/agents/forge-reviewer.md" >/dev/null \
    || { echo "plugin copy is out of date: run scripts/sync-plugin.sh" >&2; exit 1; }
  echo "plugin copy is in sync"; exit 0
fi
mkdir -p "$dst/skills" "$dst/agents"
cp -R "$src"/skills/. "$dst/skills/"
cp "$src/forge-reviewer.md" "$dst/agents/forge-reviewer.md"
echo "synced skills and reviewer into $dst"
