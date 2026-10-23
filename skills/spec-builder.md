
# Skill: spec-builder

Use when a spec should be drafted from existing sources (a ticket, a PRD, design files, API
docs) rather than authored from scratch. Reduces the manual-authoring friction in the
spec-gate by pre-filling `spec.md`, while never fabricating anything the sources don't
actually support.

## Trigger phrases
"build a spec from this ticket", "turn this PRD into a spec", "spec this feature out"

## Step 1 - Gather sources

Identify what's available: a ticket/work-item, a PRD or requirements doc, design files
(Figma or equivalent), API/schema documentation (OpenAPI/Swagger or equivalent). Extract
every source URL/reference from the ticket body, not just its main description field -
custom fields often hold design and API links.

## Step 2 - Confirm or collect missing sources (batched, per the token-economy rule)

For anything missing, ask once, batched:
- No design source found - paste a link, or skip (UI/component inventory will be
  incomplete)?
- No PRD/requirements doc found - paste a link, or use only the ticket's own description
  and acceptance criteria?
- No API/schema doc found - paste a link, or skip (API mapping will be incomplete/best-
  guess)?

Do not proceed past this step without at least one requirements source (ticket or PRD).
Print back what was confirmed before continuing.

## Step 3 - Extract, don't fabricate

Pull requirements, acceptance criteria, and any explicit constraints directly from the
sources. For a design source: inventory each screen/component, its key actions, and data
shown. For an API/schema source: map each identified user action to a specific endpoint by
path and method - **never invent an endpoint that isn't in the source**. Anything that
doesn't have a clear source match goes in a "Gaps" section, not into the spec as if it were
confirmed.

## Step 4 - Draft spec.md

Use `specs/template/spec.md`. In addition to the standard sections, populate:
- **Component/Screen inventory** (if a design source was available) - name, purpose, key
  actions, data shown.
- **Interface mapping** (if an API/schema source was available) - action → method →
  endpoint → key request/response fields. List unmapped actions separately as gaps, not as
  silently-assumed endpoints.
- **Dependencies** - backend/other-feature/third-party dependencies found in the sources.
- **Open questions** - anything a source left ambiguous, with an owner (Product/Design/
  Backend/unclear) and a rough priority, not just a flat list.

Leave `[NEEDS CLARIFICATION]` markers on anything the sources didn't resolve, exactly as a
manually-authored spec would - this skill changes how the spec gets populated, not the
spec-gate rule that clarification markers must be resolved before task breakdown begins.

## Step 5 - Confirm and summarize

Report what was produced: source count used, screens/endpoints mapped, gaps flagged, open
questions raised. This is a draft for human review, not a final spec - say so.

## Rules

- **Never fabricate a requirement, constraint, or endpoint not found in a source.** A gap
  in the sources is a gap in the spec, stated explicitly - not filled in with something
  plausible-sounding.
- **Read-only against the source systems** unless the person explicitly asks to post the
  generated spec back (e.g., as a ticket comment) - that is a separate, optional,
  explicitly-confirmed step, never automatic.
- **One spec per run** - if a spec already exists for this feature, ask before overwriting
  rather than silently replacing it.
