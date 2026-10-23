# Quality gate

Shared severity taxonomy and enforcement rules for generation and review - the same bar at
both ends, so strictness never drifts. This is the operating rulebook and is deliberately
short. Rationale, real incidents and full wording live in `memory/quality-gate-detail.md`:
open one section of it only when applying that check in depth, never at task start.

## Severity scale

- **CRITICAL** - will crash, corrupt data, deadlock, or is a real race condition.
- **HIGH** - memory leak, retain cycle, actor-isolation violation, Core Data misuse,
  security issue, or a state-consistency bug that makes a mandatory/enforced flow (forced
  update, required auth, a blocking gate) appear to succeed or complete when it didn't.
- **MEDIUM** - SOLID/DRY violation, architecture boundary violation, duplicate logic
  (including a new local extension duplicating one that already exists), poor error
  handling.
- **LOW** - naming, spelling, style, minor readability.
- **NIT** - optional polish, never blocks.

A violation of a `HARD` rule from `memory/constitution.md` is never below HIGH. Security
findings involving tokens/credentials default to CRITICAL if they can leak, persist
insecurely, or survive logout, and HIGH otherwise - reason about the worst case, never
downgrade because a leak "probably" won't be hit.

## Confidence

Every finding carries **High | Medium | Low**. Low means "a human should double-check",
not "weaker". If a check could not be fully traced within budget, say so at Low confidence
- never assert it as fact, never skip it silently.

## The gate

Identical at generation time (before a `tasks.md` item is marked done) and review time
(before a spec/PR is marked shippable):

| Severity | Effect |
|----------|--------|
| CRITICAL | Hard fail. No waiver. Fix required. |
| HIGH     | Hard fail by default. Fix required. |
| MEDIUM   | Fails by default. May be explicitly waived (Suppression below). |
| LOW      | Reported, non-blocking. |
| NIT      | Reported, non-blocking, not counted toward pass/fail. |

Zero CRITICAL/HIGH and zero un-waived MEDIUM = pass. Low confidence does not lower a
finding's severity for the gate.

## Check depth mode

