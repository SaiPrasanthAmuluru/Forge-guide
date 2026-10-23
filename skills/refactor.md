# Skill: refactor

Use when behavior should stay identical but structure/quality should improve.

## Trigger phrases
"refactor", "clean up", "restructure", "simplify", "extract"

**Only on request.** Refactor when the developer asked for it. In any other skill, a better
structure you notice becomes a "Beyond this change" note in the spec, never an edit.

## Step 0 - Context scan (before anything else)

Read the overall map first (`context/base-snapshot.md`; `skills/build-context.md` if
missing) and record `Map consulted`. For a refactor, the context scan IS the impact analysis, not a separate later step: search
for every call site of what's being refactored before proposing a boundary. Refactors are
the highest-risk skill for staleness - the "existing pattern" being refactored FROM may
already be half-migrated elsewhere in the repo. Grep for other call sites before assuming
the current state is uniform, and populate the spec's Impact / blast radius section from
this search, not from assumption.

The flow map (`context/flow-brief.md` section 1) for a refactor is the dependency picture:
who calls what is being moved, what state it owns, and which entry points reach it. Fill
the spec's **Flow & understanding** from it.

## Impact and reuse come first (scripts, not judgement)

A refactor is mostly its blast radius. Before anything else run
`scripts/impact.sh --symbols <every declaration you will move, rename, split or delete>`
and fill the spec's Impact table from it; use `scripts/reuse-scan.sh --need "<words>"` before
creating any new helper or type. After the change run `scripts/impact.sh <base>` on the diff.

## Before generating any code (batched round)

Lead with "my understanding" (what moves where, what must stay identical) for the person
to confirm, per `context/flow-brief.md` section 3, and apply its stop-and-ask rules
(section 4) while working. Then ask only what is still open:

1. **Behavior contract** - must output be byte-identical, or is minor behavior drift
   acceptable if it's arguably more correct? (must be identical / minor drift OK if noted)
2. **Test safety net** - are there existing tests to confirm no regression? (yes / no -
   write characterization tests first / no tests, proceed carefully)
3. **Scope boundary** - single file, module, or does this cascade? (single file / module /
   unsure - map dependents first, using the Step 0 scan above)

## While refactoring

Pull the playbook entries for the domain being touched (`scripts/playbook.sh index`, then
`show <ID>`) - a refactor is exactly the
moment a known-better-pattern either gets adopted or gets reintroduced as a regression.
If the refactor's own fix duplicates a helper across two methods or files it touches,
extract a shared one before calling it done - new duplication introduced by the refactor
itself is not exempt just because it's "cleanup."

## After the refactor

- Confirm no behavior change via existing tests, or manually trace the affected paths if
  no tests exist.
- If any minor behavior drift happened, document it explicitly - don't let it pass silently
  as "just a refactor."
- Run the applicable checks from `memory/quality-gate.md` against the diff - scoped to
  what actually changed, per the ratchet, not the whole file being refactored.
