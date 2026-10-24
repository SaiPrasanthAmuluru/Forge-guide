# Quality gate - detail and evidence

Rationale, real incidents and full wording behind the rules in `memory/quality-gate.md`.
**Do not read this file at the start of a task.** The core file is the operating rulebook;
come here only when applying one specific check in depth, or when deciding whether a rule
still earns its place (see AGENTS.md "Maintenance"). Severity scale, confidence, gate
table and check-depth modes live only in the core file - not duplicated here, so they
cannot drift.

Use `grep -n '^## \|^- \*\*' memory/quality-gate-detail.md` to find a section, then read
just that range.

## False-positive discipline

Prefer fewer, well-justified findings over padding the list - a LOW/NIT flood buries the
real ones. If you're not sure whether something is actually a duplicate, a race, or a real
bug, say so and mark Confidence: Low rather than asserting it as fact. Don't flag idiomatic
patterns as violations just because they differ stylistically from another convention.
Before asserting a fact about a symbol's type, nilability, or behavior, open its actual
declaration and confirm it - a confidently wrong claim about code that was never actually
checked is worse than no finding at all. This applies equally to claims about the
codebase's own current state, not just the code under direct scrutiny: whether something
already has test coverage, whether a test failure is pre-existing/unrelated to the current
change, whether an existing pattern being cited as a trusted reference is itself correct.
Real usage caught this exact gap - "verify before asserting" applied rigorously to code
under review, but a claim about existing test coverage was stated from memory, was wrong,
and had to be walked back in the same message once actually checked. Treat a claim about
the codebase as a claim to verify, not a recollection to trust, regardless of which
direction the claim points (something existing vs. something missing, a failure being
related vs. unrelated).

A validator passing is not proof the intended change took effect - it only proves the file
is still well-formed. Real incident: a bulk edit intended to delete several lines was
reported as clean because a syntax lint passed on the project file afterward; the lint
only checks syntax, and a later `grep` showed the edit had silently done nothing (a
macOS/BSD `sed` incompatibility swallowed it with no error; a stack playbook entry covers it). After any edit made by a script/tool rather than by hand, confirm the specific
change actually happened (grep for what should be gone/present) - don't let "the validator
didn't complain" stand in for "the edit worked." These are different claims, and a
format/syntax validator is blind to the second one by construction.

The same honesty applies to estimates. A time/effort estimate produced without actual
measurement (hours for a task, size of an implementation) is a qualitative guess based on
diff/task complexity, not a calibrated figure - state that plainly whenever one is given,
and don't let it be treated as a deadline commitment. If a number is carried over from
another source (a pasted transcript, an earlier session) and adjusted rather than
independently re-derived for the current context, say so explicitly rather than presenting
it as freshly calculated - a mechanically re-split inherited number is not the same as one
sanity-checked against the actual codebase it's now describing.

## The new-code ratchet

The gate applies to **new and changed code only** - the diff, plus code whose behavior is
directly affected by the diff (per impact/blast-radius analysis). It does not retroactively
fail a task or PR for pre-existing issues in the surrounding file/module that the current
change doesn't touch or depend on.

Why: applying strict mode to an entire legacy file on day one makes every task fail
permanently and the tool stops getting used - the opposite of the goal. The ratchet keeps
the bar high going forward without requiring a full-codebase rewrite first, and keeps
review/generation scoped to what's actually relevant, which also keeps token spend down -
no re-analyzing untouched code every pass.

Pre-existing issues discovered incidentally while working nearby are surfaced as a NIT-tier
note ("found while you were here, not blocking this task") rather than blocking - visible
for later cleanup, never silently ignored, but never a reason the current task can't ship.

## Scale handling for oversized diffs/specs

If there's more to review than can get genuine attention within budget, don't silently
truncate and present something that looks complete but isn't. Prioritize the
highest-risk files first (anything touching auth/tokens, the persistence layer,
concurrency, permission/capability config, or a shared callback/hook), review
those thoroughly, and explicitly state which files were not reached and why. A disclosed
partial review is honest; an undisclosed one is actively misleading.

