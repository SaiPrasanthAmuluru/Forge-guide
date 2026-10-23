#!/usr/bin/env bash
# check-context-freshness.sh
#
# Cheap staleness check for cached context (context/base-snapshot.md, or any area note under
# context/areas/ with the same frontmatter) — one git rev-parse and one
# comparison, not a repo-wide scan. Tells the caller whether the cached snapshot is
# still trustworthy or needs a refresh, and how far behind it is if not.
#
# Usage: ./scripts/check-context-freshness.sh [path-to-snapshot]
#   (defaults to context/base-snapshot.md relative to repo root)
#
# Exit codes:
#   0 - current, or behind but untouched in the paths it cites: safe to reuse
#   1 - stale: a cited path changed, or the base is far ahead
#   2 - no snapshot exists yet, or it has no recorded commit (first build needed)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT="${1:-$REPO_ROOT/context/base-snapshot.md}"
# git operations run against the PROJECT being worked on, which is not necessarily the folder
# holding this toolkit: FORGE_PROJECT, else the git toplevel of the current directory.
PROJECT_ROOT="${FORGE_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")}"

if [ ! -f "$SNAPSHOT" ]; then
  echo "[NO SNAPSHOT] $SNAPSHOT does not exist — build one before relying on cached context."
  exit 2
fi

BASE_REF=$(grep -m1 '^base_ref:' "$SNAPSHOT" | sed 's/^base_ref: *//' | xargs)
SNAPSHOT_COMMIT=$(grep -m1 '^snapshot_commit:' "$SNAPSHOT" | sed 's/^snapshot_commit: *//' | xargs)

if [ -z "$BASE_REF" ] || [ -z "$SNAPSHOT_COMMIT" ] || [[ "$SNAPSHOT_COMMIT" == "<"* ]]; then
  echo "[NO SNAPSHOT] $SNAPSHOT exists but has no recorded commit yet — build it before use."
  exit 2
fi

# Cheap: resolve the current commit of base_ref, no scanning.
CURRENT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse "$BASE_REF" 2>/dev/null || echo "")
if [ -z "$CURRENT_COMMIT" ]; then
  echo "[ERROR] Could not resolve $BASE_REF - is it fetched locally?"
  exit 1
fi

if [ "$CURRENT_COMMIT" = "$SNAPSHOT_COMMIT" ]; then
  echo "[CURRENT] Matches $BASE_REF at $(git -C "$PROJECT_ROOT" rev-parse --short "$CURRENT_COMMIT") - safe to reuse."
  exit 0
fi

# Relevance-based staleness: the base moving is normal on an active repo. The file is stale
# only if a path it cites changed, or the base is far ahead (FORGE_MAX_BEHIND, default 60).
MAX_BEHIND="${FORGE_MAX_BEHIND:-60}"
BEHIND=$(git -C "$PROJECT_ROOT" rev-list --count "${SNAPSHOT_COMMIT}..${CURRENT_COMMIT}" 2>/dev/null || echo "?")
SHORT_OLD=$(git -C "$PROJECT_ROOT" rev-parse --short "$SNAPSHOT_COMMIT" 2>/dev/null || echo "$SNAPSHOT_COMMIT")
SHORT_NEW=$(git -C "$PROJECT_ROOT" rev-parse --short "$CURRENT_COMMIT")

CITED=$(grep -v '^snapshot_commit:' "$SNAPSHOT" | sed -E 's#https?://[^ )]*##g; s#<[^>]*>##g' | grep -oE '[A-Za-z0-9_@.+-]+(/[A-Za-z0-9_@.+-]+)+' | sed -E 's/\*.*$//; s/[.:,;)]+$//' | grep -E '/' | sort -u)
CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only "${SNAPSHOT_COMMIT}..${CURRENT_COMMIT}" 2>/dev/null)

HITS=""
if [ -n "$CITED" ] && [ -n "$CHANGED" ]; then
  HITS=$(printf '%s\n' "$CHANGED" | awk 'NR==FNR{c[$0]=1;next} {for (p in c) if (index($0,p)>0) {print p; break}}' <(printf '%s\n' "$CITED") - | sort -u)
fi

if [ -n "$HITS" ]; then
  echo "[STALE] $SHORT_OLD -> $SHORT_NEW ($BEHIND commit(s)); changed paths this file cites:"
  printf '%s\n' "$HITS" | head -n 8 | sed 's/^/  /'
  echo "Next: ./scripts/refresh-context.sh, then re-check only the rows citing those paths."
  exit 1
fi

if [ "$BEHIND" != "?" ] && [ "$BEHIND" -gt "$MAX_BEHIND" ]; then
  echo "[STALE] $BEHIND commits behind (limit $MAX_BEHIND) though no cited path changed - refresh on a schedule: ./scripts/refresh-context.sh"
  exit 1
fi

NC=0; [ -n "$CITED" ] && NC=$(printf '%s\n' "$CITED" | wc -l | tr -d ' ')
echo "[CURRENT-ENOUGH] $BEHIND commit(s) behind ($SHORT_OLD -> $SHORT_NEW); none touch the $NC path(s) this file cites. Reuse; no refresh needed."
exit 0
