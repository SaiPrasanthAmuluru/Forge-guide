---
name: forge-session-report
description: "Use at the end of a batch of work (multiple bug fixes, new-feature generations, and/or PR reviews) to produce one consolidated report, instead of handing over individual spec/log files for each task separately."
---

This is a thin wrapper. The workflow lives in one place, the toolkit file below, so there is a
single copy to maintain.

1. Read `$FORGE_HOME/AGENTS.md` for the load order, if it has not been read in this session.
2. Read `$FORGE_HOME/skills/session-report.md` and follow it.

If `FORGE_HOME` is not set, ask the developer where the Forge-guide toolkit is kept
(`export FORGE_HOME=<path>`). Do not guess a path.
