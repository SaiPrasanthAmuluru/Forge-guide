---
name: forge-spec-builder
description: "Use when a spec should be drafted from existing sources (a ticket, a PRD, design files, API docs) rather than authored from scratch. Reduces the manual-authoring friction in the spec-gate by pre-filling `spec.md`, while never fabricating anything the sources don't actually support."
---

This is a thin wrapper. The workflow lives in one place, the toolkit file below, so there is a
single copy to maintain.

1. Read `$FORGE_HOME/AGENTS.md` for the load order, if it has not been read in this session.
2. Read `$FORGE_HOME/skills/spec-builder.md` and follow it.

If `FORGE_HOME` is not set, ask the developer where the Forge-guide toolkit is kept
(`export FORGE_HOME=<path>`). Do not guess a path.
