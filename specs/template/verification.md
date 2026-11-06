# Verification: <feature name>

Run after implementation, before marking the spec done. Go through every acceptance
criterion from `spec.md` explicitly - "it compiles" and "it runs" are not verification.

- [ ] Criterion 1 - <how it was checked: test / manual trace / repro> - PASS/FAIL
- [ ] Criterion 2 - <how it was checked> - PASS/FAIL

## Final check and independent pass (required - scripts/verify-spec.sh fails without both)

- [ ] `scripts/final-check.sh --local` (spelling, whitespace, leftover debug code on added lines) -
  final-check: <clean | findings fixed> (not "NOT RUN")
- [ ] Independent pass run by `forge-reviewer` or a human, not the context that wrote the change -
  verdict: <Approve | No blocking findings>, written only after every CRITICAL, HIGH and un-waived
  MEDIUM was fixed and the reviewer run again - or the skip written as shown in AGENTS.md step 4 when Mode is fast

## Tests and CI gates (before pushing)

- [ ] New logic has tests in a compiled target; expected values come from the requirement
- [ ] Tests asserting any field whose source changed were swept
- [ ] CI gates known and checked locally where possible (e.g. diff coverage <threshold>): <result>

## Divergences

<Any place implementation differs from the spec - either the spec was wrong (update it) or
the implementation needs fixing. Never leave a silent divergence unrecorded.>

## Security check (if HARD constitution rules apply)

- [ ] No hardcoded secrets introduced
- [ ] No PII logged
- [ ] No bypass of existing auth/keychain/centralized data pattern
