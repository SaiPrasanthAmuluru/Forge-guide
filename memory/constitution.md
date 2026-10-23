# Constitution

Non-negotiable and default principles for this project. Every rule carries a tier and a
`last-verified` date. Rules unverified past ~90 days should be re-checked against the
current codebase before being trusted, not assumed still true.

Tiers:
- **HARD** - never violated, no exceptions, no silent override.
- **DEFAULT** - followed unless current repo context clearly disagrees; agent must say so
  if overriding.
- **SUGGESTED** - style preference, applied when convenient, skip without comment.

---

## Security [HARD] - last-verified: <date>

- Never hardcode secrets, API keys, or tokens in source. Use existing config/secrets
  pattern already present in the repo.
- Never log PII (names, emails, tokens, session identifiers) even at debug level.
- Never send source code, diffs or repository contents to a third-party service (hosted
  embeddings, hosted vector databases, remote analyzers, paste sites) that the developer
  has not approved for this project. Install no tools and connect no services unasked.
- Never bypass an existing auth, keychain, or centralized data-access pattern to take a
  shortcut - extend it or flag that it needs extending.

## Spec discipline [HARD] - last-verified: <date>

- No implementation code without an accompanying `spec.md` for the feature/fix, unless the
  change is a one-line trivial fix explicitly marked as such by the human.
- All `[NEEDS CLARIFICATION]` markers must be resolved before task breakdown begins.

## Developer control [HARD] - last-verified: <date>

- The developer owns the code. Change only the files and lines the spec names; if the work
  needs another file, ask first. No unrequested refactor, rename, reformat, dependency or
  pattern migration, and no cleanup of untouched code.
- Never commit, push, merge or open a PR unless asked to.
- Never claim more certainty than the context supports: say what was read, what was not,
  and what is assumed.

## Fit the code as it is today [DEFAULT] - last-verified: <date>

- Solve the task in the shape the codebase has now: its layering, naming, helper families,
  error handling, tests and formatting. Smallest diff that is correct and complete. Code the
  author would recognise as their own team's.
- Most work depends on today's structure, not on a cleaner one that does not exist yet. The
  best change *here* is the one that works with current callers, so a better design that needs
  a wider refactor is not a reason to widen the change.
- If you see a materially better design, deliver the fit-today change anyway and add one
  short note (spec section "Beyond this change"): what would be better as a whole, why it is
  not done now (name the consumers or tasks that depend on the current state), and roughly
  how large it is. The developer decides; do not argue for it, repeat it, or put it in the code.

## Code quality [DEFAULT] - last-verified: <date>

- Prefer O(n) over worse; use Set/Dictionary for lookups over nested loops.
- No sentinel values; handle edge cases explicitly.
- Add doc comments to new public functions/types.
- Favor targeted edits over full-file regeneration.
- Use the repo's own helper family (e.g. `isNil`/`isNotNil`/`isNotBlank`) wherever it has
  one. Before writing a nil/empty check, grep the helper file for the family, not only the
  helper named in AGENTS.md. Seen twice in real review.

## Token economy [DEFAULT] - last-verified: <date>

- Clarifying questions: one batched round, menu-style options where possible, not serial
  freeform back-and-forth.
- Reference code by file:line instead of pasting full files into context when possible.
- Log every spec-gated task's rough token cost in `logs/token-ledger.md`.

## Style [SUGGESTED] - last-verified: <date>

- (Project-specific formatting/naming preferences go here - keep this section short;
  anything that would cause real mistakes if removed belongs in DEFAULT or HARD instead.)
