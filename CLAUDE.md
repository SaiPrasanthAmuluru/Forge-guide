# Project instructions

Mode: strict

<!-- strict | standard | fast — how much to search and re-check. Never changes severities,
the gate, or the verdict. Definitions: `memory/quality-gate.md` "Check depth mode". -->

`AGENTS.md` is the entry point for agents other than Claude Code; the two are kept in sync
by hand. Both stay short on purpose — a bloated instruction file hurts agent performance
and inflates cost — so detail lives in linked files that are loaded only when needed.

## Load order (the token budget)

**Always, once per session:** this file, `memory/constitution.md`, and `memory/quality-gate.md`
(core only, ~2K tokens). `HARD` constitution rules and CRITICAL/HIGH gate findings are
non-negotiable.

**Only when the task needs it:**
- one skill file from `skills/` for the task type — never all of them
- playbook entries: run `scripts/playbook.sh index` once, then `scripts/playbook.sh show <ID>`
  for the entries matching the code being touched (`find <keyword>` to search). Never read a
  playbook file whole
- `memory/quality-gate-detail.md`: one section, only when applying that check in depth
- `context/flow-brief.md` (generation tasks: flow map, questions, stop-and-ask)
- `context/base-snapshot.md` is read in full at the start of every generation task (it is capped
  at ~2.5K tokens; after the freshness check), `skills/build-context.md` only to build/refresh it
- `review/review-prompt.md` (reviews only), `skills/session-report.md` (reports only)

## Before writing any code

1. Check `specs/` for an active spec matching the task. None, and a source (ticket/PRD/
   design/API doc) exists → `skills/spec-builder.md`; otherwise start one from
   `specs/template/` before generating code.
2. **Read the overall codebase map first, in full: `context/base-snapshot.md`** (purpose and
   scope, structure, where shared helpers and processes live, entry points, test and CI gates). Run
   `scripts/check-context-freshness.sh`: current (or behind but untouched in the paths it
   cites) -> use it, no refresh; stale -> `refresh-context.sh` and re-check only the
   affected rows. Read it once per session, not again per task. Reuse a still-valid
   `context/areas/<area>.md` flow note instead of re-tracing the area; missing or still the template -> build it with
   `skills/build-context.md` (a bounded probe, then the developer confirms the uncertain
   rows). Never write code without the map. Then run the context scan for the area: what
   already exists, what is already solved, which entry point to use. Record `Map consulted`
   and fill Existing-code context in the spec. Order is always map -> flow -> questions -> code.
3. Map the flow the change plugs into and turn what is unclear into questions
   (`context/flow-brief.md`): read what code can answer, then ask — in ONE batched,
   menu-style round — starting with "my understanding" for the person to confirm, then the
   relevant flow questions (2-4 short options each, last option open text), then the
   assumptions being proceeded on. Resolve every `[NEEDS CLARIFICATION]` marker in that
   round. Never serially, one question per turn. Stop and ask again mid-work if the code
   contradicts the flow map or a step has two readings. For every new type, file, parameter or flag, fill the spec's
   "Decisions & why" (reader, existing mechanism, why not derive it, honest scope) - it
   becomes the PR description.
4. Pick the matching skill file (new feature / bug fix / refactor / API integration).
5. **Impact and reuse, scripted (mandatory, every generation task).** List the declarations
   you will change, remove or whose behavior changes and run
   `scripts/impact.sh --symbols <names>`; run `scripts/reuse-scan.sh --need "<words>"` for
   what you intend to build with. Fill the spec's Impact table and Reuse scan line from the
   output (consumers in untouched files each get a decision). A local reference tool may
   replace the text search; say which was used. Shared contracts (delegate, hook,
   notification, protocol method, singleton entry point) additionally get `scripts/xref.sh`.
6. Run `scripts/drift-check.sh` mentally or literally; if a skill's assumption about the
   codebase looks outdated, flag it — don't trust the doc over the live code.

## While writing code

- Targeted edits (str_replace-equivalent) over full-file rewrites.
- Reference existing code by `file:line`; don't paste large blocks to re-explain them.
- Tiers: `HARD` never violated; `DEFAULT` followed unless the repo clearly disagrees (say so
  when overriding); `SUGGESTED` applied when convenient.
- Before writing in a domain a playbook covers, pull the matching entries (see Load order) —
  real past incidents, not style preferences.
- After fixing one instance of a bug shape, check the diff and file for the same shape
  before moving on (sibling-instance check).
- **A merge isn't done when the conflict markers are gone.** Run the post-merge
  signature-compatibility check (`memory/quality-gate.md`) on every changed type/method
  across every file the merge touched, conflicted or not. If it touches generated or
  structural project files (build/project manifests, lockfiles), run a structural check for
  stale references whether or not git flagged a conflict there; a syntax lint doesn't catch
  this. Stack specifics are in the stack playbook (iOS: IOS-028, IOS-029).

## After writing code

Keep the developer in control (`memory/constitution.md`: Developer control, Fit the code as it
is today). Finish with a short handoff, not a victory lap: what changed and in which files;
what you deliberately left untouched; what you read and what you could not verify (context
confidence); how to check it; and, only if real, one "Beyond this change" note. Do not commit,
push or open a PR unless asked.

1. Check the implementation against `spec.md`'s acceptance criteria — every one, explicitly.
2. Run the applicable `memory/quality-gate.md` checks on the diff, scoped to new/changed
   code (the ratchet). The gate applies at generation time, not only at review time. Re-run
   `scripts/impact.sh <base>` and `scripts/reuse-scan.sh <base>` on your own diff and put
   anything new into the spec.
