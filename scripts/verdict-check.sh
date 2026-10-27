#!/usr/bin/env bash
# verdict-check.sh - does a finished review's verdict follow from its own findings?
# The gate is arithmetic (memory/quality-gate.md): any CRITICAL, any HIGH or any un-waived
# MEDIUM means "Request changes"; an author pass never approves. Reviews have come out softer
# than that ("Approve with comments" beside an open HIGH), so this checks the draft mechanically.
#
# Usage: scripts/verdict-check.sh <review.md> [--waived N]
#        cat review.md | scripts/verdict-check.sh - [--waived N]
#   --waived N   number of MEDIUM findings that have an entry in logs/suppressions.md
#                (this script does not read that file; pass the count)
# Counts findings from "### [SEVERITY] ..." headings and one-line "[SEVERITY] file:line ..."
# entries. The stated verdict is the last line that mentions "verdict", else the last line
# that says Request changes / Approve / No findings.
# Exit: 0 consistent, 1 the stated verdict is softer than the findings require,
#       2 no verdict line found (cannot check). Prints the required verdict either way.
# Bash 3.2 / BSD safe. Read-only.
set -u
f="${1:-}"; waived=0
[ -n "$f" ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
shift
while [ $# -gt 0 ]; do case "$1" in --waived) waived="${2:-0}"; shift 2 ;; *) shift ;; esac; done
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if [ "$f" = "-" ]; then cat > "$tmp"; else cat "$f" > "$tmp" 2>/dev/null || { echo "cannot read $f" >&2; exit 2; }; fi

count() { grep -Ec "^(### +)?\[$1\]" "$tmp" || true; }
crit="$(count CRITICAL)"; high="$(count HIGH)"; med="$(count MEDIUM)"; low="$(count LOW)"; nit="$(count NIT)"
med_open=$((med - waived)); [ "$med_open" -ge 0 ] || med_open=0
author=0; grep -Eq '^Reviewed:.*Pass: *author' "$tmp" && author=1

if [ $((crit + high + med_open)) -gt 0 ]; then required="Request changes"; else required="a pass (Approve / Approve with comments / No blocking findings)"; fi
echo "findings: CRITICAL $crit, HIGH $high, MEDIUM $med (waived $waived), LOW $low, NIT $nit"

stated="$(awk '{ L[NR]=$0 } END { for (i=NR; i>=1; i--) if (tolower(L[i]) ~ /verdict/) { print L[i] " " L[i+1] " " L[i+2]; exit } }' "$tmp")"
[ -n "$stated" ] || stated="$(grep -Ei 'request changes|approve|no findings from this author pass' "$tmp" | tail -n 1)"
if [ -z "$stated" ]; then echo "no verdict line found; required: $required"; exit 2; fi
echo "stated:   $stated"
echo "required: $required"

low_stated="$(printf '%s' "$stated" | tr '[:upper:]' '[:lower:]')"
approves=0
case "$low_stated" in *"request changes"*) approves=0 ;; *"no findings from this author pass"*) approves=0 ;; *approv*) approves=1 ;; esac
if [ "$approves" = 1 ] && [ $((crit + high + med_open)) -gt 0 ]; then
  echo "MISMATCH: the verdict approves but $((crit + high + med_open)) blocking finding(s) are open."; exit 1
fi
if [ "$approves" = 1 ] && [ "$author" = 1 ]; then
  echo "MISMATCH: an author pass (not independent) never approves."; exit 1
fi
echo "ok: the verdict is not softer than the findings."
exit 0
