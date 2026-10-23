#!/usr/bin/env bash
# pr-gate.sh - optional PreToolUse hook for the Bash tool.
# Whether to open a pull request is the developer's decision, not the agent's. This hook stops
# an agent from running `gh pr create` / `az repos pr create` on its own initiative.
# Reads the hook JSON on stdin; exit 2 + stderr = block and tell the agent why.
# The developer opts in for a session or a command with FORGE_ALLOW_PR=on (or removes the hook).
# No python or other dependency: it only needs bash and grep.
set -u
[ "${FORGE_ALLOW_PR:-off}" = "on" ] && exit 0
[ "${FORGE_GATE:-on}" = "off" ] && exit 0
input="$(cat)"
printf '%s' "$input" | grep -Eq '(az[[:space:]]+repos[[:space:]]+pr[[:space:]]+create|gh[[:space:]]+pr[[:space:]]+create)' || exit 0

echo "Blocked: opening a pull request is the developer's decision. Do not create one. Finish with the handoff (what changed, what was left alone, how to check it) and let the developer raise the PR. If they have asked you to, they can set FORGE_ALLOW_PR=on for this session." >&2
exit 2
