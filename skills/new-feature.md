
# Skill: new-feature

Use when the task is adding new functionality that doesn't exist yet in the codebase.

## Trigger phrases
"add", "build", "create a new", "implement", "support for"

## Step 0 - Context scan and flow map (before anything else, even clarification)

Read the overall map first (`context/base-snapshot.md`, in full; build it with
`skills/build-context.md` if missing - never generate code without it), record
`Map consulted` in the spec, then understand the area this touches. Follow
`context/flow-brief.md` for the flow map (entry points, the current flow end to end, state
and ownership, boundaries, closest analogue, tests) and for how unknowns become questions.
Alongside it, scan for reuse:
- Search for an existing utility/extension/helper that already does this or something
  close to it - surface any hit as one of the batched question options below ("found
  `X` in `Y` - reuse it?") rather than as a separate step.
- Search for an existing centralized entry point (coordinator/adapter/manager) for this
  feature area - new code should go through it, not duplicate it inline.
- Check whether this is already solved: recent commits, an open/linked PR, an existing
  ticket resolution. If solid evidence says it's already done, say so and stop rather than
  generating a redundant fix.

Populate the spec's **Existing-code context** and **Flow & understanding** sections from
this before moving on.

## Impact and reuse (scripts)

`scripts/impact.sh --symbols <declarations you will change or remove>` before coding and
`scripts/impact.sh <base>` on the diff after; `scripts/reuse-scan.sh --need "<words>"` before
writing any helper and `scripts/reuse-scan.sh <base>` after. Record both in the spec
(Impact scan, Reuse scan).

## Before generating any code

Run the clarification round exactly as `context/flow-brief.md` section 3 describes: lead
with "my understanding" for the person to confirm, ask only the relevant unanswered
flow questions, list the assumptions. The defaults below are asked **only if the scan and
the spec don't already answer them** (skip any answered in the original request), folded
into the same single round:

1. **Consumer** - who/what calls this? (UI only / internal service / public API / multiple)
2. **Data shape** - does this need a new model, or extend an existing one? (new / extend
   existing: <name> / unsure - investigate first)
3. **Concurrency** - does this run on the main thread, background, or does it not matter
   yet? (main-thread UI work / background/async / not sure yet)
4. **Existing pattern** - is there a similar feature already in the repo to follow the
   pattern of, or is this the first of its kind? (follow: <name> / no precedent, propose
   one)
5. **Test expectations** - does this need unit tests, or just the implementation for now?
   (yes, tests too / just implementation / repo doesn't have a test setup yet)

Leave the last option on each open-ended, but default to the checklist - don't ask these
as separate freeform turns.

## Stop and ask while building

Follow `context/flow-brief.md` section 4: pause with one focused question when the code
contradicts the flow map, a step has two readings, the scope widens, an assumption fails,
or a new parameter would have no reader. Don't guess through it.

## Drift check before trusting this skill

Before applying "Existing pattern" answers above, confirm the referenced pattern still
exists as described - a quick grep, not a full read. If it's been refactored since this
skill file was last verified, flag it and ask which pattern to follow instead of guessing.

## Writing the spec

Fill `specs/00X-feature-name/spec.md` using the answers above, sized to the change (the
short form at the top of the template for a small change). Every acceptance criterion
should be checkable - "returns X for input Y", not "works correctly."

## Impact analysis (before task breakdown)

If this feature touches a shared contract - a delegate callback, an integration hook, a
notification name, a protocol method, a singleton entry point - search the whole codebase
for every other place that contract is used, not just the code being added. Populate the
spec's **Impact / blast radius** section from this search. This is not optional for shared
contracts; see `memory/quality-gate.md`'s mandatory checks.

## Writing tasks

Break `tasks.md` into the smallest units that can each be verified independently. Note an
estimated relative size (S/M/L) per task - this feeds the token ledger and helps catch
tasks that are secretly too large and should be split further.

## While implementing

Pull the relevant playbook entries (`scripts/playbook.sh index`, then `show <ID>` - never
the whole file) for known-better-patterns before writing code in
a domain it covers (persistence, concurrency, platform APIs) - don't reintroduce a pattern
that's already a documented incident. After fixing any bug-shaped issue mid-implementation,
grep the rest of the diff and file for the same shape before moving on - a fix applied to
one instance while an identical one sits untouched nearby is a recurring, avoidable failure.

## After implementation

Run through `spec.md`'s acceptance criteria one by one against the actual diff before
calling the feature done. Note any criterion that wasn't met or was interpreted differently
than written - update the spec if the interpretation was actually correct, don't just
silently diverge. Then run the applicable checks from `memory/quality-gate.md` against the
diff before marking the task done - the gate applies at generation time, not only at
review time.
