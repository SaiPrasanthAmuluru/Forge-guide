# Forge-guide

> Forge code with intention. Guide it with review.

A lean, token-conscious spec-driven workflow for AI coding agents - forges code from a
gated spec, then guides it through a strict, single-pass review before it ships.

Built on the Spec-Driven Development (SDD) idea, and grown from real review and generation incidents rather than theory. It is plain Markdown
plus dependency-free shell scripts: it works with any AI coding agent, any language and any
Git host.

## How to use it

Clone it once, anywhere (for example `~/Tools/Forge-guide`). You never copy it into your
project. Your agent reads the rules from the clone; the scripts run from inside your
project and use that project's git. Only needs `git` and `bash`.

**Make your agent see the toolkit.** Most agents have a way to read files outside the
project (an extra directory, a workspace folder, or simply the absolute path). Then start
the session in your *project* and give the agent its entry file:

> Read `<path>/Forge-guide/AGENTS.md` and follow it for this session.

Agents that auto-load `AGENTS.md` or `CLAUDE.md` from the working directory can instead
use a copy or symlink of that one file in the project root.

**To review a PR or a commit range**

1. In your project: `<path>/Forge-guide/scripts/pr-range.sh <PR number | PR URL | branch>`
   prints the base and head commits.
2. Open a *fresh* agent session (a fresh context is what makes the review independent) and say:
   > Use `<path>/Forge-guide/review/review-prompt.md` as the rubric. Base `<sha>`, head
   > `<sha>`. Mode: standard. PR description: ...
3. You get graded findings (CRITICAL to NIT), a mechanical verdict and a list of checks run.
   Post it on the PR yourself, or automate that with your own CI job.

**To review your own changes before committing** (nothing needs to be committed or pushed)

1. In your project: `<path>/Forge-guide/scripts/local-changes.sh` lists what is there (staged,
   unstaged and new files, plus any unpushed commits) and the commands to use.
2. Open a fresh agent session and say:
   > Use `<path>/Forge-guide/review/review-prompt.md` to review my uncommitted local changes.
   > Mode: standard.
3. It reads the working tree against `HEAD` and changes nothing: no staging, commits or stashes.

**To generate code**

1. In your project, say:
   > Follow `<path>/Forge-guide/AGENTS.md`. Task: <what you want>.
2. The agent builds a map of your codebase once (`skills/build-context.md`), writes a short
   spec, runs the impact and reuse scans, asks its questions in one batch, then codes and
   checks its own work against the same gate the reviewer uses.

**Choosing a depth:** set `Mode: strict | standard | fast` in your request. It changes how
much is searched and re-checked, never the severities or the verdict.

**Where your project's state goes:** `<project>/.forge/` (specs, logs, session state).
Add `.forge/` to `.git/info/exclude` if you do not want it committed.

Paste-ready prompts for any agent are in `adapters/generic/prompts.md`. Tool-specific extras
(a packaged reviewer subagent, an optional hook) live under `adapters/` and are never required.

## Principles for the developer's trust

- **Your code, your call.** The agent changes only what the spec names, matches the style and
  structure already in the repo, and never commits, pushes or opens a PR unless asked.
- **Best for today, honest about tomorrow.** Most tasks depend on the current state of the
  code, so the change fits it. If a whole-codebase refactor would be better, the agent says
  so once, in a short "Beyond this change" note, and leaves the decision to you.
- **Full context before code, shown at handoff.** Every handoff states what was read, what
  was not verified, what was left untouched and how to check it.
- **Reviews follow the same rule.** A review does not demand a restructure; it can mention
  one as an observation that does not affect the verdict.

## Why this exists

Spec-driven workflows usually aim at **consistency**: the agent should not contradict itself
or invent scope. Forge-guide also covers what they tend to leave out: keeping **cost** down
and measured, **verifying** afterwards that the implementation satisfies the spec, checking
that generated code does not **duplicate or break** something that already exists, and
handling **rule staleness** as a codebase evolves. It does this without heavy ceremony.

