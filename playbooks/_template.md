# Playbook template

Copy this to `playbooks/<stack>.md` when adding a new language/stack. Read
`playbooks/ios-swift.md` first as a worked example of the format and depth.

## The one rule that matters

**Every entry must be a real incident, not a hypothetical one.** `playbooks/ios-swift.md`
exists because it was built from actual production PRs and review sessions - that's what
makes it worth more than generic "best practices" advice the model already knows. A
playbook entry invented from training-data intuition ("Python devs often forget to close
file handles") adds no real signal over what the model would already consider, and dilutes
the file's credibility. If you don't have a real Seen for something yet, leave it out -
add it the first time it actually happens.

This means a brand-new stack playbook starts **empty or nearly empty**, and that's correct.
Fill it in as real incidents accumulate, exactly like `ios-swift.md` did.

## Required structure

```markdown
# Playbook: <stack name>

<One line: what this covers and what generates its entries.>

---

### <PREFIX>-001 - <short title> [<SEVERITY>]

**Seen:** <what actually happened - specific enough that a reader recognizes the shape,
not a generic description>
**Action:** <the concrete rule - what to do instead, stated as an instruction>
```

- `<PREFIX>` — a short stack tag (e.g. `AND` for Android/Kotlin, `TS` for TypeScript/Node,
  `PY` for Python). Keep IDs stable once assigned — other files may reference them.
- `<SEVERITY>` — one of CRITICAL/HIGH/MEDIUM/LOW/NIT per `memory/quality-gate.md`.
- Number sequentially; don't renumber existing entries when adding new ones.

## Required section: platform/language currency

Every stack playbook needs its own version of `playbooks/ios-swift.md`'s IOS-017 entry -
the stack-specific instance of `memory/quality-gate.md`'s generalized platform/language
API currency check. At minimum, state:
- How this stack declares its minimum supported version (a config field, a manifest key, a
  language-level pragma).
- What existing tooling can check for deprecated usage automatically (a linter rule set, a
  dedicated scanner) - prefer running that over reasoning from memory.
- Where to verify current deprecation status when uncertain (the ecosystem's official docs
  or changelog).

## When to retire an entry

If a pattern stops being reachable (the codebase migrated away from it entirely, the
underlying API was removed), don't delete the entry silently - mark it superseded and say
why, so the history of what used to bite this codebase isn't lost.

## If a similar doc already exists elsewhere

If the org already maintains a separate precautions/lessons-learned doc for this stack (a
team wiki page, a doc used by another tool), check it for overlap before adding a new
entry here - real usage has already produced near-duplicate entries in two parallel docs
this way. Either point to the existing doc instead of duplicating it, or reconcile the two
explicitly rather than letting both grow independently and drift apart.

## A real caution, not just a design preference

A formal benchmark comparing full-skill loading, compact IDs, short guidance, and
retrieval-based approaches for AI code review found no conclusive evidence that loading
extensive in-context guidance improves review quality over an ordinary review, across
several configurations tested. This project's own real usage has shown the opposite in
specific cases - playbook entries here have caught real bugs other passes missed - so
this isn't a reason to stop building the playbook. It is a reason to keep entries compact,
keep loading them selectively rather than dumping the whole file in every time (see
`AGENTS.md`'s reading-efficiency section), and to actually use the pruning
discipline already built into this project - retire entries that stop earning their
keep, don't let the file grow indefinitely on the assumption that more guidance is always
better. Measure this the same way everything else here gets measured: does a specific
entry keep showing up as relevant in real `test-runs.md`/`session-report` entries, or is
it dead weight nobody's checked against in months.
