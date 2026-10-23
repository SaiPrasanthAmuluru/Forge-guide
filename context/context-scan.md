# Context scan

The concrete mechanics behind "check what already exists before generating anything" -
referenced from `memory/quality-gate.md`'s mandatory checks and `skills/new-feature.md`'s
Step 0.

## What happens when (intervals, not every task)

| Cadence | What | Cost |
|---|---|---|
| Rarely, when the check says STALE | Rebuild or refresh the map rows whose cited paths changed (`refresh-context.sh`, `skills/build-context.md`) | A few targeted reads |
| Once per session | Read the map (and `quality-gate` core, constitution) | ~2.5K tokens |
| Per task | `check-context-freshness.sh` (one git call), the area note if valid, the flow brief for what is new, live cross-call-site check | Small |

Staleness is relevance-based: the base branch moving is normal and does not by itself
invalidate anything. A cached file is stale only if a path it cites changed
(`check-context-freshness.sh`), or the base is more than `FORGE_MAX_BEHIND` commits ahead
(default 60), so an active repo is not refreshed on every task.

## Read the map first (once per session, before the first generation task)

`context/base-snapshot.md` is the overall codebase map (purpose and scope, structure, where shared helpers
live, entry points, shared processes, test and CI facts). A generation task reads it **in
full before anything else** - it is capped to be cheap - and then maps the flow of the
specific area (`context/flow-brief.md`), then asks. Order: **map -> flow -> questions ->
code.** The spec records which rows were used (`Map consulted:`), so "I didn't know that
helper/process/gate existed" can't happen silently.

## Check the cached snapshot first, before scanning live

`context/base-snapshot.md` holds the general "what already exists in this codebase"
answer - extensions, established patterns, naming conventions - captured once against a
specific commit of `base_ref` (`origin/main`), not re-derived from scratch on every task.
Re-scanning the whole codebase fresh every single time a task starts is exactly the kind
of repeated, avoidable cost the token-economy pillar exists to cut, when the codebase
hasn't actually moved since the last time this was done.

Before doing a live already-exists/already-fixed search:

1. Run `./scripts/check-context-freshness.sh`. It's one cheap `git rev-parse` and
   comparison, not a scan - it tells you whether the snapshot still matches `base_ref`'s
   current commit.
2. **Current** → use the snapshot directly for the general "does something like this
   already exist" question. Only fall back to a live grep if the snapshot genuinely
   doesn't cover the specific area being touched in enough detail - the snapshot is a
   cache, not a promise of completeness for everything.
3. **Stale** → don't silently trust it, and don't reflexively do a full re-scan either.
   Run `./scripts/refresh-context.sh` to see exactly what changed since the snapshot was
   taken, and only re-check the snapshot sections that overlap with what actually
   changed. Update `snapshot_commit`/`captured_at`/the Build log once done.
4. **No snapshot exists** (or it is still the template) → build it with
   `skills/build-context.md` (a bounded probe, not a full scan) and have the developer
   confirm the uncertain rows, then continue. Every task after this one reuses it until
   `base_ref` moves. Never generate code while the map is missing: that is "blind" mode.

Git checks run against the project (`FORGE_PROJECT`, else the current directory's git
toplevel), not the folder that holds the toolkit.

Whether to treat "stale" as auto-refresh-and-continue or as a prompt back to the person
("context is N commits behind main - refresh now, or proceed against the cached snapshot
knowing anything changed since won't be reflected?") depends on how far behind it is and
how central the area being touched is - a snapshot one commit behind on an unrelated part
of the codebase is fine to proceed with; ask when unsure rather than guessing either way.

**This caching applies to the general codebase-knowledge questions only.** The
cross-call-site check (who else calls the exact symbol this diff/fix touches) and
verify-before-asserting (confirming a specific claim about current code) always run live
against current state, regardless of snapshot freshness - a stale answer to "who calls
this" is actively dangerous, not just wasteful, since a very recent caller could be
missed entirely. Don't let a fresh-looking snapshot substitute for these.

## Context tools: local only, no new dependencies

Order of preference for finding things: (1) the agent's own search (Glob / Grep / Read,
or an Explore-style subagent for broad sweeps) - the default and enough for most work;
(2) a local symbol or reference tool (language-server or IDE backed, a tree-sitter outline)
only if the session already has one - use it for "who references this" and symbol
outlines, since it is exact where text search is approximate; (3) `scripts/map-probe.sh`
and `scripts/xref.sh`, which need nothing installed. Rules:
- Source code, diffs and file contents stay on the developer's machine and the model
  provider already in use. Do not send them to any other service (hosted embedding APIs,
  hosted vector databases, remote analyzers) unless the developer approved that specific
  service for this project.
- Do not install tools or connect services unasked; suggest, then wait.
- A tool's answer is evidence only for what it actually returned; state the method used.

## Already-exists check (duplication)

Search against the **pre-change baseline**, not the current working tree - the working
tree may already include this task's own in-progress additions, which would make a
duplicate look like it's "already there." For a git-based repo, that means diffing or
grepping against the base branch/commit the work started from, not `HEAD` mid-task.

Look specifically for:
- An existing extension/helper on a common type with equivalent semantics to what's about
  to be written (a new `isNotEmpty` when one already exists under a different name, a new
  `.firstOrNil(where:)` duplicating an existing pattern).
- An existing centralized entry point (coordinator/adapter/facade/manager) for this feature
  area - new code should call into it, not reimplement a parallel path.

## Already-fixed check (redundant work)

Before investigating a bug or building a feature from scratch, check whether it's already
solved:
- Recent commit history for messages referencing the same issue/ticket.
- Linked or recently-merged PRs referencing the same issue/ticket.
- If evidence is found, still read the actual current code to confirm the defect is
  genuinely gone before stopping - evidence of an attempt isn't the same as confirmation it
  worked. High confidence the defect is gone → stop, don't generate a redundant fix. Low
  confidence → proceed, but note what was found.

## What this is not

This isn't a full static-analysis pass over the whole codebase every time - it's a
targeted search scoped to the area the current task touches, sized to stay cheap, and
increasingly a cache lookup rather than a fresh scan at all once a snapshot exists. See
the token-economy pillar: the point is avoiding wasted generation, not performing an
exhaustive audit before every task.
