
# Skill: api-integration

Use when connecting to an external service, library, or third-party API.

## Trigger phrases
"integrate", "connect to", "call the API", "add SDK", "wire up"

## Step 0 — Context scan and flow map (before anything else)

Read the overall map first (`context/base-snapshot.md`; `skills/build-context.md` if
missing) and record `Map consulted`. Follow `context/flow-brief.md` for the flow map: where the call is triggered, how
responses reach the UI or store, who owns that state, what the existing network/auth layer
does. Then search for an existing integration of this provider, or a centralized network/auth layer
this should go through, before writing a parallel path. If a similar integration already
exists for a different provider, check whether its pattern should be followed for
consistency. Populate the spec's Existing-code context section from this.

## Impact and reuse (scripts)

`scripts/impact.sh --symbols <declarations you will change or remove>` before coding and
`scripts/impact.sh <base>` on the diff after; `scripts/reuse-scan.sh --need "<words>"` before
writing any helper and `scripts/reuse-scan.sh <base>` after. Record both in the spec
(Impact scan, Reuse scan).

## Before generating any code (batched round)

Lead with "my understanding" (trigger, call, what happens to the response, what is not
being touched) per `context/flow-brief.md` section 3; apply its stop-and-ask rules
(section 4) while building. Ask only what the docs, schema and code don't already answer.
The *Contract* item in its checklist matters most here - which response fields are
guaranteed and which can be missing; never assume.

1. **Auth** — does this need new credentials/config, or does the repo already have a
   pattern for this provider? (new config needed / existing pattern: <name> / unsure)
2. **Error handling** — what should happen on failure — retry, fail silently, surface to
   user? (retry with backoff / fail silently, log / surface error to user)
3. **Rate limits / cost** — is this a paid or rate-limited API that needs throttling
   awareness? (yes, throttle / no concern / unsure — check docs first)
4. **Data handling** — does response data need to be cached, persisted, or is it
   transient? (cache / persist to <store> / transient, no storage)

## Security check (HARD, from constitution)

Confirm no credentials get hardcoded or logged. Confirm the integration doesn't bypass any
existing centralized network/auth layer already in the repo.

## Currency check

Before wiring up an SDK/client library, check whether it's on a version the provider has
scheduled for deprecation or removal — most API providers publish an explicit deprecation
timeline (dated phases, a minimum-supported-version header, or a formal policy). If a
newer stable version exists with no migration blocker, prefer it over pinning to something
already in its deprecation window. This is the api-integration-specific instance of the
platform/language currency check in `memory/quality-gate.md` — that file has the general
rule; this is where it applies to a provider's own versioning, not just language/OS APIs.

## After implementation

Verify against acceptance criteria, and specifically verify the failure-path behavior
(criterion 2 above) — not just the happy path. Run the applicable checks from
`memory/quality-gate.md` against the diff before calling the integration done.
