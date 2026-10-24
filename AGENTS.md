# AGENTS.md

Mode: strict

<!-- strict | standard | fast - see `memory/quality-gate.md` "Check depth mode". -->

Single entry point for any agent (the open `AGENTS.md` convention). `CLAUDE.md` only imports
this file for tools that look for that name, so there is one copy to maintain. Tool-specific
extras live under `adapters/`; the rules here assume only that the agent can read files, and
that it can run shell commands (if it cannot, ask the developer to run a script and paste the
output, or use plain `git diff` and text search). Kept short on
purpose: a bloated instruction file hurts performance and inflates cost; detail lives in the
linked files (`memory/`, `playbooks/`, `skills/`, `review/`), loaded only when needed.

## Load order (the token budget)

Always, once per session: this file, `memory/constitution.md`, `memory/quality-gate.md`
(core only). `HARD` rules and CRITICAL/HIGH gate findings are non-negotiable.

Only when the task needs it: one skill file for the task type; `context/flow-brief.md` for
generation tasks (flow map, questions, stop-and-ask); playbook entries via
`scripts/playbook.sh stacks`, then `index <stack>` for the project's language, then `show <ID>`
(never the whole file; if no playbook matches the project's language, skip playbooks rather than
reading another stack's);
one section of `memory/quality-gate-detail.md` when applying a check in depth;
`review/review-prompt.md` for reviews; `skills/build-context.md` to build the codebase map;
`skills/session-report.md` for reports.

## Before writing any code

1. Check `specs/` for an active spec. None, and a source (ticket/PRD/design/API doc) exists
   → `skills/spec-builder.md`; otherwise start one from `specs/template/`.
2. Read the overall codebase map first, in full: `context/base-snapshot.md` (purpose and scope,
   structure, where shared helpers and processes live, entry points, test and CI gates;
   capped ~2.5K tokens). `scripts/check-context-freshness.sh`: current (or behind but untouched in the paths it
   cites) -> use, no refresh; stale -> refresh the affected rows. Read it once per session;
   reuse a valid `context/areas/<area>.md` flow note; missing or template -> `skills/build-context.md`. Never write code without
   the map. Then run the matching skill's Step 0 scan for the area, and record `Map
   consulted` in the spec. Order: map -> flow -> questions -> code.
3. Map the flow the change plugs into and turn what is unclear into questions
   (`context/flow-brief.md`): read what code can answer, then ask in ONE batched round -
   "my understanding" to confirm, the relevant flow questions, the assumptions. Resolve
   every `[NEEDS CLARIFICATION]` marker there, not serially. Stop and ask again mid-work if
   the code contradicts the flow map or a step has two readings. For every new type, file, parameter or flag, fill the spec's "Decisions & why" (reader, existing mechanism, why not derive it, honest scope); it becomes the PR description.
4. Pick the one matching skill file - read only that one.
5. If the change touches a shared contract, run the cross-call-site impact analysis before
   task breakdown (mandatory - `memory/quality-gate.md`; `scripts/xref.sh` or a local reference tool).
   For every declaration you change or remove, run `scripts/impact.sh --symbols <names>`; before
   writing a helper, `scripts/reuse-scan.sh --need "<words>"`; re-run both on your diff afterwards.

## While writing code

- Targeted edits over full-file rewrites; reference code by file:line.
- Tiers: HARD never bends; DEFAULT bends only with a stated reason; SUGGESTED is optional.
- Pull the matching playbook entries before writing in a domain one covers.
- After fixing one instance of a bug shape, check the diff for the same shape elsewhere.
- A merge isn't done when conflict markers are gone: run the post-merge
  signature-compatibility check on every changed type/method across every touched file,
  conflicted or not; if generated or structural project files (manifests, lockfiles) are
  touched, run a structural check for stale references regardless of conflicts (the stack
  playbook names the checker).

## After writing code

1. Check the diff against every acceptance criterion in `spec.md`, explicitly.
2. Run the applicable `memory/quality-gate.md` checks, scoped to new/changed code (ratchet).
3. Re-run `scripts/impact.sh <base>` and `scripts/reuse-scan.sh <base>` on your own diff and put
   anything new into the spec.
4. Offer the independent pass (a fresh-context reviewer or a human, not the context that wrote
   the change) at the depth the Mode sets, and record it in `verification.md`
   (`scripts/verify-spec.sh` fails until it is). A same-context review is an "author pass, not
   independent" and can't approve. Whether to open a PR is the developer's call: never create
   one yourself; say the change is ready for review and stop.
5. Keep the developer in control (`memory/constitution.md`: Developer control, Fit the code as
   it is today): change only what the spec names, match the existing code, never commit or
   push unasked, and finish with a short handoff - files changed, what was left untouched,
   what was read vs not verified, how to check it, and at most one "Beyond this change" note.
6. Update `session-state.md` briefly and log the task now (see Working agreement).

## Token economy

No exploratory tool calls - every call has a purpose; get paths and line numbers back, not
file contents; open only the range needed. Don't re-read unchanged content already in
context. Filter large output by keyword or a tool's structured summary, never blind
`tail`/`head`. Keep this file, the constitution and the gate unedited within a session
(they are the cacheable prefix). Fresh session per distinct task - every turn resends the
transcript. Parallel/sub-agents multiply reading cost: default to one pass; if splitting,
cheapest capable model for triage/listing, strongest only for bug-finding and confirming a
flagged bug, and ask for paths and conclusions back.

## Reviewing a diff

Use `review/review-prompt.md` for a PR, a commit range, unpushed commits or uncommitted local
changes (`scripts/local-changes.sh` shows what exists; `diff-scope.sh --local` triages it; nothing
is staged or changed): one pass with a token-aware flow (`scripts/diff-scope.sh`
triage → diff-only candidate pass → targeted confirmation), same gate and playbooks as
generation. Re-reviews of an updated PR are incremental (commits since the last reviewed
head, plus re-confirming open findings). Where subagents exist, run the review in a
read-only reviewer with its own context (a fresh session, or a packaged subagent from `adapters/`). If "review"
is ambiguous about which rubric, ask once before starting.

## Reporting on a batch of work

Use `skills/session-report.md` for one consolidated report after several tasks/reviews.

## Maintenance

Rules unverified for a long stretch get re-verified. Every rule costs tokens each time it
loads, so rules and playbook entries that go unused or get overridden repeatedly are
candidates for removal. New recurring bug shapes get a Seen/Action entry in the relevant
`playbooks/<stack>.md` (`playbooks/_template.md`) - only after they actually happen. While
dogfooding, log one entry in `logs/test-runs.md` per real task. Savings or recall claims are
measured with `evals/README.md`, not estimated. Before changing a core file, keep it
agent- and stack-neutral: `scripts/neutrality-check.sh` fails if it names one (tool-specific
wiring belongs in `adapters/`, stack lessons in `playbooks/<stack>.md`).

**Where state lives.** When the toolkit is the project, `specs/`, `logs/` and `session-state.md`
sit beside this file; when it is kept outside the project, they live in the project under
`.forge/`. Templates, playbooks, scripts and skills are always read from the toolkit. Paths in these files
are relative to the toolkit root; when it is kept outside the project, `FORGE_HOME` names it
(`export FORGE_HOME=~/Apps/Forge-guide`) and scripts are run by absolute path.

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
