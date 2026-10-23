#!/usr/bin/env bash
# pr-gate.sh - PreToolUse hook for the Bash tool. Blocks raising a PR while the most
# recently touched spec's "Independent pass" checkbox in verification.md is unticked.
# Reads the hook JSON on stdin; exit 2 + stderr = block and tell the agent why.
# No specs folder / no verification.md -> allow (nothing to enforce). FORGE_GATE=off skips.
set -u
[ "${FORGE_GATE:-on}" = "off" ] && exit 0
input="$(cat)"
cmd="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")' 2>/dev/null)"
printf '%s' "$cmd" | grep -Eq '(az[[:space:]]+repos[[:space:]]+pr[[:space:]]+create|gh[[:space:]]+pr[[:space:]]+create)' || exit 0

# The project's specs: <project>/specs/ (toolkit used as the project) or <project>/.forge/specs/
# (toolkit kept outside the project). Project = CLAUDE_PROJECT_DIR, else FORGE_PROJECT, else the
# git toplevel of the current directory.
root="${CLAUDE_PROJECT_DIR:-${FORGE_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}}"
latest=""
while IFS= read -r f; do latest="$f"; break; done < <(ls -t "$root"/specs/*/verification.md "$root"/.forge/specs/*/verification.md 2>/dev/null | grep -v '/template/')
[ -z "$latest" ] && exit 0

unticked="$(awk '/^## Independent pass/{s=1;next} /^## /{s=0} s && /^[[:space:]]*- \[ \]/{c++} END{print c+0}' "$latest")"
if [ "$unticked" -gt 0 ]; then
  echo "Blocked: independent pass not ticked in $latest. Run the forge-reviewer subagent (or get a human review), tick the line with its verdict, then raise the PR. To skip deliberately: say so and set FORGE_GATE=off." >&2
  exit 2
fi
exit 0

