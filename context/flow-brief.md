# Flow brief

Used by the generation skills (new-feature, bug-fix, refactor, api-integration) before any
code is written. Two jobs: **understand the existing flow the change plugs into**, and
**ask about what is still unclear** - in that order. Reading the code answers what code can
answer; people answer the rest. Not loaded for reviews.

Why: the author pass keeps passing on assumptions it never confirmed - ownership inferred
from an absent id, a flag carried forward with no reader, a scope the code contradicted.
Those were assumptions about *flow*, not about missing utilities.

## 1. Map the flow (bounded, targeted)

The overall codebase map (`context/base-snapshot.md`) is read first, in full - see
`context-scan.md`. This step is only about the area being touched. Fill the spec's **Flow & understanding**
section, ~25 lines:

- **Entry points** - every way into this behavior: UI action, deep link, push, background
  task, widget, API callback. `file:line` each.
- **Current flow, end to end** - trigger -> view/controller -> view model -> use case ->
  repository/service -> API or store -> state change -> UI. One line per hop with
  `file:line`. For a bug: the path from trigger to the failing point, plus what *should*
  happen there.
- **State and ownership** - who owns each piece of state, the source of truth, caching and
  freshness, and who else reads or writes it (shared contracts get the cross-call-site
  check).
- **Boundaries crossed** - permission/role, record ownership, tenant/session switch,
  logout mid-flow (IOS-012, IOS-035, IOS-036).
- **Closest existing analogue** - the feature to follow, and how this one differs. List its
  vertical slice, one file per layer (view, view model, use case, repository, API, router,
  test), and read the signatures of each before writing the new code. New code matches the
  analogue's shape unless the Decisions & why table says otherwise.
- **Impact on existing flows** - for every declaration you will change, remove, or whose
  behavior changes (not only "shared contracts"): run `scripts/impact.sh --symbols <names>`.
  It lists consumers by area, and the ones in files you will not touch are the flows to
  confirm. Each such area gets a decision in the spec's Impact table (still correct /
  adapted / out of scope, and who decided); an area you cannot decide is a question for the
  batched round. Enum cases, selector/notification strings and generated code need
  `xref.sh --also`. Re-run `impact.sh <base>` on the finished diff: symbols you ended up
  touching that you did not plan are the ones that surprise reviewers.
- **Existing helpers and their usage** - before writing any helper, extension, formatter,
  mapper or check: `scripts/reuse-scan.sh --need "<types, verbs, nouns of what you need>"`.
  Use a match, or say why not. For each helper/API you will call, read two or three existing
  uses (`xref.sh <name> --max 3`) and match their arguments, error handling and style; the
  "used Nx" count tells you which form is the convention.
- **Rules per path** - for each rule in the request, the entry points, the sibling screens
  sharing the component and the row/item types it must hold on (IOS-047). A rule is not
  done until it is confirmed on each.
- **Other platforms** - if web or Android already ships this, how it presents real data
  (grouping, duplicates, empty states, labels) and what the design says, before building
  UI from the API shape (IOS-048).
- **Tests** - what covers this area today, and what does not.

Budget: grep to find hops, then read only signatures and the lines in the path
(offset/limit), not whole files. Roughly 10-12 reads; `fast` Mode fewer. Anything not
traced is listed as "not traced" - never filled in by guess.

### Reuse the area note when it is still valid (context at intervals, not every time)

Save the finished flow map of an area as `context/areas/<area>.md` (the same ~25 lines,
with `base_ref`, `snapshot_commit` and `captured_at` in its frontmatter and the `file:line`
paths cited). Next task in that area: run `scripts/check-context-freshness.sh
context/areas/<area>.md`. `CURRENT` / `CURRENT-ENOUGH` -> reuse the note, spend the reads only
on what the new task adds; `STALE` -> it names the cited paths that changed, re-trace only
those hops and update the note. The note is project-specific: keep it in the project repo.

