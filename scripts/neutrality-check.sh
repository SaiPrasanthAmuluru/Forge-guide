#!/usr/bin/env bash
# neutrality-check.sh - keeps the core of the toolkit agent-agnostic and stack-agnostic.
# Fails (exit 1) when a core file names a specific AI agent/vendor or a specific platform stack.
# Usage: scripts/neutrality-check.sh        (run from anywhere; checks the toolkit it lives in)
#
# Where those names ARE allowed (they are the point of those files):
#   adapters/              tool-specific wiring
#   CLAUDE.md              the compatibility shim for tools that look for that file name
#   playbooks/<stack>.md   per-stack lessons (ios-swift.md ships as the worked example)
#   scripts/probes/        per-stack probe extras
#   review/regressions.md  real past cases
#   scripts/impact.sh, scripts/reuse-scan.sh, scripts/map-probe.sh, scripts/diff-scope.sh
#                          language heuristics (stack words allowed, agent names are not)
#   README.md              may state which languages the heuristics cover (stack words only)
# A single line can opt out with the marker  forge-allow  (use sparingly, say why).
# Bash 3.2 / BSD safe: only grep and sh.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1
AGENT='(^|[^a-z])(claude|anthropic|openai|chatgpt|gemini|copilot|cursor|codex|windsurf|aider|cline|spec-?kit|bmad|superpowers)([^a-z]|$)'
STACK='(^|[^a-z])ios([^a-z]|$)|swift|xcode|pbxproj|core ?data|uikit|cocoapods|nsmanaged|\.plist|IOS-[0-9]'
fail=0
list="$(find . -type f ! -path './.git/*' ! -name '.DS_Store' | sed 's#^\./##' | sort)"
while IFS= read -r f; do
  case "$f" in
    adapters/*|CLAUDE.md|LICENSE|scripts/neutrality-check.sh|scripts/probes/*|review/regressions.md|playbooks/ios-swift.md) continue ;;
  esac
  case "$f" in *.png|*.jpg|*.zip) continue ;; esac
  stack_ok=0
  case "$f" in scripts/impact.sh|scripts/reuse-scan.sh|scripts/map-probe.sh|scripts/diff-scope.sh|context/risk-paths.txt|README.md) stack_ok=1 ;; esac
  # agent names
  hits="$(grep -nIiE "$AGENT" "$f" | grep -v 'forge-allow' | grep -v 'CLAUDE\.md' | grep -v 'adapters/' | grep -v 'claude-code/' || true)"
  if [ -n "$hits" ]; then fail=1; echo "AGENT NAME in $f:"; printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/   /'; fi
  # stack names
  if [ "$stack_ok" = 0 ]; then
    hits="$(grep -nIiE "$STACK" "$f" | grep -v 'forge-allow' | grep -v 'ios-swift' | grep -v 'probes/swift.sh' || true)"
    if [ -n "$hits" ]; then fail=1; echo "STACK NAME in $f:"; printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/   /'; fi
  fi
done <<EOF_LIST
$list
EOF_LIST
if [ "$fail" = 0 ]; then echo "neutrality check passed: no agent or stack names outside the allowed places."; else echo; echo "Fix the lines above (reword, move to adapters/ or a stack playbook), or mark a deliberate exception with 'forge-allow'."; fi
exit "$fail"