## The pillars

1. **Spec-gate** - no code is generated until a spec exists and open questions are resolved.
2. **Lean ceremony** - `spec.md` + `tasks.md` only. No separate `plan.md` layer unless a
   task genuinely needs one.
3. **Token economy** - clarifying questions are batched and selectable (menu-style, not
   freeform back-and-forth); every session logs an entry in `logs/token-ledger.md`.
4. **Trust tiers** - every constitution/skill rule is tagged `HARD`/`DEFAULT`/`SUGGESTED`.
   Nothing is flat-priority.
5. **Staleness / drift detection** - rules carry a `last-verified` date and get re-checked
   against the live codebase, not trusted indefinitely.
6. **Verification loop** - implementation is checked against acceptance criteria, not just
   "did it compile" - and re-checked after every round of edits, not only the first.
7. **Security hygiene** - a standing HARD-tier check: no hardcoded secrets, no PII in logs,
   no bypassing established auth/keychain patterns.
8. **Session-state handoff** - a short, structured "where I left off," not a transcript.
9. **Context-first generation** - before writing anything, scan what already exists in the
   area being touched: existing utilities/extensions, established patterns, centralized
   entry points to reuse instead of duplicating. Also checks whether the problem is already
   solved before generating a redundant fix.
10. **Impact / blast-radius analysis** - before task breakdown, trace every consumer/call-
    site a change touches - the class of bug ("this hook is reused for something else
    elsewhere") that a diff-only read never catches.
11. **Ultra-strict quality gate, scoped by a ratchet** - CRITICAL/HIGH findings always
    block; the gate applies to new/changed code only, not an entire legacy file, so it's
    adoptable on a real existing codebase instead of failing everything on day one.
12. **Playbooks, not just principles** - known-better-patterns grounded in real incidents
    (Seen → Action), shared verbatim between generation and review so the two standards
    never drift apart. Multi-stack from the start via `playbooks/_template.md` - but a new
    stack playbook starts empty and grows only from real incidents, never invented ones.
13. **Agent- and language-agnostic** - `AGENTS.md` (the open convention read by many agent
    tools) is the single entry point; `CLAUDE.md` just imports it for tools that look for
    that name. Rules, playbooks and scripts are plain files with no tool-specific
    dependency; stack lessons are per-language playbooks. Both entry files stay short on purpose - evidence shows bloated or
    LLM-expanded instruction files hurt agent performance and inflate cost rather than
    helping.
14. **Platform / language currency check** - every ecosystem has its
    own deprecation lifecycle, checked against the project's own declared minimum target,
    preferring existing ecosystem tooling over reasoning from memory on a fast-moving
    surface.
15. **Cached base context, refreshed only when it moves** - general "what already exists
    in this codebase" knowledge (extensions, patterns, conventions) is captured once
    against a specific commit and reused until `main` actually moves, instead of being
    re-derived from scratch on every task. Diff-specific checks (cross-call-site, verify-
    before-asserting) always still run live - only the general, stable knowledge is
    cached.

16. **Lean rule loading + check-depth modes** - rules are loaded by need, not by default:
    a ~2K-token core gate always, playbook entries one-by-one via `scripts/playbook.sh`,
    rationale files only on demand. A `Mode: strict | standard | fast` line sets how much is
    searched and re-checked without ever changing severities or the verdict. Reviews run
    triage → diff-only candidate pass → targeted confirmation instead of reading context up
    front, and a re-review of an updated PR covers only the commits since the last reviewed
    head. The token ledger records real token deltas so cost drift is visible.

## Token budget

Rules loaded before any work starts, estimated at ~4 bytes per token:

| | Before (estimate) | After (estimate) |
|---|---|---|
| Generation task (entry file + constitution + gate + 1 skill + playbook + context-scan) | ~17.7K | ~12.5K with the playbook index, 3 matching entries, `flow-brief.md` (~1.5K) and the codebase map (~2.5K when built) - about -29%; the map is the deliberate cost of not generating blind |
| Review (entry file + constitution + gate + review prompt + playbook) | ~18.4K | ~9.5K with the index and 3 matching entries (about -48%) |

Biggest single item: the playbook was ~8.4K tokens read whole; its index is ~0.85K and each
entry ~0.25K, so a task touching three domains pays ~1.6K. These are file-size estimates,
not measured session totals - `logs/token-ledger.md` is where the real numbers go, and
`evals/` is the protocol for turning them into a with/without comparison (tokens per task,
recall on known issues, false positives).

## Layout

```
Forge-guide/
├── AGENTS.md                 # the single entry point for any agent
├── CLAUDE.md                 # imports AGENTS.md + a few Claude Code notes
├── memory/
│   ├── constitution.md       # tiered, dated, non-negotiable-vs-suggested rules
│   ├── quality-gate.md       # CORE rulebook (~2K tokens): severity, gate, modes, mandatory checks
│   └── quality-gate-detail.md # rationale + incidents; read one section on demand, never at start
├── playbooks/
│   ├── ios-swift.md          # example stack playbook: Seen/Action entries from real incidents
│   └── _template.md          # format + rules for adding a new stack playbook honestly
├── context/
│   ├── context-scan.md       # already-exists / already-fixed checks + snapshot caching logic
│   ├── base-snapshot.md      # the codebase map: read in full first, every generation task (project-specific)
│   ├── flow-brief.md         # generation: map the existing flow, one batched question round, stop-and-ask triggers
│   └── risk-paths.txt        # regexes marking a changed file HIGH risk (edit for your codebase)
├── review/
│   ├── review-prompt.md      # single-pass review harness, references quality-gate + playbooks
│   └── regressions.md        # past review misses as replayable cases; replayed only when the rubric changes
├── evals/
│   ├── README.md             # A/B protocol: tokens per task, recall, false positives (measure, do not estimate)
│   └── results.md            # results table template
├── skills/
│   ├── new-feature.md        # context-scan → clarify → impact-analysis → build → verify
│   ├── bug-fix.md            # already-fixed check → sibling-instance/downstream checks
│   ├── refactor.md           # context-scan IS the impact analysis for a refactor
│   ├── api-integration.md    # existing-integration scan + provider currency check
│   └── spec-builder.md       # drafts spec.md from a ticket/PRD/design/API doc
├── specs/
│   └── template/
│       ├── spec.md           # includes impact/blast-radius, gaps, interface mapping
│       ├── tasks.md
│       └── verification.md
├── session-state.md
├── logs/
│   ├── token-ledger.md
│   └── suppressions.md       # audit trail for waived MEDIUM findings
├── scripts/
│   ├── pr-range.sh           # PR number or branch -> exact base/head commits, no checkout
│   ├── neutrality-check.sh   # fails if a core file names a specific agent or stack (those belong in adapters/ and playbooks/)
│   ├── local-changes.sh      # what is uncommitted/unpushed in this checkout, and the commands to review it
│   ├── map-probe.sh          # stack-neutral fact sheet (shape, scope, tests, gates) used to build the map
│   ├── xref.sh               # dependency-free call-site finder for the cross-call-site check
│   ├── impact.sh             # consumers of every declaration you change/remove, flagged when in untouched files
│   ├── reuse-scan.sh         # existing extensions/helpers: find before writing, flag re-implementation after
│   ├── probes/swift.sh       # optional stack extras; add probes/<stack>.sh for others
│   ├── pr-gate.sh            # optional hook: stops the agent opening PRs itself (the developer decides)
│   ├── ledger-append.sh      # one-command token-ledger row (per task)
│   ├── phase-log.sh          # tokens, files read and cause per phase (map/flow/scans/generate/review/rework)
│   ├── finding-log.sh        # one row per finding: who found it, status, which check should have
│   ├── report-metrics.sh     # reads the three ledgers: tokens by type/phase, escapes, precision, playbook hits
│   ├── playbook.sh           # index / show <ID> / find <kw> - read playbook entries, not the file
│   ├── diff-scope.sh         # review pre-filter: read order, skips, budget - from numstat only
│   ├── review-prep.sh        # one command for review prep: triage + impact + reuse + playbook index, run together
│   ├── verdict-check.sh      # fails when a review verdict is softer than its findings (gate arithmetic)
│   ├── drift-check.sh
│   ├── verify-spec.sh
│   ├── check-context-freshness.sh  # cheap staleness check for base-snapshot.md
│   └── refresh-context.sh          # shows what changed since the last snapshot
└── adapters/                 # optional, tool-specific wiring; the rules never depend on it
    ├── generic/prompts.md    # paste-ready prompts: review a PR, review local changes, generate, report
    ├── ci/                   # PR review in CI on GitHub, Azure DevOps, GitLab, Bitbucket (any agent)
    ├── github-actions/       # alternative GitHub template that uses a vendor action
    └── claude-code/          # reviewer subagent, PR-blocking hook and skill wrappers for Claude Code
```

## Context before code: map, then flow, then questions

Forge-guide is for any project in any language. Before writing or changing code the agent
reads the overall codebase map (`context/base-snapshot.md`, capped ~2.5K tokens): what the
project is, how big it is and where work happens, how it is structured and which layers it
uses, where shared helpers and shared processes live, entry points, and how it is tested
and gated. Then it maps the flow of the area, then asks, then codes.

`scripts/map-probe.sh` gathers the facts for any repository as paths, names and counts
only (languages and size, manifests, docs, files per directory, layer-named directories,
entry points, tests and how they run, CI and coverage gates, recent churn, largest files),
so building the map costs a handful of targeted reads; the developer confirms the uncertain
rows once (`skills/build-context.md`). Stack extras are optional plugins in
`scripts/probes/<stack>.sh` (Swift is included as an example); stack lessons live in
`playbooks/<stack>.md`. The spec records `Map consulted`, and `verify-spec.sh` fails while
that is still a placeholder. The map describes one project, so it lives in that project's
repo, not in the shared toolkit.

## Tools: local only, nothing to install

Forge-guide runs on the agent's own search plus two dependency-free scripts (`map-probe.sh`
for the map, `xref.sh` for call sites). A local language-server or IDE reference tool is
used when the session already has one, because it is exact; nothing is installed unasked.
Source and diffs are never sent to a third-party service (hosted embeddings, vector
databases, remote analyzers) unless the developer approves that service for the project -
this is a HARD rule in the constitution, because many teams cannot allow it.

