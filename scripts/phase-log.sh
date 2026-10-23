#!/usr/bin/env bash
# phase-log.sh - one row per internal phase of a task, so you can see WHERE tokens went.
# Usage: phase-log.sh "<task>" <phase> "<~tokens>" <files-read> "<why more context was needed or ->" "<notes>"
# phase: map | flow | questions | scans | generate | self-check | review | rework | report | other
# Tokens = the usage-readout delta across that phase (a guess marked ~ beats a blank).
set -eu
[ "$#" -eq 6 ] || { sed -n 2,6p "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
case "$2" in map|flow|questions|scans|generate|self-check|review|rework|report|other) ;;
  *) echo "phase must be: map flow questions scans generate self-check review rework report other" >&2; exit 1;; esac
. "$(dirname "$0")/_state.sh"
f="$state/logs/phase-ledger.md"; mkdir -p "$state/logs"
[ -f "$f" ] || printf '# Phase ledger\n\nAppend-only. One row per phase of a task. Read by scripts/report-metrics.sh.\n\n| Date | Task | Phase | Tokens (Δ) | Files read | Why more context was needed | Notes |\n|------|------|-------|-----------|-----------|-----------------------------|-------|\n' > "$f"
printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$(date +%F)" "$(clean "$1")" "$2" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" "$(clean "$6")" >> "$f"
echo "phase row added: $f"
