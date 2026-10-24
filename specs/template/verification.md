# Verification: <feature name>

Run after implementation, before marking the spec done. Go through every acceptance
criterion from `spec.md` explicitly - "it compiles" and "it runs" are not verification.

- [ ] Criterion 1 - <how it was checked: test / manual trace / repro> - PASS/FAIL
- [ ] Criterion 2 - <how it was checked> - PASS/FAIL

## Independent pass (recommended before the developer raises a PR - see memory/quality-gate.md)

- [ ] Run by `forge-reviewer` or a human, not the context that wrote the change - verdict:
  <...> - or reason it was not run (e.g. `fast` Mode, low-risk): <...>

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
