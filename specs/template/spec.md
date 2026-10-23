# Spec: <feature name>

**Status:** draft | clarifying | ready | in-progress | done
**Skill:** new-feature | bug-fix | refactor | api-integration | spec-builder

> **Size the spec to the change.** Small or `fast`-Mode change: fill only Problem statement,
> Map consulted, Flow & understanding (a few lines), Decisions & why, Acceptance criteria.
> Fill Impact / blast radius, Interface mapping, Gaps and the inventories only when the
> change touches a shared contract or comes from an external source. An empty section is
> deleted, not left as a template.

## Problem statement

<One or two sentences - what and why, no implementation detail yet.>

## Existing-code context

**Map consulted:** <snapshot @ short SHA; rows used, e.g. "3 shared helpers, 4 ownership
check, 6 coverage gate"; `?` rows confirmed with: ...>

**Reuse scan:** <ran `scripts/reuse-scan.sh --need "<words>"`; helpers I will use (Type.member, used Nx), or "none fit because ...". After coding, re-run on the diff and list each candidate: switched to the helper / kept because ...>

<Populated before clarification, from the context-scan step - what already exists in this
area: relevant utilities/extensions, the established pattern for similar features, any
centralized entry point (coordinator/adapter/manager) this should go through instead of a
new inline path. Empty only if this is genuinely greenfield in this area.>

## Flow & understanding

<From `context/flow-brief.md`, ~25 lines: entry points; the current flow end to end with
file:line per hop (for a bug, the failing path and what *should* happen); state and
ownership; boundaries crossed (permission, record ownership, tenant/session); the closest
existing analogue; tests that cover it. Anything not traced is listed as "not traced".>

**My understanding** (confirmed by: <person / not yet>):
<<= 8 lines: current flow, intended change, what will not be touched.>

## Decisions & why

<Every new type, file, parameter, flag or rule (see `context/flow-brief.md` 2b). Copy into
the PR description.>

| Added | Reader (what changes because of it) | Existing mechanism checked | Why not derive it from loaded data | Scope claimed |
|-------|-------------------------------------|----------------------------|------------------------------------|---------------|

## Assumptions

<Anything proceeded on without confirmation. A wrong assumption must be cheap to reject.>

| # | Assumption | Risk if wrong | Confirmed? |
|---|------------|---------------|------------|

## Open questions

<Populated by the batched clarification round from the relevant skill file, or left by
spec-builder where a source didn't resolve something. Remove once resolved - don't leave
stale [NEEDS CLARIFICATION] markers around after they're answered.>

| # | Question | Owner | Priority |
|---|----------|-------|----------|
| 1 | [NEEDS CLARIFICATION] <question> | Product / Design / Backend / unclear | High / Medium |

## Acceptance criteria

<Every criterion must be checkable against the actual code/output, not vague.>

- [ ] Given <input/condition>, the system does <observable behavior>.
- [ ] Given <input/condition>, the system does <observable behavior>.

## Component / screen inventory

<Optional - fill when the feature has a UI surface, especially when spec-builder drew this
from a design source. Name, purpose, key actions, data shown. Omit this section entirely
for backend-only or non-UI changes rather than leaving it empty.>

| # | Screen/component | Purpose | Key actions | Reference |
|---|-------------------|---------|--------------|-----------|

## Interface mapping

<Optional - fill when the feature involves external/internal API calls. Never list an
endpoint that isn't confirmed against an actual API/schema source - unmapped actions go in
Gaps below, not fabricated here.>

| Action | Method | Endpoint | Key fields | Notes |
|--------|--------|----------|------------|-------|

## Gaps

<Anything a source didn't resolve or confirm - an action with no matching endpoint, a
screen with no confirmed spec - stated explicitly rather than filled in with a guess.>

## Impact / blast radius

**Impact scan:** <ran `scripts/impact.sh --symbols <every declaration I will change, remove or whose behavior changes>` before coding, and `scripts/impact.sh <base>` on the diff after. Method used: text search / reference tool>

| Symbol | Change | Consumers outside the change (areas) | Decision: still correct / adapted / out of scope (by whom) |
|--------|--------|--------------------------------------|-------------------------------------------------------------|
| <name> | <changed / removed / behavior> | <e.g. Features/Inbox (3 files), Tests (2)> | <...> |

<Populated during investigation, before task breakdown - every other call site, consumer,
or downstream assumption this change touches, found via cross-call-site search, not
assumption. Empty only after that search has actually been run and found nothing.>

## Context confidence

<high | medium | low - and why. What was read (map, flow, consumers via impact.sh), what was
not, and what is assumed. Shown to the developer at handoff.>

## Beyond this change (optional - omit if nothing real)

<At most two notes. For each: a better whole-codebase design you noticed, why this change
does not do it (the consumers or in-flight tasks that depend on today's structure), and
rough size. Information for the developer; not a task, and not done in this change.>

## Out of scope

<Explicitly excluded, to stop scope creep during implementation.>

## Dependencies

<Backend, other in-flight features, or third-party dependencies this spec relies on.>

## Notes

<Anything relevant discovered during investigation - existing patterns found, constraints
uncovered, etc.>
