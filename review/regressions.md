# Review regression set

Real defects the rubric **missed** on first review, kept so a change to the rubric can be
checked against them instead of judged by feel. Source: two real PR reviews (cases A* and B*) and a later
session report (cases dated 15 Oct), where an independent pass and the human reviewers
found what the author's own pass did not.

**Do not load this file in a normal review or generation task.** It is read only when the
rubric itself is being changed (`review/review-prompt.md`, `memory/quality-gate.md`, a
playbook entry), because replaying it costs real tokens.

## Replay procedure

1. For each case whose "Expected to be caught by" item the change touched, run the
   `forge-reviewer` subagent on `<base>..<head_before_fix>` (the diff as it was before the
   reviewer's comment was addressed).
2. Record whether a finding matching "What was missed" appears. Add a row to the log below.
3. A rubric change that makes a previously-caught case stop being caught is rejected or
   reworked. A case still not caught after a change that was meant to catch it means the
   change doesn't work yet.
4. Keep the cost down: replay only the touched cases, in `fast` Mode first; escalate only
   if a case is unclear.

Fill in `base` and `head_before_fix` per case once (git SHAs). Without them a case can't
be replayed.

## Cases

Status: **missed** = not flagged at all; **partial** = a related finding was raised but the
fix or scope was incomplete (inferred from the report's counts: 11 missed outright, 4
partial; B1 and B12 are listed with the missed items in its root-cause table but are the
partial ones - correct this if wrong).

| ID | PR | What was missed | Status | Root cause | Expected to be caught by | base | head_before_fix |
|----|----|-----------------|--------|-----------|---------------------------|------|-----------------|
| R-01 | B10 | Why pass this value through at all | missed | design altitude was ungraded | review-prompt category 20 | | |
| R-02 | B13 | Why a separate file for this | missed | same | category 20 | | |
| R-03 | B6 | Naming of the new type/API | missed | same | category 20 | | |
| R-04 | B7 | Profile router flag has no effect | missed | no "who reads this?" check | "Value has a consumer" | | |
| R-05 | B11 | Same flag, second site | missed | same | "Value has a consumer" + sibling check | | |
| R-06 | B1 | Ownership of the loaded record inferred from `ownerId == nil` | partial | sibling check on one instance | IOS-036, category 20 | | |
| R-07 | B12 | Same inference on the deep-link path | partial | same | IOS-036 | | |
| R-08 | B8 | No test for the "someone else's record" case | missed | IOS-016 existed, not applied to the risky case | IOS-016 + IOS-036 test requirement | | |
| R-09 | B9 | Initializer starts async work before inputs are set | missed | no playbook entry | IOS-037 | | |
| R-10 | B4 | Request id in a log line (hygiene) | missed | no check covers it | **none yet - gap**; decide if it deserves one | | |
| R-11 | A5 | `isNotBlank` convention: `isEmpty` judged "not a violation" | missed | existing rule misapplied | project-convention check in constitution / gate | | |
| R-12 | A1 | Date-format coverage assumed, not checked | missed | verify-before-asserting didn't fire | evidence tags: runtime claim needs `probed`/`ran` | | |
| R-14 | B4 | `debugPrint` is invisible in release; use the project's logging helper (same comment as R-10, second reviewer) | missed | hygiene unchecked | Cleanup notes hygiene bullet | | |
| R-15 | B12 | Deep link dropped `showPrivilegedActions` and the link's status that the legacy screen got: approver case lost | missed | privilege-parity check didn't cover argument parity | IOS-035 (extend to arguments, not just checks) | | |
| R-16 | 15 Oct R1-2 | Test asserted malformed HTML copied from code output | missed | no test-oracle check | IOS-038 | | |
| R-17 | 15 Oct R1-3 | Deep link built a display model without an argument every feed route passes | missed | cross-call-site compared privileges, not arguments | IOS-039 | | |
| R-18 | 15 Oct R1-4 | Input built before its mode was resolved; stale list | missed | no capture-vs-mutation check | IOS-040 | | |
| R-19 | 15 Oct R2-2 | Privilege check computed by the list but missing on the notification route | missed | cross-call-site not run on the value | IOS-039 + cross-call-site | | |
| R-20 | 15 Oct R2-1 | Restore trusted ambiguous diff position; sibling function had the same flaw | missed | sibling-instance | IOS-042 + sibling | | |
| R-21 | 15 Oct R1-5 | Contract change broke an existing converter test (CI) | missed | no test sweep | IOS-041 | | |
| R-22 | 15 Oct R2-3 | CI diff coverage 88% vs 90% | gate | tests not written with the code | IOS-043 + gate "Tests ship with the code" | | |
| R-23 | 15 Oct R1-20 | `isNil`/`isNotNil` helpers not used (second sighting of R-11) | missed | helper family not searched | constitution helper-family rule | | |
| R-24 | 14 Oct dev | Feature gated on `==` of a type whose `==` ignores associated values: worked in one flow only | missed | no check on custom `==` | IOS-046 | | |
| R-25 | 14 Oct dev | Input shown for a closed ticket opened from a deep link; status rule only on the list path | missed | rule not checked per entry point | IOS-047 | | |
| R-26 | 14 Oct QE | No "no results" state and self-tag possible on the sibling screen sharing the component | missed | rule not checked per surface | IOS-047 | | |
| R-27 | 16 Oct QA | One suggestion row per person; role with two people showed twice (web/Android group by role) | missed | no parity check with other platforms | IOS-048 | | |
| R-28 | 16 Oct QA | Label reused from an existing string; casing differs from the design | missed | labels not checked against design | IOS-048 | | |
| R-29 | 16 Oct Android dev | Self-exclusion matched person rows only; signed-in user reachable through a role row | missed | rule not checked per row type | IOS-047 | | |
| R-30 | 21 Oct review | Edit seeded saved hours; changing dates never cleared them, request sent hours outside the range | missed | seeded-state invalidation not checked | IOS-045 | | |
| R-31 | 21 Oct client | `0.5` typed in an hours field saved as `5` (stored 0 rendered empty, `0` and `.` wiped) | missed | no keystroke-sequence test | IOS-044 | | |
| R-13 | A4 | PR text said "open requests"; code also allows approved | missed | nothing compared description to diff | category 15 (description vs diff) | | |

## Replay log

| Date | Rubric change | Cases replayed | Caught before | Caught after | Note |
|------|---------------|----------------|---------------|--------------|------|
