#!/usr/bin/env bash
# ledger-append.sh - add one row to logs/token-ledger.md in a single command.
# Usage: ledger-append.sh "<task>" <gen|fix|review|merge|report> <strict|standard|fast> "<~tokens>" <clarif> <regens> "<playbook ids>" "<notes>"
set -eu
[ "$#" -eq 8 ] || { echo "usage: $0 task type mode tokens clarif regens ids notes" >&2; exit 1; }
# Where the ledger lives: $FORGE_STATE if set; the toolkit's own logs/ when the toolkit IS the
# project; otherwise <project>/.forge/ so a toolkit kept outside the project stays read-only.
here="$(cd "$(dirname "$0")/.." && pwd)"
proj="${FORGE_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if [ -n "${FORGE_STATE:-}" ]; then state="$FORGE_STATE"
elif [ "$proj" = "$here" ]; then state="$here"
else state="$proj/.forge"; fi
f="$state/logs/token-ledger.md"
mkdir -p "$state/logs"
if [ ! -f "$f" ]; then
  printf '# Token ledger\n\nAppend-only. See the toolkit README for how to fill it.\n\n| Date | Task | Type | Mode | Tokens (Δ) | Clarif. rounds | Full-file regens | Playbook IDs loaded | Notes |\n|------|------|------|------|-----------|----------------|------------------|---------------------|-------|\n' > "$f"
fi
c() { printf '%s' "$1" | tr '|\n' '/ '; }
printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' "$(date +%F)" "$(c "$1")" "$2" "$3" "$(c "$4")" "$5" "$6" "$(c "$7")" "$(c "$8")" >> "$f"
echo "ledger row added: $f"