3. **Before raising a PR, run the independent pass** — the `forge-reviewer` subagent or a
   human, not the context that wrote the change — at the depth the Mode sets, and tick it
   in `verification.md` (`scripts/verify-spec.sh` fails until it is). A same-context review
   is an "author pass, not independent" and can't approve. Real result: a fresh reader
   found in minutes what the author pass missed, mostly design and ownership questions.
4. Update `session-state.md`: done, open, next unresolved decision — a few lines.
5. Append one row to `logs/token-ledger.md` **now, per task**: task, Mode, approximate tokens
   used (session token count from `/cost` or `/context` before vs. after the task), clarification
   rounds, full-file regenerations, playbook IDs loaded. Reconstructing it later costs more
   than a one-line append; `skills/session-report.md` backfills only as a fallback.

**Where state lives.** When this toolkit is the project, `specs/`, `logs/` and `session-state.md`
sit beside this file. When the toolkit is kept outside the project (the normal case for a
shared copy), they live in the project under `.forge/` (`.forge/specs/`, `.forge/logs/`,
`.forge/session-state.md`); `scripts/ledger-append.sh` and `scripts/pr-gate.sh` already look
there. Templates, playbooks, scripts and skills are always read from the toolkit.

## Working agreement

- Don't run builds, test suites or anything that changes the developer's checkout unless
  asked; the developer runs builds. Say what should be run and what to paste back. The
  read-only toolkit scripts (`playbook.sh`, `diff-scope.sh`, `check-context-freshness.sh`)
  are part of the workflow and are fine.
- Report "author pass complete, independent pass pending" until the independent pass runs;
  not "done".
- Don't start a fix the developer didn't ask for, especially on the send/save path; propose it.
- Code stays local: no third-party services for source or diffs, and install or connect
  nothing unasked (`memory/constitution.md`, `context/context-scan.md`).
- Log the task with `scripts/ledger-append.sh` when it ends. Also log the work behind it:
  `outcome: accepted|edited|rejected` in the ledger Notes once the developer has looked at the result,
  `scripts/phase-log.sh` per phase (tokens, files read, why more context was needed) and
  `scripts/finding-log.sh` per finding, including anything a human, CI or another agent
  found that you did not - with the check that should have caught it.

## Token economy

- **No exploratory calls.** Every tool call has a stated purpose; don't probe whether a tool
  works. When locating things, get paths and line numbers back, not file contents; open only
  the range needed (offset/limit).
- Don't re-read a large diff or file already in context and unchanged. (If the person is
  editing the same files concurrently, re-reads are unavoidable — name that cost.)
- Filter large command output by keyword (`grep -i "fail\|error"`) or a tool's structured
  summary (e.g. `xcresulttool`), never blind `tail -N`/`head -N` — a `tail -200` once cut off
  the actual failure list and forced a costlier recovery.
- **Keep the rules a stable prefix.** This file, the constitution and the gate are the
  cacheable start of every request. Editing them mid-session invalidates the cache for
  everything after; make rule edits between sessions, and put task-specific material after
  them, not before.
- **Fresh session per distinct task.** Every turn resends the whole transcript, so cost
  compounds with session length. `session-state.md` and the logs make the handoff clean.
  Measured on one 8-day session: 60% of all calls fell on its first day (repeated fix rounds
  re-reading one large diff), and a narrow fresh-session review used about 2% of that day's
  cache reads (about 1% of the whole session's). Start each PR review in its own session.
- **Subagents and parallel passes multiply reading cost** — default to one pass. If you do
  split work: the cheapest capable model for triage and file listing, a mid-tier model for
  summaries and rule-compliance checks, the strongest only for bug-finding and for confirming
  a flagged bug. Give each agent only the diff and the rules it needs; ask for paths and
  conclusions back, not contents.

## Reviewing a diff

To get the base and head of a PR: `scripts/pr-range.sh <PR number | branch>`. Use `review/review-prompt.md` as the system prompt: one pass with a token-aware flow
(`scripts/diff-scope.sh` triage → diff-only candidate pass → targeted confirmation), not a
multi-agent roster. A re-review of an updated PR is incremental (only the commits since the
last reviewed head, plus re-confirming open findings). In a long session, delegate the
review to the read-only `forge-reviewer` subagent so the diff stays out of the main
context; its fresh context also serves as the independent pass for high-risk work.
It uses the same `memory/quality-gate.md` and `playbooks/` as generation, so a review finding
and a generation-time check are one standard. If "review" is ambiguous about which rubric
(this project's vs. a separate built-in review tool/skill), ask once before starting — a
real session lost most of a pass to the wrong rubric.

## Reporting on a batch of work

After several tasks/reviews, use `skills/session-report.md` for one consolidated report
instead of handing over each spec/log file.

## Rule maintenance (occasionally, not every session)

- A `constitution.md`, `quality-gate.md`, `playbooks/*.md` or `skills/*.md` rule unverified
  for a long stretch gets flagged for re-verification, not trusted indefinitely.
- Every rule costs tokens each time it is loaded. A rule or playbook entry that hasn't
  fired in a long stretch, or keeps being silently overridden, is a candidate for removal —
  this file and its skills should shrink as often as they grow.
- A bug shape that shows up a second time in real use gets a Seen/Action entry in the
  relevant `playbooks/<stack>.md` — grown from actual mistakes, never anticipated ones.
- Claims about savings or recall are measured with `evals/README.md`, not estimated; a rule
  that changes no result over about ten runs is a pruning candidate.
- While dogfooding: after a real task, add one entry to `logs/test-runs.md` — what worked,
  what broke, one thing to fix.
