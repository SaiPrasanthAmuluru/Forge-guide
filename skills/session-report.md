# Skill: session-report

Use at the end of a batch of work (multiple bug fixes, new-feature generations, and/or PR
reviews) to produce one consolidated report, instead of handing over individual spec/log
files for each task separately.

## Trigger phrases
"generate a report", "summarize this session", "give me a report of everything we did"

## What to gather

(Where the toolkit is kept outside the project, `specs/`, `logs/` and `session-state.md` are
under `<project>/.forge/`. If a folder or file below does not exist, say so once in the
report and build that section from the conversation; do not stop or invent contents.)

- Every `specs/*/` folder touched or created since the last report (or since a given date
  if the person specifies one) - `spec.md`, `tasks.md`, `verification.md` for each.
- Every new entry in `logs/token-ledger.md`, `logs/test-runs.md`, and
  `logs/suppressions.md` since the same cutoff.
- The current `session-state.md`.
- Every review run this session, even if its output was only shown in chat and never
  saved to a file - pull the findings back from the conversation itself.
- Any `playbooks/<stack>.md` entries added or referenced this session.

- The computed numbers: run `scripts/report-metrics.sh [since-date]` once and paste its
  tables into the sections below instead of recounting by hand. It reads
  `logs/token-ledger.md`, `logs/phase-ledger.md` and `logs/findings-ledger.md`.

Don't re-run anything else to gather this - it's a summary of what already happened, not a new
analysis pass.

## Report structure

```markdown
# Session report - <date range or session label>

## Overview
- Tasks covered: <N> (bug fixes: <n>, new features: <n>, reviews: <n>)
- Repos/PRs touched: <list>

## Per-task summary

### <Task 1 name> - <skill used> - <outcome: done/blocked/in-progress>
- Spec: `specs/<folder>/spec.md`
- One-line what changed and why
- Quality-gate outcome: <severities that fired>, <any suppressions and why>
- Verdict (if a review): <Approve / Approve with comments / Request changes>, per the
  mechanical gate rule in `memory/quality-gate.md` - never softened by overall impression

<repeat per task>

## Aggregated quality-gate findings

| Severity | Count | Notes |
|----------|-------|-------|
| CRITICAL | | |
| HIGH     | | |
| MEDIUM   | | (waived: N, see suppressions) |
| LOW      | | |
| NIT      | | |

**If this session used more than one review rubric or tool** (forge-guide's quality-gate
alongside a separate review skill/tool with its own severity scale), report each rubric's
findings in its own table - never convert or merge severities across two different scales.
Label which table is which and note it in Friction/design feedback if running two review
systems on the same diff seems redundant rather than complementary - that's worth flagging,
not silently accepting as normal.

## Token/cost trend

| Task type | Tasks | Tokens (total, ~) | Per task (~) | Mode(s) |
|-----------|-------|-------------------|--------------|---------|
| gen / fix / review / merge / report | <n> | <from logs/token-ledger.md> | <total / n> | <modes used> |

- Compare per-task cost against the previous report's table. **State plainly if it rose**,
  and name the likely cause from this list rather than leaving the number bare: a long
  chained session, a rule/playbook file read whole instead of `scripts/playbook.sh`, an
  unchanged diff or file re-read, a Mode change (`standard` → `strict`), a stale
  `context/base-snapshot.md` forcing a wide re-scan.
- If the ledger has no token figures for work this report covers, say so and give a rough
  estimate marked `~` - don't write "not tracked" and move on; that is how the trend
  stayed invisible.
- Total clarification rounds this session: <n>
- Full-file regenerations: <n> (flag any - this is what the workflow exists to avoid)
- Any task where investigation required re-reading the same large file multiple times

## Where the tokens went (task and phase)

From `report-metrics.sh`: tokens by phase (map, flow, questions, scans, generate,
self-check, review, rework), the costliest tasks, and the cause tags logged for extra
context. For each of the three costliest tasks write one line: what internal step took the
tokens (reviewing a PR, generating one file, rebuilding the map, re-reading a shared
contract) and what made it need so much context. Then say whether that context was
avoidable: a stale map, a helper or consumer nobody had listed, a question that was
answerable from code. Flag if rework is above ~20% of phase tokens: that is generation
that skipped a check.

## What others caught that we missed (escapes)

Every real finding that a human reviewer, another review agent, CI or production reported
and our own passes did not. One row each, from `logs/findings-ledger.md`:

| Finding | Caught by | Sev | Should have been caught by | Would catching it earlier have saved tokens? |
|---|---|---|---|---|

- "Should have been caught by" names the existing check that failed to fire, or
  `none-existed` if the gap is a missing check; the second case is a proposed rule or
  playbook entry (draft it under Playbook activity).
- The last column is a judgment with a reason, never a number you invented: late fixes cost
  a rework round plus a re-review; say which, using the phase ledger.
- Also list findings that **only** our pass caught and others missed (unique catches), so the
  comparison is two-sided. Report the escape rate and precision from the metrics script.
- If another review agent runs on the same diff, treat it as a separate rubric (see above)
  and note which findings overlap: pure overlap is wasted tokens, a unique catch is value.

## Agent and skill effectiveness

From `report-metrics.sh`, in this order and only what has data:
- Developer outcome per task (accepted as is / edited / rejected, from the ledger notes) and
  why for each edit or rejection. This is the adoption signal: if developers rewrite or reject
  output, the cause is a finding about the workflow, not about the developer.
- Escape rate, and precision per pass (independent pass, own review, scans, self-check).
- Review-phase tokens per true finding.
- Playbook entries cited by a finding but never loaded (a retrieval failure), and entries
  loaded repeatedly that never hit (prune candidates; decide only with several reports of data).
- Clarification rounds and any question that was answerable from code.
- Which skill ran for which task type, and the cost per task type compared with the last report.
- Scan yield: how many `impact.sh` / `reuse-scan.sh` flags led to a spec decision or code
  change versus were dismissed.
If a table is empty, say the ledger was not filled for that and backfill per the rules below.

## Playbook activity

- Entries referenced by ID this session (e.g. <STACK>-001, <STACK>-012): <list>
- New entries proposed but not yet added (a real incident found this session that isn't
  in a playbook yet): <list with a drafted Seen/Action for each>

## Review misses & development misjudgments (self-assessment)

Include this section whenever the person asks for it directly, or proactively whenever a
finding in this session was only caught on a second/independent pass after an earlier pass
(self-review or otherwise) missed or misjudged it - that gap is exactly what this section
exists to make visible rather than quietly correct and move past. For each: what was
claimed or missed, what was actually true, how it was caught, and which mandatory check (if
any) existed specifically to prevent it but didn't fire. Ordered by how much it matters,
most consequential first. This is not a blanket apology section - state the specific gap
plainly, the same way a finding in the review section itself would be stated.

## Continuing a task from a prior report

If this session's work continues a task a prior report already opened (the same spec, same
fix, another round), say so explicitly and reference that report by name/date. Report this
session's findings as their own table, not merged/re-totaled into the prior report's
numbers - treat sequential rounds of one task as sequential, not additive, and say so in
one line rather than leaving the reader to infer it.

## Friction / design feedback

- Anything that felt like the workflow got in the way, asked something already-answerable,
  or where the gate's verdict and the reviewer's own judgment disagreed (see the run where
  this happened before - keep watching for it)
- Any tool/environment gap hit (not a forge-guide design issue, but worth recording) -
  e.g. a permission wall, a parsing failure in a script, a missing local tool

## Open items carried forward

- <anything left unresolved, pulled from session-state.md's Open/unresolved section>
```

