# Skill: build-context

Use for ANY project, in any language, when `context/base-snapshot.md` is missing, still the
template, or stale in the area being touched. Goal: before writing or changing code, the
agent knows what the project is, how big it is, how it is structured, where shared things
live, and how it is verified - built cheaply, then confirmed by the developer.

## 1. Probe (one command, no file contents)

Run `scripts/map-probe.sh` from the project root. It works on any repository and prints
paths, names and counts only: size and languages, build manifests, docs that explain the
project, source files per directory, role directories (controllers, services, utils...),
entry points, cross-cutting homes (auth, logging, config, errors, networking), where tests
live and how they run, CI / lint / coverage gates, where recent work happens, the largest
files. If a stack has a plugin in `scripts/probes/`, its extras are appended. No plugin
for your stack is fine: the core output is enough; you simply read a little more.

## 2. Read selectively (about 8-12 reads, ranges not whole files)

Use the probe output to open only what a map row needs:
- the README / ARCHITECTURE / CONTRIBUTING it listed (headings and key sections)
- one reference feature end to end (signatures per layer)
- the shared helper files and the auth / permission / logging / config homes it surfaced
- the main entry point and one place where routes or screens are registered
- one existing test file, and the CI file that sets any gate

If the task is confined to one area, spend the reads there and mark the rest `?`; a later
task adds the rows it needs.

## 3. Write the map

Fill the sections of `context/base-snapshot.md`, one line per entry with a path, inside the
size cap. Mark anything inferred rather than read with `?`. Never invent a row. Scope
(section 1) is as important as structure: say what is active, what is legacy, what is
large, so the change is sized and placed correctly.

## 4. Confirm with the developer (one batched message)

List the 3-5 least certain rows and what code can't answer (which helper is the standard
for X? is there a shared process for Y? what do CI gates require? what may the agent run?).
Correct the map from the answers, then fill `snapshot_commit` (full SHA of `base_ref`),
`captured_at`, and one Build log line.

## 5. Keep it honest

- Conventions revealed later (a review comment, a missed helper, a CI failure) become map
  rows at the end of that task (`skills/session-report.md`, "Map additions").
- Remove a row that is no longer true; the map shrinks as often as it grows.