The same discipline applies to test runs. If only some of the relevant test
targets/suites were actually run, say exactly which ones - a result like "1302 passed, 3
failed" is misleading if it's silently the state of two targets out of three that cover
the diff, presented as if it describes the whole branch. Name what ran and what didn't,
the same way an oversized-diff review names what wasn't reached.

## Execution-verified vs. reading-verified

State explicitly, in a finding or a report, whether a claim was confirmed by actually
running something (a test, a build, a reproduction) or only by reading code statically -
these carry different reliability and the difference is worth surfacing, not blurring
into one undifferentiated "confirmed." A finding backed by a live failing test is stronger
evidence than the same finding backed by careful reading alone, even when both reach the
same conclusion; say which one it is. This cuts both ways: don't claim something is
"verified" when it was only read, and don't undersell something that was actually
reproduced by describing it the same way as a static read.

## Suppression

A MEDIUM finding may be waived, but never silently. Suppression requires:

1. An inline marker at the site, with a rule ID and a reason:
   `// forge-guide-ignore: <RULE-ID> reason: <short justification, e.g. ticket/context>`
2. An entry appended to `logs/suppressions.md` (rule ID, file:line, reason, date) - an audit
   trail, not a bypass. Anyone reading the repo later can see what was waived and why, and
   re-evaluate it once the reason no longer applies.

CRITICAL and HIGH findings cannot be suppressed this way - they must be fixed, or the
task/spec is not marked done.

## Mandatory checks (never conditional on being asked)

These stopped being "only if the reviewer thinks to check" the moment they became a
standing part of the gate. Both generation and review run them by default, every time -
but **not at the same depth for everything touched**. Scope the depth to the risk, not
uniformly to every line:

- **High-risk domains get the full exhaustive treatment**: anything touching auth/session/
  token handling, persistence, concurrency, a public/shared API
  surface, or a contract genuinely invoked from more than one place. Full cross-repo
  search, full live-source verification, no shortcuts.