## 2. Turn the gaps into three lists

For everything unclear:

1. **Answerable from code** - go and read it. Never ask a person what one grep answers.
2. **Needs a human** - product intent, the backend's guarantee, a design decision, who is
   allowed to do this. These become questions.
3. **Safe to assume** - low-risk and reversible. Written down as an **Assumption** (with
   the risk if wrong) in the spec and shown to the person; proceed on it.

## 2b. Justify everything you add (before the round)

A human reviewer's most common comment is not "this is wrong" but "why does this exist?"
(why this parameter, why a separate file, why does the router pass this). For every new
type, file, parameter, flag, rule or entry point you plan, answer four things in the spec's
**Decisions & why** table:

1. **Reader** - what reads it, and does that reader actually change behavior? (A value
   computed for a screen that hides the control anyway has no reader.)
2. **Existing mechanism** - is there already a process for this that other cases share
   (e.g. every request type being cancelled the same way)? Search before adding a
   parallel rule; if the new thing is a special case, say why it must be.
3. **Derive, don't pass** - can the destination work this out from data it already loads
   (the request-details call by id)? Passing a precomputed answer through a router
   duplicates the rule and goes stale.
4. **Honest scope** - does the name and doc comment claim no more and no less than the
   code covers (self-cancel vs. all cancellation), so it isn't reused for the wrong case?

A row you cannot justify becomes a question in the batched round, or the thing is not added.
The table is reused as the PR description, so the reviewer gets the answers up front.

## 3. One batched round

Ask in a single message, menu-style, 2-4 concrete options per question built from what the
scan found, last option open text. With a question tool, at most 4 questions per call:
take the highest-risk ones and turn the rest into Assumptions. Structure:

1. **My understanding** (<= 8 lines): the current flow, the intended change, and what will
   not be touched. Ask the person to confirm or correct it. This is the cheapest way to
   catch a misread flow before it costs code.
2. **The "needs a human" questions**, drawn only from the checklist items that are relevant
   and unanswered:
   - *Trigger*: every route in? (UI / deep link / push / background)
   - *Actor*: who may do this; whose record is it; what if it is someone else's?
   - *Data*: source of truth, freshness, offline, empty and error states.
   - *Sequencing*: repeat taps, concurrent triggers, cancellation, ordering.
   - *Boundaries*: tenant/session switch or logout mid-flow.
   - *Contract*: which API fields are guaranteed, which can be missing.
   - *Side effects*: analytics, notifications, caches to invalidate.
   - *Compatibility*: feature flag, minimum OS, existing data.
   - *Done*: what proves it works; whether tests are expected.
3. **Assumptions** being proceeded on, so a wrong one is cheap to reject.

Skill-specific defaults (consumer, data shape, scope, repro...) are asked only if the scan
and the spec don't already answer them.

Skip the question round - but still show the understanding and the assumptions - when the
change is small and reversible, nothing in list 2 affects behavior, permissions, data or a
shared contract, and the Mode is `fast`. Never skip it in `strict` while list 2 is
non-empty. Unattended: take the most reasonable reading, say which at the top of the work,
and stop only for something that cannot be undone.

Don't ask: what the spec, ticket or code already states; style the constitution or
playbook decides; "shall I go ahead?".

## 4. Stop and ask during the work

Pause, with one focused question and options, when:

- the code contradicts the flow map;
- a step in the request has two readings that lead to different behavior;
- the work needs a layer or subsystem outside the agreed scope;
- `impact.sh` shows consumers in a flow the spec never mentions;
- an Assumption turns out false;
- the better design needs a wider change than the request: do not widen it; deliver the
  fit-today change and record a "Beyond this change" note;
- a parameter, flag or property would have no reader (value-has-consumer) - don't invent
  one to make the code compile.

Record the answer in the spec (Open questions resolved / Assumptions updated) so it isn't
asked twice.
