#!/usr/bin/env bash
# finding-log.sh - one row per finding, with WHO/WHAT found it, so misses become visible.
# Usage: finding-log.sh "<task or PR>" <severity> <found-by> <status> "<check that should have caught it or ->" "<playbook id or ->" "<note>"
# severity: CRITICAL|HIGH|MEDIUM|LOW|NIT
# found-by: self-check | scan | own-review | independent-pass | human-reviewer | other-agent | ci | production
#   (the last four are "escapes": they found it after our own passes did not)
# status:   true | false-positive | waived
# "check that should have caught it": the earlier stage or script that missed it, e.g.
#   impact.sh, reuse-scan.sh, flow-brief, self-check, constitution rule X, none-existed
set -eu
[ "$#" -eq 7 ] || { sed -n 2,11p "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
case "$2" in CRITICAL|HIGH|MEDIUM|LOW|NIT) ;; *) echo "bad severity" >&2; exit 1;; esac
case "$3" in self-check|scan|own-review|independent-pass|human-reviewer|other-agent|ci|production) ;; *) echo "bad found-by" >&2; exit 1;; esac
case "$4" in true|false-positive|waived) ;; *) echo "bad status" >&2; exit 1;; esac
. "$(dirname "$0")/_state.sh"
f="$state/logs/findings-ledger.md"; mkdir -p "$state/logs"
[ -f "$f" ] || printf '# Findings ledger\n\nAppend-only. One row per finding. Read by scripts/report-metrics.sh.\n\n| Date | Task | Severity | Found by | Status | Should have been caught by | Playbook ID | Note |\n|------|------|----------|----------|--------|----------------------------|-------------|------|\n' > "$f"
printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$(date +%F)" "$(clean "$1")" "$2" "$3" "$4" "$(clean "$5")" "$(clean "$6")" "$(clean "$7")" >> "$f"
echo "finding row added: $f"