## Lightweight variant: a batch of ad hoc fixes with no natural spec

Some sessions don't fit the structure above at all - a string of independent one-error-at-
a-time compile fixes pasted in by the person after a local build, a merge-conflict
resolution, an environment/runtime diagnosis with no ticket behind it. Forcing the full
per-task/spec/quality-gate structure onto this shape produces a report that's mostly "not
applicable" placeholders (a real session hit this: ~13 independent compile-error fixes plus
one merge, with no specs/ folder opened and no review pass run at all). Use this shorter
form instead when there's no spec, no review pass, and the work is a batch of small
independent fixes rather than a feature/bug-fix/review task:

```markdown
# Session report - <date range or session label> (lightweight)

## Overview
- Shape: ad hoc fix batch (no specs/ folder, no review pass this session)
- Tasks covered: <n> (fixes: <n>, merge resolutions: <n>, diagnoses: <n>)
- Repo/branch: <name>

## Fixes applied
| File | Fix | Verified? |
|------|-----|-----------|
| ... | ... | reading-verified / build-verified / test-verified |

## Notable findings surfaced incidentally
(dead code removed, a merge leaving a stale reference, a real bug found while fixing
something else - anything worth a playbook entry, even though no review pass was run)

## Playbook activity
- New entries proposed but not yet added: <list with drafted Seen/Action>

## Review misses & development misjudgments (self-assessment)
(same rules as the full report - include whenever something was missed on a first pass, or
whenever asked)

## Friction / design feedback
## Open items carried forward
```

Still apply the mandatory-check discipline from `memory/quality-gate.md` to work covered by
this shape - a merge resolution still needs the post-merge signature-compatibility check, a
dismissed-as-unrelated test failure still needs independent diagnosis before being called
that - the lightweight report format is about the *report's* structure, not a lighter bar
for the work itself. Still backfill `logs/token-ledger.md`/`logs/test-runs.md` per the rule
below; a session with no spec is not exempt from that.

## Rules

- **This is a summary, not a re-review.** Don't re-analyze code while writing the report -
  pull conclusions already reached during the session.
- **Backfill the logs, don't just summarize around them.** If `logs/token-ledger.md`,
  `logs/test-runs.md`, or `session-state.md` are still blank/template for work this report
  covers - meaning the per-task logging instructions in `AGENTS.md` weren't
  followed live - write real entries into those files now (`ledger-append.sh`, `phase-log.sh`, `finding-log.sh`) from what's known this session,
  don't just let the report itself be the only record. Rough estimates are explicitly fine
  per the ledger's own rule; an approximate real entry beats a perfectly-accurate one that
  never gets written. Note in Friction/design feedback that the live logging didn't happen
  and had to be backfilled - that's a real signal worth tracking across sessions, not a
  detail to smooth over.
- **The verdict/severity numbers must match what was actually produced this session** -
  don't round up a "Request changes" review into a softer summary line, and don't recompute
  severities differently here than the review itself used.
- **Keep it to what actually happened.** If a section has nothing for it (no suppressions
  used, no new playbook entries), write "none this session" rather than omitting the
  section - a missing section reads as "forgot to check," not "nothing to report."

## Map additions (every report)

List conventions, shared helpers, shared processes and CI facts that this session's review
comments or misses revealed and that `context/base-snapshot.md` did not contain, and add
them to the map (one line each, with a path). Write "none" if there are none. This is how
the map learns from the reviews instead of repeating them.
