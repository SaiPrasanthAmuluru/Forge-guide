#!/usr/bin/env bash
# final-check.sh - mechanical checks on the lines a change ADDS, before handoff or a PR.
# It catches the small things a reviewer should never have to write: misspelt words in names,
# comments and strings, whitespace errors, conflict markers, and leftover debug code or
# unreferenced TODOs. Only added lines are checked, so old problems never block new work.
#
# Usage: scripts/final-check.sh <base> [head]     a range (head defaults to HEAD)
#        scripts/final-check.sh --local           uncommitted work (staged, unstaged, new files)
# Leftover patterns come from context/final-check-patterns.txt ("label<TAB>regex" per line);
# edit it for the project. A line that carries the word "forge-allow" is skipped.
# Read-only. Exit: 0 clean, 1 findings, 3 clean but the spell check could not run
# (install codespell: pip install codespell) - report that as "spell check not run", never as a pass.
# Bash 3.2 / BSD safe.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
PATTERNS="${FORGE_FINAL_PATTERNS:-$here/context/final-check-patterns.txt}"
base=""; head="HEAD"; local_mode=0
while [ $# -gt 0 ]; do
  case "$1" in
    --local) local_mode=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [ -z "$base" ]; then base="$1"; else head="$1"; fi; shift ;;
  esac
done
[ "$local_mode" = 1 ] || [ -n "$base" ] || { echo "usage: final-check.sh <base> [head] | --local" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 2; }
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
# Files that are data, not prose or code: skipped for spelling and leftovers.
SKIP='(\.lock|\.resolved|\.pbxproj|\.xcstrings|\.strings|\.xliff|\.svg|\.min\.[a-z]+|\.xcscheme|\.plist|\.json|\.csv|package-lock\.json)$|(^|/)(Pods|Carthage|vendor|node_modules|\.build|DerivedData)/|\.xcassets/' # forge-allow

if [ "$local_mode" = 1 ]; then
  git diff -U0 --no-color HEAD > "$TD/diff.txt" 2>/dev/null
  git ls-files --others --exclude-standard | while IFS= read -r f; do
    grep -Iq . "$f" 2>/dev/null || continue
    n="$(wc -l < "$f" | tr -d ' ')"
    printf 'diff --git a/%s b/%s\n+++ b/%s\n@@ -0,0 +1,%s @@\n' "$f" "$f" "$f" "$n"
    sed 's/^/+/' "$f"
  done >> "$TD/diff.txt"
  label="uncommitted changes"
else
  git diff -U0 --no-color "$base...$head" > "$TD/diff.txt" 2>/dev/null || { echo "cannot diff $base...$head" >&2; exit 2; }
  label="$base...$head"
fi

# added.txt: one line per added line, "path:line:content" (skipped files left out).
awk -v skip="$SKIP" '
  /^\+\+\+ b\// { path = substr($0, 7); keep = (path !~ skip); next }
  /^\+\+\+ / { keep = 0; next }
  /^@@ / { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
  /^\+/ { if (keep) print path ":" ln ":" substr($0, 2); ln++ }
' "$TD/diff.txt" > "$TD/added.txt"

echo "== final-check: $label =="
fail=0; notrun=0
echo "added lines checked: $(wc -l < "$TD/added.txt" | tr -d ' ')"

# 1. whitespace errors and conflict markers (git knows them; limited to this diff)
if [ "$local_mode" = 1 ]; then ws="$(git diff --check HEAD 2>&1 || true)"; else ws="$(git diff --check "$base...$head" 2>&1 || true)"; fi
if [ -n "$ws" ]; then echo "-- whitespace / conflict markers --"; printf '%s\n' "$ws" | head -30; fail=1; fi

# 2. spelling, on added lines only
if command -v codespell >/dev/null 2>&1; then
  # codespell reads one file; prefix-free text keeps line numbers aligned with added.txt.
  sed 's/^[^:]*:[0-9]*://' "$TD/added.txt" > "$TD/text.txt"
  cfg=""; [ -f "$here/.codespellrc" ] && cfg="--config $here/.codespellrc"
  # shellcheck disable=SC2086
  sp="$(codespell $cfg "$TD/text.txt" 2>/dev/null || true)"
  if [ -n "$sp" ]; then
    echo "-- spelling --"
    printf '%s\n' "$sp" | while IFS= read -r l; do
      n="$(printf '%s' "$l" | sed -n 's/^[^:]*:\([0-9][0-9]*\):.*/\1/p')"
      rest="$(printf '%s' "$l" | sed 's/^[^:]*:[0-9]*: *//')"
      where="$(sed -n "${n}p" "$TD/added.txt" | cut -d: -f1,2)"
      echo "  $where  $rest"
    done
    fail=1
  fi
else
  echo "-- spelling: NOT RUN (codespell not installed; pip install codespell) --"; notrun=1
fi

# 3. leftovers (debug code, unreferenced TODOs), from the pattern file
if [ -f "$PATTERNS" ]; then
  : > "$TD/left.txt"
  grep -v 'forge-allow' "$TD/added.txt" > "$TD/scan.txt" || true
  while IFS="$(printf '\t')" read -r label_p rx unless; do
    case "$label_p" in ''|\#*) continue ;; esac
    [ -n "$rx" ] || continue
    if [ -n "$unless" ]; then
      grep -E "$rx" "$TD/scan.txt" 2>/dev/null | grep -vE "$unless" | cut -c1-160 | sed "s/^/  [$label_p] /" >> "$TD/left.txt" || true
    else
      grep -E "$rx" "$TD/scan.txt" 2>/dev/null | cut -c1-160 | sed "s/^/  [$label_p] /" >> "$TD/left.txt" || true
    fi
  done < "$PATTERNS"
  if [ -s "$TD/left.txt" ]; then echo "-- leftovers (remove, or add forge-allow on the line with a reason) --"; head -40 "$TD/left.txt"; fail=1; fi
fi

echo
if [ "$fail" = 1 ]; then echo "FINAL CHECK FAILED - fix the lines above, then run it again."; exit 1; fi
if [ "$notrun" = 1 ]; then echo "final check: clean, but the spell check did not run. Say so in the handoff."; exit 3; fi
echo "final check: clean."
