#!/usr/bin/env bash
# xref.sh - local, dependency-free "who else uses this symbol" finder for the cross-call-site
# check. Word-boundary match, grouped as definition / production use / test use, vendored
# code excluded. Paths first, snippets capped, so the output is cheap to read. It is a text
# search: if a language-server or IDE reference tool is available in the session, prefer its
# exact answer and say which method was used in the review's "Checks run" line.
#
# Usage: xref.sh <symbol> [--files] [--max N] [--also <other-spelling>]...
#   --files   paths with counts only (no snippets)
#   --max N   snippet lines per group (default 12)
#   --also S  extra spelling to search too (selector string, notification name, protocol name)
# Bash 3.2 / BSD safe. Read-only.
set -u
[ "$#" -ge 1 ] || { echo "usage: $0 <symbol> [--files] [--max N] [--also S]..." >&2; exit 1; }
SYM="$1"; shift
FILES_ONLY=0; MAX=12; ALSO=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --files) FILES_ONLY=1 ;;
    --max) shift; MAX="${1:-12}" ;;
    --also) shift; ALSO="$ALSO
${1:-}" ;;
  esac
  shift
done
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
VENDOR='(^|/)(Pods|Carthage|node_modules|vendor|\.build|build|dist|DerivedData|\.venv|venv|target|__pycache__|\.next|coverage)/'
TESTP='(^|/)(tests?|__tests__|spec|specs)/|[._-]tests?\.[A-Za-z]+$|[._-]spec\.[A-Za-z]+$|Tests?\.[A-Za-z]+:|(^|/)test_[^/]*\.py:|_test\.go:'
DEFP="(func|class|struct|enum|protocol|extension|typealias|var|let|val|def|function|const|interface|type|fn|trait|object|actor)[[:space:]]+${SYM}([^A-Za-z0-9_]|$)"

search() { # $1 = pattern, $2 = fixed(0/1)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ "$2" = "1" ]; then git grep -nI -F -- "$1" 2>/dev/null; else git grep -nI -w -- "$1" 2>/dev/null; fi
  else
    if [ "$2" = "1" ]; then grep -rnIF -- "$1" . 2>/dev/null; else grep -rnIw -- "$1" . 2>/dev/null; fi
  fi | grep -Ev "$VENDOR"
}

{ search "$SYM" 0
  printf '%s\n' "$ALSO" | sed '/^$/d' | while IFS= read -r extra; do search "$extra" 1; done
} | sort -u > $TD/all 2>/dev/null

total="$(wc -l < $TD/all | tr -d ' ')"
grep -Ei "$TESTP" $TD/all > $TD/t || true
grep -Eiv "$TESTP" $TD/all > $TD/p || true
grep -E "$DEFP" $TD/p > $TD/d || true
grep -vxFf $TD/d $TD/p > $TD/u 2>/dev/null || cp $TD/p $TD/u

echo "== xref: $SYM (text search, word-boundary; $total lines) =="
[ "${#SYM}" -lt 4 ] && echo "  note: short name - expect unrelated matches; add context or use --also"
show() { # $1 title, $2 file
  n="$(wc -l < "$2" | tr -d ' ')"; fcount="$(cut -d: -f1 "$2" | sort -u | wc -l | tr -d ' ')"
  echo "-- $1: $n lines in $fcount files"
  cut -d: -f1 "$2" | sort | uniq -c | sort -rn | head -n 25 | sed -E 's/^ *([0-9]+) (.*)$/   \1  \2/'
  if [ "$FILES_ONLY" -eq 0 ] && [ "$n" -gt 0 ]; then
    echo "   snippets:"; head -n "$MAX" "$2" | cut -c1-150 | sed 's/^/   /'
    [ "$n" -gt "$MAX" ] && echo "   ... $((n-MAX)) more (raise --max or use --files)"
  fi
}
show "definitions" $TD/d
show "production uses" $TD/u
show "test uses" $TD/t
echo "-- reminder: also check other spellings (string/selector/notification names, protocol conformances, reflection, generated code) and say how this was searched in Checks run."