- **Low-risk code gets a lighter, explicitly-scoped check**: a private helper used only
  within the file/module being changed, with no external callers and no involvement in the
  domains above, gets a check scoped to that file/module rather than a repo-wide search.
  This is a real narrowing, not a silent skip - say so in one line ("scoped to file-local:
  no external callers, not security/persistence/concurrency") so the choice is visible,
  same discipline as disclosing a partial review on an oversized diff.
- When it's genuinely unclear which tier something falls in, default to the high-risk
  treatment once, not every time going forward - note the ambiguity so it's cheaper to
  resolve on the next pass (e.g. confirm via a repo-map or naming convention whether a
  given module is ever exposed outside its own file).

This scoping exists because thoroughness and token cost are a real tradeoff, not a solved
problem - the point isn't to cut corners on what actually matters, it's to stop spending
the same exhaustive budget on code that was never at risk in the first place.

- **Cross-call-site check.** (Method: local reference lookup if available, else
  `scripts/xref.sh`, else grep; a text search misses other spellings - selector or
  notification strings, protocol conformances, reflection, generated code - so search
  those explicitly and say what was searched.) Any shared contract touched by the change - a delegate
  callback, an integration hook/closure property, a notification name, a protocol method,
  a singleton entry point - gets searched for every other place it's invoked or assigned,
  not just the site in the diff. A hook named for one purpose is frequently reused for a
  related but distinct one; code that assumes the narrower meaning without checking is a
  recurring, hard-to-spot bug class. If there isn't budget to trace every touched symbol,
  say so explicitly and name the symbol at Confidence: Low rather than skipping silently.
- **Sibling-instance check.** After fixing one instance of a bug shape, search the rest of
  the diff and file for the same shape before calling the fix complete - fixing one of two
  identical bugs and missing the other is a recurring failure mode, not a one-off. This
  applies during review and investigation too, not only after a fix: a real review pass
  checked one function's actor isolation carefully and never checked its three siblings in
  the same file; checked one entity's batch-delete cascade risk and never checked whether
  the same race applies to other entities; checked one function's callers and never traced
  the analogous functions sitting right next to it. In each case a check applied thoroughly
  to one instance got silently generalized to its siblings without ever actually running it
  against them. When a check is worth running on one function/entity/call site, explicitly
  run it against every sibling in the same file/domain before drawing a conclusion, or say
  plainly which siblings weren't checked and why - never let "I checked the representative
  one" stand in for "I checked all of them."
- **Downstream-assumption check.** When a change alters error-handling philosophy or what a
  failure path does (e.g. a delete's failure stops being fatal), re-read every subsequent
  line in that function and its siblings for logic that implicitly assumed the old behavior
  still held.
- **Already-fixed / already-exists check.** Before generating anything, check whether the
  problem is already solved (recent commits, linked PRs, an existing extension/utility) -
  see `context/` for the mechanics. Applies to review too: before flagging something as
  missing, confirm it doesn't already exist elsewhere in the codebase under a different
  name.
- **Post-merge signature-compatibility check.** A merge (or a rebase) that resolves cleanly,
  with no textual conflict, is not the same as one that's semantically compatible - a real
  incident shipped a file that merged without conflict but still called a method as if it
  returned its pre-merge type, because the other side of the merge had changed that method's
  return type and no conflict marker ever flagged it (a stack playbook entry covers this shape).
  After resolving any merge, run the cross-call-site check above against every
  type/method/property whose declaration changed on either side of the merge - across every
  file the merge touched, not only the files git reported as conflicted. This is a specific,
  mandatory application of the cross-call-site check to merges, not a separate check.
- **Independent re-review for high-risk domains.** A self-review performed in the same
  context as the implementation is not sufficient for anything touching concurrency,
  persistence ordering, or a shared checkpoint/contract - validated by two independent real
  incidents: one where a same-session self-review missed a compile-breaking error and an
  actor-isolation violation in its own fix, caught only once an independent re-review was
  explicitly requested; another where a dedicated self-review carefully checked one
  checkpoint's concurrency but missed an identical-class ordering bug in a second
  checkpoint added the same session, which then shipped to production before a later,
  separately-requested adversarial pass caught it. Having just written the code appears to
  make the same blind spots invisible to a review done immediately after, specifically for
  timing/ordering assumptions about a framework or helper's actual behavior. For anything
  in this risk tier, treat a second, independent pass - ideally with no prior context of
  having written the fix - as required before marking the work done, the same way the
  cross-call-site check is required and not optional. Running a genuinely separate
  review tool/skill (a different rubric, a different pass with fresh context) satisfies
  this requirement just as well as a formal "independent review" step - what matters is
  that the second pass isn't the same context that just wrote the fix, not which tool runs
  it. But apply the same risk-based scoping as every other check here: this is required
  for the high-risk tier, not a blanket "always run two reviews on everything" - doubling
  review cost on a low-risk diff is exactly the uniform-exhaustiveness waste this scoping
  principle exists to avoid.
- **Platform / language API currency check.** Every ecosystem has its own deprecation
  lifecycle (a language's own deprecation attributes, a framework's release notes, a cloud
  provider's dated API-version policy) - flag any usage of something already in or past its
  deprecation window relative to the project's own declared minimum target (deployment
  target, `minSdkVersion`, `engines` field, `python_requires`, a `go.mod` directive, or
  equivalent). Two things make this check honest rather than guesswork:
  1. Prefer existing ecosystem tooling where one exists (a linter's deprecation rules, a
     dedicated scanner) over reasoning from memory alone - training knowledge of "current
     best practice" goes stale the same way anyone's does, and this is a fast-moving
     surface.
  2. Before asserting something is deprecated or superseded, verify current status against
     official documentation if uncertain, and mark Confidence: Low if this run has no way
     to verify. Only flag *genuine* modernization - an actual safety/clarity win - not
     stylistic churn; state the minimum version a suggested replacement needs and the
     concrete cost of leaving the old pattern, or it's NIT, not MEDIUM.
  The stack-specific version of this check (what tooling to shell out to, what counts as
  the declared minimum target, common deprecated-vs-superseded patterns for that stack)
  lives in `playbooks/<stack>.md` - see `playbooks/_template.md` for the section every
  stack playbook should have.

