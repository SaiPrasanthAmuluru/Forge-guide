#!/usr/bin/env bash
# drift-check.sh
#
# Lightweight staleness check: greps the current repo for patterns referenced in
# skills/*.md and constitution.md, and flags any rule whose last-verified date is
# older than the threshold below. Does NOT attempt to auto-fix anything — it only
# flags candidates for human/agent review, per the "explicit, versioned, reviewed"
# discipline this repo is built around.
#
# Usage: ./scripts/drift-check.sh [days-threshold]

set -euo pipefail

THRESHOLD_DAYS="${1:-90}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOW_EPOCH=$(date +%s)

echo "== drift-check: rules older than ${THRESHOLD_DAYS} days =="

for file in "$REPO_ROOT"/memory/constitution.md "$REPO_ROOT"/skills/*.md; do
  [ -f "$file" ] || continue
  # Extract lines like: "last-verified: 2026-05-01"
  grep -no 'last-verified: [0-9-]*' "$file" | while IFS=: read -r lineno _ date; do
    date_str=$(echo "$date" | xargs)
    if [ "$date_str" = "<date>" ] || [ -z "$date_str" ]; then
      echo "  [UNSET]  $(basename "$file"):$lineno — no last-verified date set"
      continue
    fi
    # GNU date (Linux) first, BSD date (macOS) as fallback — same pattern as
    # shared/lib.sh's calculate_relative_time.
    if date --version >/dev/null 2>&1; then
      rule_epoch=$(date -d "$date_str" +%s 2>/dev/null || echo 0)
    else
      rule_epoch=$(date -j -f "%Y-%m-%d" "$date_str" +%s 2>/dev/null || echo 0)
    fi
    if [ "$rule_epoch" -eq 0 ]; then
      echo "  [BADFMT] $(basename "$file"):$lineno — unparseable date: $date_str"
      continue
    fi
    age_days=$(( (NOW_EPOCH - rule_epoch) / 86400 ))
    if [ "$age_days" -gt "$THRESHOLD_DAYS" ]; then
      echo "  [STALE]  $(basename "$file"):$lineno — ${age_days} days old"
    fi
  done
done

echo ""
echo "== drift-check: manual step =="
echo "For each STALE/UNSET rule above, confirm the referenced pattern still exists"
echo "in the current codebase (e.g. grep for the named pattern/module) before trusting"
echo "it. Update the last-verified date once confirmed, or update/remove the rule if"
echo "it no longer matches reality."