## Flow understanding before code

The generation skills used to ask generic questions (consumer, data shape...) and miss
assumptions about the flow itself. `context/flow-brief.md` makes them map entry points, the
current flow with `file:line`, ownership and boundaries first, sort unknowns into
answerable-from-code / needs-a-human / safe-to-assume, and ask once. The spec template has
matching "Flow & understanding" and "Assumptions" sections. The independent pass before a PR
is recorded in a `verification.md` checkbox that `verify-spec.sh` checks. Review misses are
kept as cases in `review/regressions.md` (R-10, a request id in a log, has no check yet).

## Impact and reuse scans (the two context-building checks)

Two local, read-only scripts turn "check the impact on existing flows" and "check whether
a helper already exists" into steps with output, so they are not skipped under pressure.

- `scripts/impact.sh --symbols a b c` before coding, `scripts/impact.sh <base> [head]` on the
  finished diff: for each changed or removed declaration (including the function or
  property enclosing a changed line, and the enum when a case is added), its consumers,
  how many are in files the change did not touch, and which areas they belong to. Each such
  area needs a decision in the spec's Impact table.
- `scripts/reuse-scan.sh --need "optional nil blank trim"` before writing; `scripts/reuse-scan.sh
  <base> [head]` after: lists existing extension members and `*Helper`/`*Utils` functions with
  how often the codebase already uses them, and flags added lines that repeat a helper's body,
  use a raw `== nil` where `isNil` exists, or declare a name close to an existing helper's.
