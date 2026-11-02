#!/usr/bin/env bash
# install.sh - set up Forge-guide on this machine. Nothing leaves the machine and nothing is
# installed from the network; it only points your shell at this folder.
#
#   ./install.sh                  check the toolkit and print what to add (changes nothing)
#   ./install.sh --profile        also add `export FORGE_HOME=...` to your shell profile (once)
# Bash 3.2 / BSD safe.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
want_profile=0
for a in "$@"; do
  case "$a" in
    --profile) want_profile=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

echo "Toolkit: $here"
[ -f "$here/AGENTS.md" ] && [ -d "$here/scripts" ] || { echo "This does not look like the Forge-guide folder." >&2; exit 1; }
chmod +x "$here"/scripts/*.sh "$here/install.sh" 2>/dev/null || true
"$here/scripts/playbook.sh" stacks >/dev/null 2>&1 && echo "ok: scripts run" || echo "warning: scripts/playbook.sh did not run"

case "${SHELL:-}" in */zsh) prof="$HOME/.zshrc" ;; */bash) prof="$HOME/.bash_profile" ;; *) prof="$HOME/.profile" ;; esac
line="export FORGE_HOME=\"$here\""
if [ "$want_profile" = 1 ]; then
  if grep -qs '^export FORGE_HOME=' "$prof"; then echo "FORGE_HOME already set in $prof (left alone)"
  else printf '\n# Forge-guide\n%s\n' "$line" >> "$prof"; echo "added FORGE_HOME to $prof; open a new terminal or run: source $prof"; fi
else
  echo "Add this to $prof (or re-run with --profile):"; echo "  $line"
fi


echo
echo "Still manual (so you stay in control of your settings):"
echo "  - your agent's wiring (skills, reviewer, permissions) lives in adapters/<tool>/README.md"
echo "  - agents read $here/AGENTS.md; for a project that should use it, add a line to its CLAUDE.md or AGENTS.md"
