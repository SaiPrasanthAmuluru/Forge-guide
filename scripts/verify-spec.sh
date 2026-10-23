#!/usr/bin/env bash
# verify-spec.sh
#
# Basic verification-loop gate: confirms every acceptance criterion in a spec's
# verification.md has been explicitly marked PASS before the spec can be considered
# done. This is intentionally dumb (checkbox/PASS-FAIL parsing, not test execution) -
# it's a guardrail against "it compiles" being mistaken for "it's verified", not a
# replacement for actually running tests.
#
# Usage: ./scripts/verify-spec.sh specs/00X-feature-name/

set -euo pipefail

SPEC_DIR="${1:?Usage: verify-spec.sh specs/00X-feature-name/}"
VERIFICATION_FILE="${SPEC_DIR%/}/verification.md"

if [ ! -f "$VERIFICATION_FILE" ]; then
  echo "No verification.md found at $VERIFICATION_FILE"
  echo "Copy specs/template/verification.md into $SPEC_DIR first."
  exit 1
fi

TOTAL=$(grep -c '^\s*- \[' "$VERIFICATION_FILE" || true)
UNCHECKED=$(grep -c '^\s*- \[ \]' "$VERIFICATION_FILE" || true)
FAILS=$(grep -ci 'FAIL' "$VERIFICATION_FILE" || true)

SPEC_FILE="${SPEC_DIR%/}/spec.md"
MAP_MISSING=0
if [ -f "$SPEC_FILE" ] && grep -q 'Map consulted:\*\* <' "$SPEC_FILE"; then MAP_MISSING=1; fi
SCANS_MISSING=0
CONF_MISSING=0
if [ -f "$SPEC_FILE" ] && grep -q '^<high | medium | low' "$SPEC_FILE"; then CONF_MISSING=1; fi
if [ -f "$SPEC_FILE" ] && grep -Eq '(Impact|Reuse) scan:\*\* <' "$SPEC_FILE"; then SCANS_MISSING=1; fi

echo "== verify-spec: $SPEC_DIR =="
echo "  Total criteria/items: $TOTAL"
echo "  Unchecked:            $UNCHECKED"
echo "  Marked FAIL:          $FAILS"

if [ "$MAP_MISSING" -eq 1 ]; then
  echo "  spec.md: 'Map consulted' is still the template placeholder - read context/base-snapshot.md"
  echo "  (build it with skills/build-context.md if missing) and record which rows were used."
fi

if [ "$SCANS_MISSING" -eq 1 ]; then
  echo "  spec.md: 'Impact scan' and/or 'Reuse scan' is still the template placeholder - run"
  echo "  scripts/impact.sh and scripts/reuse-scan.sh and record what they showed (or write"
  echo "  'n/a - <reason>' for a change with no declarations, e.g. a comment or string fix)."
fi

if [ "$CONF_MISSING" -eq 1 ]; then
  echo "  spec.md: 'Context confidence' is still the template placeholder - state high/medium/low,"
  echo "  what was read, and what was not verified (the developer sees this at handoff)."
fi

if [ "$UNCHECKED" -gt 0 ] || [ "$CONF_MISSING" -eq 1 ] || [ "$FAILS" -gt 0 ] || [ "$MAP_MISSING" -eq 1 ] || [ "$SCANS_MISSING" -eq 1 ]; then
  echo ""
  echo "NOT VERIFIED - resolve unchecked items and FAILs before marking spec.md done."
  exit 1
else
  echo ""
  echo "All criteria checked, no FAILs found. Spec can be marked done."
fi
