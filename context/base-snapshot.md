---
base_ref: origin/main
snapshot_commit: <full SHA of base_ref when this was captured - fill on first build>
captured_at: <date>
---

# Codebase map (cached)

The first thing a generation task reads - the whole file, every time, so it is capped at
~120 lines (~2.5K tokens): one line per entry, with a path. It answers "what is this
codebase, how big is it, how is it laid out, where do things live, and how is it tested", so
new code reuses what exists and goes where it belongs. Built by `skills/build-context.md`
from `scripts/map-probe.sh`; freshness per `context/context-scan.md`. It describes one
project: keep it in that project's repo.

Not authoritative for anything diff-specific ("who else calls this exact symbol" is the
cross-call-site check and always runs live). A row marked `?` is unverified.

## 1. Purpose and scope
<What the project is in two lines; stacks and languages; rough size (source files, main
directories by size); which areas are active (recent churn) vs. stable or legacy; the
docs that explain it (README, ARCHITECTURE, ADRs).>

## 2. Structure
<Top-level layout and what each part owns; modules/packages and their dependency
direction; the layers in use (e.g. handler -> service -> repository, or view -> view model
-> use case) and where a new piece of each kind goes; ONE reference feature to imitate,
with its file per layer.>

## 3. Shared helpers and conventions - where do I find X
<One line each: name - file - when to use. Cover whichever exist: null/empty/blank
handling; current user, permissions and ownership checks; logging (and what reaches
production); dates and time; HTTP/API client and error type; configuration and feature
flags; analytics; localization; error/notification UI; naming and file-placement rules.>

## 4. Entry points and wiring
<Where the app starts; where routes, commands, screens or jobs are registered; how
dependencies are created/injected; the arguments existing entry points pass, so a new one
matches.>

## 5. Processes shared across features
<Flows several features reuse and must not re-implement (approval, cancellation, retry,
auth refresh, session/logout cleanup, permission gating). Name the shared implementation,
or "none - verified per feature".>

## 6. Tests, CI and how work is verified
<Test framework and where tests live; which test folders are really built/run; where mocks
live; the commands the developer runs (and which the agent may run); CI gates (coverage
threshold, lint, type checks) and the local command to check them.>

## 7. Risk areas
<Areas that are fragile, security-sensitive, concurrent, or already known as hotspots
(pointers to playbook IDs or past reports).>

## Build log
<One line per build/refresh: date, commit range, full vs incremental, rows corrected.>
