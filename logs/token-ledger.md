# Token ledger

Append-only. Rough numbers are fine — the point is the trend, not precision. Roll old
entries into a monthly summary once this gets long (AGENTS.md, Maintenance).

**How to fill "Tokens":** note the session token count (your tool's usage readout, e.g. `/cost` in Claude Code)
before the task and after it; the difference is the task's cost. If you only have one
reading per session, record the session total and say so in Notes. A guess marked `~` beats
a blank cell — blank is what hid the cost trend before.

| Date | Task | Type | Mode | Tokens (Δ) | Clarif. rounds | Full-file regens | Playbook IDs loaded | Notes |
|------|------|------|------|-----------|----------------|------------------|---------------------|-------|
| <date> | <task name> | gen / fix / review / merge / report | strict / standard / fast | <~n> | <n> | <n> | <e.g. IOS-001, IOS-028> | <e.g. "base-snapshot stale, refresh read 3 files"> |

## Reading the trend

`skills/session-report.md` computes tokens per task type from this table and flags a
rising trend. The three levers it points at, in order of how often they were the cause:
a long chained session (start fresh), a playbook/rule file read whole instead of via
`scripts/playbook.sh`, and re-reading an unchanged diff. Mode is recorded so a cost jump
caused by switching `standard` → `strict` isn't misread as a regression.

This file is per task. For where the tokens went inside a task use `scripts/phase-log.sh`
(`logs/phase-ledger.md`); for what was found and who found it use `scripts/finding-log.sh`
(`logs/findings-ledger.md`); `scripts/report-metrics.sh` reads all three.
