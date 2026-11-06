#!/usr/bin/env bash
# lint-repo.sh - the publish gate for this toolkit repo: nothing ships with a typo, a shell
# warning, a broken link, a stray long dash or a core file that has grown past its token budget.
#
# Usage: scripts/lint-repo.sh [--fast]     --fast skips the Markdown style pass
# Checks, in order: shell syntax, shellcheck, codespell, markdownlint, long dashes,
#   relative Markdown links, neutrality, size budget of the always-loaded files, and an optional
#   personal deny list (one regex per line in $FORGE_DENY_FILE, default ~/.forge/deny.txt, kept out of the repo).
# Needs: codespell, shellcheck, markdownlint (npm i -g markdownlint-cli). A missing tool FAILS the
# run (set FORGE_LINT_SKIP_MISSING=1 to downgrade that to a warning on a throwaway machine).
# Exit 0 only when every check passes. Bash 3.2 / BSD safe.
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 2
fast=0; [ "${1:-}" = "--fast" ] && fast=1
bad=0
fail() { echo "FAIL: $1"; bad=1; }
need() { # tool, install hint
  command -v "$1" >/dev/null 2>&1 && return 0
  if [ "${FORGE_LINT_SKIP_MISSING:-0}" = 1 ]; then echo "skip: $1 not installed ($2)"; else fail "$1 is not installed ($2)"; fi
  return 1
}
files="$(git ls-files 2>/dev/null)"; [ -n "$files" ] || files="$(find . -type f -not -path './.git/*' | sed 's#^\./##')"
sh_files="$(printf '%s\n' "$files" | grep -E '\.sh$' || true)"
md_files="$(printf '%s\n' "$files" | grep -E '\.md$' || true)"

echo "-- shell syntax"
for f in $sh_files; do bash -n "$f" || fail "syntax: $f"; done
echo "-- shellcheck"
if need shellcheck "pip install shellcheck-py"; then
  # shellcheck disable=SC2086
  shellcheck -S warning -x $sh_files || fail "shellcheck"
fi
echo "-- spelling"
if need codespell "pip install codespell"; then
  # shellcheck disable=SC2086
  codespell $files || fail "codespell"
fi
if [ "$fast" = 0 ]; then
  echo "-- markdown style"
  if need markdownlint "npm i -g markdownlint-cli"; then
    # shellcheck disable=SC2086
    markdownlint $md_files || fail "markdownlint"
  fi
fi
echo "-- long dashes"
# bytes of U+2013 and U+2014, so it works with BSD grep (no -P) and any locale
dash="$(printf '\342\200[\223\224]')"
# shellcheck disable=SC2086
if LC_ALL=C grep -nE "$dash" $files 2>/dev/null | head -5 | grep .; then fail "long dash (use a hyphen with spaces)"; fi
echo "-- relative links"
for f in $md_files; do
  d="$(dirname "$f")"
  grep -oE '\]\([^)#][^)]*\)' "$f" 2>/dev/null | sed 's/^](//; s/)$//; s/#.*//' | grep -vE '^(https?:|mailto:|<)' | grep . | while IFS= read -r l; do
    [ -e "$d/$l" ] || echo "BROKEN: $f -> $l"
  done
done > /tmp/forge-links.$$ 2>/dev/null
if [ -s /tmp/forge-links.$$ ]; then cat /tmp/forge-links.$$; fail "broken relative link"; fi; rm -f /tmp/forge-links.$$
echo "-- neutrality"
scripts/neutrality-check.sh >/dev/null || { scripts/neutrality-check.sh | tail -5; fail "neutrality"; }
echo "-- size budget (always-loaded files, bytes)"
budget() { # file max
  [ -f "$1" ] || return 0
  sz="$(wc -c < "$1" | tr -d ' ')"
  [ "$sz" -le "$2" ] && printf '  ok   %-30s %6d / %d\n' "$1" "$sz" "$2" || { printf '  OVER %-30s %6d / %d\n' "$1" "$sz" "$2"; fail "$1 grew past its budget; trim before adding"; }
}
budget AGENTS.md 11000
budget memory/constitution.md 4500
budget memory/quality-gate.md 11500
budget review/review-prompt.md 31000
deny="${FORGE_DENY_FILE:-$HOME/.forge/deny.txt}"
if [ -f "$deny" ]; then
  echo "-- personal deny list"
  # shellcheck disable=SC2086
  if grep -niEf "$deny" $files 2>/dev/null | head -5 | grep .; then fail "deny-list match (employer or private names)"; fi
fi
echo
[ "$bad" = 0 ] && echo "lint-repo: all checks passed." || { echo "lint-repo: FAILED."; exit 1; }