- Both are text heuristics (word-boundary search, tuned on Swift and generic on other languages). They produce candidates, not
  verdicts; a language-server reference tool is exact if the session has one. `verify-spec.sh`
  fails while the spec's `Impact scan` and `Reuse scan` lines are still placeholders.

## Using the toolkit from outside your project

Keep one clone of this repo (say `~/Tools/Forge-guide`), set `export FORGE_HOME=~/Tools/Forge-guide`
in your shell profile (the reviewer subagent reads it to find the rules), and start your agent from the
*project*, with the toolkit readable as a reference (an extra directory, a workspace folder,
or by absolute path). Scripts run by absolute path from inside the project and use that
project's git.

- **State stays in the project:** `.forge/specs/`, `.forge/logs/`, `.forge/session-state.md`.
  `scripts/ledger-append.sh` creates `.forge/logs/token-ledger.md` on first use. Add `.forge/`
  to the project's `.git/info/exclude` if you do not want it committed.
- **Pull requests are your decision.** The rules already say an agent never commits, pushes or
  opens a PR unless you ask. `scripts/pr-gate.sh` is an optional hook that enforces it: it
  blocks `gh pr create` / `az repos pr create` when an agent runs them. Say yes for a session
  with `FORGE_ALLOW_PR=on`, or run the command yourself. It needs an agent that can run a
  command before its shell calls; the Claude Code wiring is in `adapters/claude-code/`.
  The independent-pass line in `verification.md` is your record that a fresh review happened;
  `verify-spec.sh` still checks it, but nothing forces a PR.
