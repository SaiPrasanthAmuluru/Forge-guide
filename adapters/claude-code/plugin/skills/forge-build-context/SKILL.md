---
name: forge-build-context
description: "Use for ANY project, in any language, when `context/base-snapshot.md` is missing, still the template, or stale in the area being touched. Goal: before writing or changing code, the agent knows what the project is, how big it is, how it is structured, where shared things live, and how it is verified - built cheaply, then confirmed by the developer."
---

This is a thin wrapper. The workflow lives in one place, the toolkit file below, so there is a
single copy to maintain.

1. Read `$FORGE_HOME/AGENTS.md` for the load order, if it has not been read in this session.
2. Read `$FORGE_HOME/skills/build-context.md` and follow it.

If `FORGE_HOME` is not set, ask the developer where the Forge-guide toolkit is kept
(`export FORGE_HOME=<path>`). Do not guess a path.
