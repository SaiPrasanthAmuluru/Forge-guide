# Evals: measuring tokens and effectiveness

The toolkit's claims (fewer tokens, fewer missed issues) are only worth what they measure
to be. Until runs are recorded here, the numbers in the README are estimates (file sizes at
about 4 bytes per token), not results. This protocol turns them into results with a few
real tasks and the token counter you already have.

## What is measured

| Question | Measure | Where it comes from |
|----------|---------|---------------------|
| Does it cost fewer tokens? | Tokens per task, by arm | `/cost` (or `/context`) before and after the task; `scripts/ledger-append.sh`, split by phase with `scripts/phase-log.sh`; summed by `scripts/report-metrics.sh` |
| Does it find more? | Recall on known issues: how many of the planted/known cases the run reported | `review/regressions.md` cases with SHAs filled in |
| Does it cry wolf? | False-positive rate: reported findings a human rejects | A human triage of each finding: true / false / nit |
| Does generation miss less? | Untouched-consumer areas and helper re-implementations left unhandled after the task | `scripts/impact.sh <base>` and `scripts/reuse-scan.sh <base>` on the finished diff |
| Does it hold up in real use? | Human PR comments per 100 changed lines, and how many were "flow / why" questions | The PR itself, over time |

## Arms (change one thing at a time)

- **A - plain:** Claude Code with no toolkit and no project rules file. Same model, same task.
- **B - lean:** the toolkit with `Mode: standard`.
- **C - strict:** the toolkit with `Mode: strict` (the default).

Each run is a fresh session started from the same commit, and the model and toolkit version
are written down. Run each arm at least three times; one run tells you nothing about
variance. Alternate the order so the first run does not always get the cold cache.

## Task set (keep it small and repeatable)

1. **Review replay (3 cases).** Pick three entries in `review/regressions.md`, fill in their
   `base` and `head_before_fix` SHAs once, and review that range. Score recall against the
   known case. Hold some cases out: do not tune the rubric on the ones you score.
2. **Generation with a known blast radius (2 tasks).** For example: add a case to an enum
   that other screens switch over; change a function with callers in another feature. The
   answer key is `scripts/impact.sh` plus a human list of the flows that had to change.
3. **Generation near an existing helper (1 task).** A task where a suitable extension
   already exists (a blank/nil check, a date formatter). The key is whether the run used it.

## Recording a run

One row per run in `results.md`: arm, task, tokens before and after (or weighted if you use
the cost report), tool calls, wall time, clarification rounds, then the effectiveness
columns. Weighted cost, if you use it, must be the same formula across all rows (the session
reports weight cache reads at 0.1, cache writes at 2 and output at 5).

## Reading the results

- Compare arms on the same task only. A review of a 20-file diff and one of a 2-file diff
  do not share a baseline.
- A saving that costs recall is not a saving. Report both together.
- A rule that changes no result over about ten runs is a pruning candidate (AGENTS.md, Maintenance). A miss the toolkit makes becomes a new case in `review/regressions.md`.
- Write down what you could not measure. Vendor review benchmarks are small and self-run;
  these runs are also small, so say how many.

## Quick version (ten minutes, no setup)

Run the same review on one PR in arm A and arm C, note `/cost` before and after each, and
count the findings a human would keep. That single row is already more than the estimates.
