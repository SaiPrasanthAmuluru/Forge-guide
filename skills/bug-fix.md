# Skill: bug-fix

Use when the task is fixing broken/incorrect existing behavior.

## Trigger phrases
"fix", "broken", "not working", "bug", "crash", "regression"

## Step 0 - Already-fixed check (before investigating)

Before planning any fix, check whether this is already solved: recent commit history and
linked/merged PRs referencing the same issue. See `context/context-scan.md` for the exact
mechanics. On high confidence the defect is already gone, confirm against the actual
current code (not just the commit/PR evidence) and stop - don't generate a redundant fix.
On low confidence, proceed, but note what was found.

## Understand the failing flow (before the batched round)

Read the overall map first (`context/base-snapshot.md`; build it with
`skills/build-context.md` if missing) and record `Map consulted` in the spec - the
failing area's helpers, ownership checks and shared processes are in it.

Follow `context/flow-brief.md` section 1, narrowed to the path from the trigger to the
failing point: entry points that can reach it, the hops with `file:line`, the state
involved and who owns it. Write down what *should* happen at the failing point; if the
spec or ticket doesn't say, that is the first question - fixing toward a guessed
"correct" behavior is how a fix lands on the wrong thing.

Evidence before cause: for async, notification or rendering behavior, ask for the log or
HTML/state dump before proposing a fix; a traced call path is a hypothesis.
When applying a reviewer's suggested fix, validate it against how the data is actually used
first (a suggestion that cleared one of two lists would have brought the old data back).

## Impact and reuse (scripts)

`scripts/impact.sh --symbols <declarations you will change or remove>` before coding and
`scripts/impact.sh <base>` on the diff after; `scripts/reuse-scan.sh --need "<words>"` before
writing any helper and `scripts/reuse-scan.sh <base>` after. Record both in the spec
(Impact scan, Reuse scan).

## Before generating any code (batched round)

Lead with "my understanding" (the flow, where it breaks, the intended fix) for the person
to confirm, per `context/flow-brief.md` section 3. Then ask only what the scan and the
ticket don't answer:

0. **Expected behavior** - what should happen instead? (as in the ticket / different:
   <describe> / not sure - propose from the flow)
1. **Repro** - do you have exact repro steps, or should the agent investigate first?
   (have steps / investigate from a stack trace or description / flaky, hard to repro)
2. **Scope** - is the fix expected to touch one function, or could it be architectural?
   (isolated / possibly wider - investigate blast radius first)
3. **Regression risk** - is this area covered by tests already? (yes / no / unsure -
   check first)
4. **Root cause vs. symptom** - patch the symptom now and file root-cause separately, or
   only fix if root cause is found? (patch now / root cause required)

## Investigation before fix

For anything beyond a one-line fix: search for the actual failing code path first
(file:line), don't guess from the bug description alone. State the root cause in one
sentence before writing the fix - this is cheap and prevents fixing the wrong thing. Check
the matching playbook entry (`scripts/playbook.sh find <keyword>`, then `show <ID>`) for a known-better-pattern matching this bug's shape -
a fix that reintroduces a documented incident is worse than a slow one.

If the fix touches a shared contract (a delegate, hook, notification, protocol method,
singleton entry point), run the cross-call-site check before writing the fix - see
`memory/quality-gate.md`'s mandatory checks. Populate the spec's Impact / blast radius
section if one exists for this fix.

## Stop and ask while fixing

Follow `context/flow-brief.md` section 4, in addition to the scope re-check below: stop and
ask when the code contradicts the flow map, the expected behavior has two readings, or an
assumption you recorded turns out false.

## Mid-implementation scope re-check

If the fix, once you're actually in it, turns out to need touching a different layer or
subsystem than the initial scope answer above assumed - real usage has hit this twice,
each time discovered only after implementing and needing a full revert once it had "gone
too deep" - stop and confirm the wider scope with the person before continuing, rather
than pushing through and finding out at the end. Catching a scope mismatch mid-fix is
cheap; discovering it only after a completed, reverted attempt is not.

## While fixing

- **Sibling-instance check.** After fixing the reported instance, grep the rest of the diff
  and the surrounding file for the same bug shape - fixing one of two identical bugs and
  missing the other is a recurring, avoidable failure.
- **Downstream-assumption check.** If the fix changes what a failure path does (a call that
  used to be fatal now logs and continues, or vice versa), re-read every subsequent line in
  that function and its siblings for logic that implicitly assumed the old behavior.

## After the fix

- Confirm against spec/acceptance criteria if one exists for the affected feature.
- Run the applicable checks from `memory/quality-gate.md` against the diff before calling
  the fix done - scoped to the new/changed code, per the ratchet.
- For a fix touching concurrency, ordering, or multi-store state cleanup: re-run the
  adversarial pattern search (not just build+test) after every round of edits in a
  multi-round fix, not only the first commit - existing tests prove no regression, not
  that new logic is correct.
- Note in `logs/token-ledger.md` if investigation required re-reading large files more
  than once - that's a sign the codebase needs a better index/comment, flag it.