- **A reviewer in its own context** is what makes the pass independent. Any agent can do this
  as a fresh session pointed at `review/review-prompt.md` (prompts in `adapters/generic/`). Tools
  with subagents can package it; Claude Code's is in `adapters/claude-code/`.

## Reviewing local changes (before you commit)

`scripts/local-changes.sh` shows the uncommitted state and the exact commands. `scripts/diff-scope.sh
--local` triages staged, unstaged and new files against `HEAD`; `scripts/impact.sh HEAD` and
`scripts/reuse-scan.sh HEAD` do the impact and reuse scans on the same set, including files git does
not track yet. The reviewer reads diffs with `git diff HEAD -- <file>` and new files directly, never
stages or edits anything, and labels the result `Reviewed: local changes on <branch> @ <sha>
(uncommitted)`. Commits not pushed yet are reviewed with `diff-scope.sh <upstream> HEAD`. The
rubric, gate and verdict are identical to a PR review.

## Reviewing a PR (Azure DevOps, GitHub or plain branches)

1. In the project's checkout run `scripts/pr-range.sh <PR number>` (or `<source-branch>
   [target-branch]`). It fetches only into private `refs/forge/*` refs, leaves your working
   tree alone, and prints the base and head commits, their subjects (so a swap is obvious),
   the size of the change, and the next commands. Number lookups try the PR merge ref
   (`refs/pull/<n>/merge`), then `az repos pr show` (Azure DevOps) or `gh pr view`
   (GitHub).
2. Run `scripts/diff-scope.sh <base> <head>` for the cheap triage (what to read first, what
   to skip, which files need a checker).
3. Open a fresh agent session and say "Use review/review-prompt.md as the review rubric;
   base <sha>, head <sha>; Mode: standard; PR description: ...". A fresh context is what
   makes it an independent pass. (Tools with subagents can use a packaged reviewer from `adapters/`.)
4. The result is Markdown with a `Reviewed: ... | Pass: ... | Coverage: ...` header, graded
   findings, a mechanical verdict and a Checks-run block. Post it as a PR comment yourself;
   nothing is posted automatically. After new pushes, run step 1 again and say
   "incremental, last reviewed head <old sha>" so only the new commits are read.
5. Clean up the private refs when you like:
   `git for-each-ref --format='%(refname)' refs/forge | xargs -n1 git update-ref -d`.

   Troubleshooting: `pr-range.sh` also accepts a PR URL. If it says `git does not run` (for example
   "Bad CPU type in executable" from a stale Intel-only `/usr/local/bin/git` on Apple Silicon), put a
   working git first: `PATH=/usr/bin:$PATH scripts/pr-range.sh <PR>`.

Tested against local and bare-remote repositories, not against a live Azure DevOps server;
the merge-ref parent order on Azure DevOps is assumed to match GitHub, which is why the
script prints both subjects.

## Adapters (optional)

`adapters/ci/` has templates that post an automatic review comment on every PR on GitHub, Azure
DevOps, GitLab or Bitbucket, using `scripts/ci-review.sh` and whichever agent you set in
`FORGE_AGENT_CMD` (setup in its README; the runner is tested against mock servers, the templates
not yet on live hosts). `adapters/github-actions/` is an alternative GitHub-only template. This repo's own
`.github/workflows/checks.yml` runs plain checks on every push and PR: script syntax, executable
bits, the neutrality check and the dash check. No secrets involved.

`adapters/generic/prompts.md` has paste-ready prompts that work in any agent. `adapters/claude-code/`
holds a read-only reviewer subagent and a hook that stops an agent opening PRs by itself. Add one
for another tool by wiring only: where it reads instructions (point it at `AGENTS.md`), how it
starts a separate reviewer context, how it limits tools. Before a PR, record the review in the
"Independent pass" line of the spec's `verification.md`.

## Flow

1. Copy `specs/template/` to `specs/00X-feature-name/`, or draft it from a source via
   `skills/spec-builder.md`.
2. Context-scan the area being touched (Step 0 of the relevant skill) before asking
   anything - surface what already exists, fold findings into the clarification round.
3. Map the flow (`context/flow-brief.md`), then resolve every `[NEEDS CLARIFICATION]`
   marker in one batched round: "my understanding" to confirm, the relevant flow questions,
   then the assumptions being proceeded on. Stop and ask again mid-work if the code
   contradicts the flow map or a step has two readings.
4. If the change touches a shared contract, run the cross-call-site impact analysis before
   writing `tasks.md`.
5. Implement task-by-task, checking the relevant `playbooks/<stack>.md` for the domain
   being touched, referencing existing code by file:line.
6. After each task, check acceptance criteria and run the applicable `memory/quality-gate.md`
   checks - the gate applies at generation time too, not only at review.
7. For review, `review/review-prompt.md` runs the same checklist against the same
   quality-gate and playbooks - one standard, checked twice.
8. Log the round in `logs/token-ledger.md` and update `session-state.md`.

## What this is not

It has no CLI, no config generation and no tool-by-tool compatibility matrix. It is a small, open toolkit of rules and
scripts for solo developers and small teams; it never sends your code to any service.

## Licence and names

MIT licensed (see `LICENSE`). Product and company names that appear (Git hosts, build tools,
agent tools, platform vendors) are used only to say what the scripts and rules work with;
no affiliation or endorsement is implied. Playbook entries describe patterns in original
wording, with illustrative identifiers rather than any employer's code. Contributions must
not include proprietary code, internal names or text copied from other projects.

## Known environment gotchas

- **Keep the working repo out of synced or sandboxed folders** (for example `~/Downloads`,
  `~/Desktop` or cloud-synced directories). Some operating systems block command-line reads
  there even after a grant (seen on macOS). Use a plain local path like `~/Projects/`.
- **Scripts need Bash 3.2+ and POSIX tools** (macOS and Linux work; on Windows use WSL or
  Git Bash). If `git` itself fails to run, put a working one first on `PATH`.
