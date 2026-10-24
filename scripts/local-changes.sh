#!/usr/bin/env bash
# local-changes.sh - the local-work counterpart of pr-range.sh. Shows what exists to review in
# the current checkout (uncommitted edits, unpushed commits) and the exact commands to use.
# Read-only: it never stages, commits, stashes or modifies anything.
#
# Usage: scripts/local-changes.sh
# Bash 3.2 safe.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 1; }
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
up="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
self="$(cd "$(dirname "$0")" && pwd)"

staged="$(git diff --cached --name-only | wc -l | tr -d ' ')"
unstaged="$(git diff --name-only | wc -l | tr -d ' ')"
untracked="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
echo "== local changes on $branch @ $sha =="
echo "uncommitted: $staged staged, $unstaged unstaged, $untracked new (untracked) files"
if [ -n "$up" ]; then
  ahead="$(git rev-list --count "$up..HEAD" 2>/dev/null || echo 0)"
  echo "unpushed commits vs $up: $ahead"
else
  ahead=""; echo "no upstream branch set (compare against a branch explicitly, e.g. origin/main)"
fi
echo
if [ "$((staged + unstaged + untracked))" -gt 0 ]; then
  git status --short | head -40
  echo
  echo "Review the uncommitted work (staged + unstaged + new files, against HEAD):"
  echo "  $self/diff-scope.sh --local"
  echo "  $self/impact.sh HEAD"
  echo "  $self/reuse-scan.sh HEAD"
  echo "  header: Reviewed: local changes on $branch @ $sha (uncommitted)"
fi
if [ -n "$ahead" ] && [ "$ahead" -gt 0 ]; then
  echo
  echo "Review the commits not pushed yet:"
  echo "  $self/diff-scope.sh $up HEAD"
  echo "  header: Reviewed: $up..$sha"
fi
if [ "$((staged + unstaged + untracked))" -eq 0 ] && { [ -z "$ahead" ] || [ "$ahead" -eq 0 ]; }; then
  echo "Nothing to review: no uncommitted changes and no unpushed commits."
fi
echo
echo "Whole branch against its target (committed work only): $self/diff-scope.sh origin/<target> HEAD"