Set by the person with the `Mode:` line at the top of `AGENTS.md` (or stated in the
task). Default **strict**. A mode changes only how much is searched and re-checked - never
the severity definitions, the gate table, or the verdict arithmetic. Every narrowing a mode
causes is disclosed in the output in one line (e.g. "fast mode: independent re-review not
run").

| | strict (default) | standard | fast |
|---|---|---|---|
| High-risk domains | exhaustive, repo-wide | exhaustive cross-call-site + verify-before-asserting | scoped to file/module unless a shared contract is touched |
| Sibling-instance check | every sibling in the file/domain | siblings in the same file/type; rest listed as not checked | the instance and its direct neighbours; rest listed |
| Independent pass before a PR | every non-trivial change, whole diff | high-risk hunks, plus any new public type/parameter/ownership decision | not run (disclosed) |
| Cleanup notes, "what this got right" | included | omitted unless asked | omitted |

Use `fast` for work outside the high-risk domains (copy, simple views, test-only changes);
use `strict` for auth/session, persistence, concurrency, shared contracts. `fast` accepts
that a CRITICAL/HIGH in a high-risk area can be missed - that is the trade, not a bug.

## Operating rules

- **Verify before asserting.** Open the actual declaration before claiming a symbol's type,
  nilability or behavior. The same applies to claims about the codebase's own state: that
  something has or lacks test coverage, that a test failure is pre-existing/unrelated, that
  a pattern being cited as a trusted reference is itself correct. A claim is something to
  check, not a recollection to trust, whichever direction it points.
- **A validator passing is not proof an edit worked.** After any scripted/bulk edit, grep
  for the specific change. `plutil`, a linter or a parse check only proves well-formedness.
- **Tag the evidence.** Mark each non-trivial claim `read` (seen in code), `probed` (one
  fact checked with a targeted grep/command/test) or `ran` (the behavior was executed).
  Runtime claims - API behavior, ordering, what a server returns, format coverage - need
  `probed` or `ran`; otherwise report them at Confidence: Low. Don't call something
  "verified" if it was only read; don't undersell something actually reproduced.
- **Disclose partial coverage.** Oversized diff: review highest-risk files first
  (auth/tokens, persistence, concurrency, entitlements, shared hooks) and name the files not
  reached. Tests: name exactly which targets/suites ran - "1302 passed, 3 failed" is
  misleading if it describes two of the three targets covering the diff.
- **Estimates are guesses unless measured.** Say so. A number carried over or re-split from
  another source must be disclosed as inherited, not presented as freshly derived.
- **New-code ratchet.** The gate applies to new and changed code, plus code whose behavior
  the diff directly affects (per blast-radius analysis) - not to pre-existing issues the
  change doesn't touch. Pre-existing issues found nearby get one NIT-tier "found while you
  were here" note; they never block.
- **Fewer, well-justified findings beat padding.** Don't flag idiomatic patterns as
  violations. Don't run a linter to confirm a lint-catchable issue. If unsure, Low
  confidence rather than asserted fact.
- **Suppression (MEDIUM only).** Inline marker
  `// forge-guide-ignore: <RULE-ID> reason: <short justification>` plus an entry in
  `logs/suppressions.md` (rule, file:line, reason, date). CRITICAL and HIGH are never
  suppressible.

## Mandatory checks (never conditional on being asked)

Depth scales with risk. **High-risk domains** - auth/session/token handling, persistence,
concurrency, a public/shared API surface, a contract invoked from more than one place - get
the full treatment (subject to Mode above). **Low-risk, file-local code** gets a scoped
check, stated in one line ("scoped to file-local: no external callers, not
security/persistence/concurrency"). Unclear tier: treat as high-risk once and note the
ambiguity so the next pass is cheaper.

- **Cross-call-site.** Any shared contract the change touches (delegate callback, hook or
  closure property, notification name, protocol method, singleton entry point): search for
  every other place it is invoked or assigned, not just the one in the diff. Method, best
  first: a reference lookup from a local language-server/IDE tool if the session has one,
  else `scripts/impact.sh <base> <head>` (finds the changed declarations itself and lists consumers in untouched files) or `scripts/xref.sh <symbol> [--also <other spelling>]` (text search grouped into
  definitions / production / tests), else grep. Say which in `Checks run`. If the budget
  doesn't allow tracing every symbol, name the symbol and mark it Confidence: Low.
- **Sibling-instance.** After finding or fixing one instance of a bug shape - in review,
  investigation or a fix - run the same check on its siblings in the same file/domain, or
  say which weren't checked and why. "I checked the representative one" is not "I checked
  them all."
- **Downstream-assumption.** When a change alters what a failure path does, re-read every
  later line in that function and its siblings for logic that assumed the old behavior.
- **Value has a consumer.** Every new or forwarded parameter, flag or stored property must
  name the place that reads it; if none can be named, remove it. "It was already there"
  (a legacy flag carried forward) is not a consumer.
- **Already-fixed / already-exists.** Before generating anything (and before flagging
  something "missing"), check recent commits/PRs and existing utilities - mechanics in
  `context/context-scan.md`.
- **Post-merge signature-compatibility.** A clean merge or rebase is not a compatible one.
  After any merge, run cross-call-site on every type/method whose declaration changed on
  either side, across every file the merge touched - conflicted or not.
- **Say what was checked, not "done".** Until the independent pass has run, report "author
  pass complete, independent pass pending", never "done" or "nothing left". Repeated
  "done" claims that a fresh reader then broke cost trust and a review round each time.
- **Tests ship with the code, with honest expected values.** New logic gets its tests in the
  same task, in a folder that is part of a compiled target; expected values come from the
  requirement, not the code's output (IOS-038, IOS-043). Know the repo's CI gates (e.g.
  diff coverage) and check them before pushing. Changing a field's source: sweep its tests
  (IOS-041).
- **Independent pass.** Before a PR is raised, a pass by something other than the context
  that wrote the change is required: the `forge-reviewer` subagent, a separate review
  tool, or a human. Scope follows the Mode table above (every non-trivial change in
  `strict`; high-risk domains - concurrency, persistence ordering, shared
  checkpoint/contract - plus any new public type, parameter or ownership decision in
  `standard`; not run in `fast`, disclosed). Tick it in the spec's `verification.md`;
  `scripts/verify-spec.sh` fails while it is unchecked. A same-context pass is labelled
  "author pass, not independent" and can never produce an Approve.
- **Platform / language API currency.** Flag use of anything in or past its deprecation
  window relative to the project's declared minimum target. Prefer ecosystem tooling over
  memory; verify against official docs or mark Confidence: Low; flag only genuine
  modernization (state the minimum version and the concrete cost of staying), else NIT.
  Stack specifics: the playbook.

## Where rules come from

- `memory/constitution.md` - project-wide HARD/DEFAULT/SUGGESTED rules.
- `playbooks/<stack>.md` - stack-specific incidents, each with an ID and severity. Never
  read a playbook whole: `scripts/playbook.sh index`, then `scripts/playbook.sh show <ID>`
  for the few entries that match the code being touched.
- Skills and the review prompt reference these sources rather than hardcoding severities,
  so one edit here is picked up everywhere.
