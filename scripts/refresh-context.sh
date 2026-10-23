#!/usr/bin/env bash
# refresh-context.sh
#
# Does NOT rewrite context/base-snapshot.md itself — that's the agent's job, since it
# requires actually reading/reasoning about what changed, not a mechanical operation.
# This script's only job is the cheap part: show exactly what changed between the
# snapshot's recorded commit and base_ref's current HEAD, so the refresh can be scoped
# to that diff instead of re-scanning the whole codebase from zero.
#
# Usage: ./scripts/refresh-context.sh [path-to-snapshot]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT="${1:-$REPO_ROOT/context/base-snapshot.md}"
# git operations run against the PROJECT being worked on, which is not necessarily the folder
# holding this toolkit: FORGE_PROJECT, else the git toplevel of the current directory.
PROJECT_ROOT="${FORGE_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")}"

BASE_REF=$(grep -m1 '^base_ref:' "$SNAPSHOT" | sed 's/^base_ref: *//' | xargs)
SNAPSHOT_COMMIT=$(grep -m1 '^snapshot_commit:' "$SNAPSHOT" | sed 's/^snapshot_commit: *//' | xargs)
CURRENT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse "$BASE_REF")

if [ -z "$SNAPSHOT_COMMIT" ] || [[ "$SNAPSHOT_COMMIT" == "<"* ]]; then
  echo "No prior snapshot commit recorded — this is a first build, not an incremental"
  echo "refresh. Scan the codebase fresh and fill in context/base-snapshot.md directly."
  exit 0
fi

echo "== Changed since snapshot ($(git -C "$PROJECT_ROOT" rev-parse --short "$SNAPSHOT_COMMIT") -> $(git -C "$PROJECT_ROOT" rev-parse --short "$CURRENT_COMMIT")) =="
echo ""
git -C "$PROJECT_ROOT" diff --stat "${SNAPSHOT_COMMIT}..${CURRENT_COMMIT}"
echo ""
echo "== Next step (agent, not this script) =="
echo "Only re-check the snapshot sections whose area appears above — existing-extensions"
echo "inventory, architectural patterns, naming conventions, hotspots — not the whole"
echo "file. Update context/base-snapshot.md's snapshot_commit to $CURRENT_COMMIT and"
echo "captured_at to today once done, and add one line to its Build log noting this was"
echo "an incremental refresh and what changed."

