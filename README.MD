# Forge-guide

> Forge code with intention. Guide it with review.

A lean, token-conscious spec-driven workflow for AI coding agents - forges code from a gated spec, then guides it through multi-agent review before it ships.

Inspired by GitHub Spec-Kit and the broader Spec-Driven Development (SDD) pattern, but scoped down: two documents instead of four, and a handful of mechanics those frameworks don't cover.

## Why this exists

Most SDD frameworks (Spec-Kit, BMAD, Superpowers) solve **consistency** - making sure the agent doesn't contradict itself or invent scope. None of them optimize for **cost**, none verify the implementation actually satisfies the spec afterward, and none handle rule staleness as your codebase evolves. This scaffold tries to close those gaps without the ceremony overhead built for 40-engineer teams.

## The eight pillars

1. **Spec-gate** - no code is generated until a spec exists and open questions are resolved.
2. **Lean ceremony** - `spec.md` + `tasks.md` only. No separate `plan.md` layer unless a task genuinely needs one.
3. **Token economy** - clarifying questions are batched and selectable (menu-style, not freeform back-and-forth); every session logs an entry in `logs/token-ledger.md` so the cost-saving claim is measurable, not assumed.
4. **Trust tiers** - every rule in `memory/constitution.md` and every skill file is tagged `HARD` (non-negotiable), `DEFAULT` (follow unless repo context disagrees), or `SUGGESTED` (style preference, easily overridden).
5. **Staleness / drift detection** - rules carry a `last-verified` date. `scripts/drift-check.sh` greps the live codebase for whether a rule's stated assumption still holds before the agent trusts it.
6. **Verification loop** - after implementation, `scripts/verify-spec.sh` (or the agent, manually) checks the code against the acceptance criteria in `spec.md`, not just against "did it compile."
7. **Security hygiene** - a standing `HARD` tier check in the constitution: no hardcoded secrets, no PII in logs, no bypassing existing auth/keychain patterns.
8. **Session-state handoff** - `session-state.md` is a short, structured "where I left off" file for solo devs jumping between projects - not a full transcript log.

## Layout

```
Forge-guide/
├── CLAUDE.md # thin root loader - points to constitution + relevant skill
├── memory/
│   └── constitution.md # tiered, dated, non-negotiable-vs-suggested rules
├── skills/
│   ├── new-feature.md
│   ├── bug-fix.md
│   ├── refactor.md
│   └── api-integration.md
├── specs/
│   └── template/
│       ├── spec.md # what/why + acceptance criteria + [NEEDS CLARIFICATION]
│       ├── tasks.md # implementation checklist, token-budgeted
│       └── verification.md   # post-implementation check against spec.md
├── session-state.md # compact handoff state, not a transcript
├── logs/
│   └── token-ledger.md # append-only cost log, rolled up periodically
├── scripts/
│   ├── drift-check.sh # compares skill assumptions vs current repo state
│   └── verify-spec.sh # checks implementation vs acceptance criteria
└── .claude/
    └── settings.json # hooks - deterministic enforcement, not just advisory md
```

## Flow

1. Copy `specs/template/` to `specs/00X-feature-name/`.
2. Fill in the problem statement in `spec.md`. Leave `[NEEDS CLARIFICATION]` markers where you're unsure.
3. Agent reads `CLAUDE.md` → picks the relevant `skills/*.md` → asks its clarifying questions as a single batched, menu-style round (see `skills/new-feature.md` for the question template) → resolves every `[NEEDS CLARIFICATION]` marker.
4. Agent writes `tasks.md` from the finalized spec.
5. Implementation happens task-by-task, referencing existing code by file:line, not by pasting whole files into context.
6. After implementation, run `scripts/verify-spec.sh` (or ask the agent to do it) - checks each acceptance criterion in `spec.md` against the actual diff.
7. Log the round in `logs/token-ledger.md` (rough estimate is fine - the point is trend, not precision) and update `session-state.md` before ending the session.

## What this is not

It's not a replacement for Spec-Kit at team scale - no CLI, no multi-agent config generation, no 30-tool compatibility matrix. It's a personal-scale scaffold, built to learn the mechanics of agentic dev workflows and to be genuinely useful for solo/small projects along the way.
