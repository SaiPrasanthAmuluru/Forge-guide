# Playbook: iOS / Swift

Known-better-patterns for this stack, grounded in real incidents - not hypothetical best
practice. Each entry: **Seen** (what actually happened) → **Action** (the concrete rule) →
severity + rule ID. Referenced by both generation skills (write code that avoids these) and
`review/review-prompt.md` (check code against these) - one source of truth so the two never
drift apart.

When a new recurring pattern shows up (a second real instance of something not already
listed here), add it - this file grows from actual mistakes, not from theory.

---

### IOS-001 - Core Data: `NSBatchDeleteRequest` skips cascade delete rules [CRITICAL]

**Seen:** A "delete this tenant's row" function used `NSBatchDeleteRequest` for performance.
The entity had ~40 relationships marked `deletionRule="Cascade"` in the `.xcdatamodel` - but
`NSBatchDeleteRequest` executes directly against the persistent store and never goes
through the object graph, so none of the cascades fired. The parent row disappeared; every
dependent row stayed orphaned on device. No exception, no silent catch - the batch delete
reported success; it just doesn't do what `context.delete()` + save does.
**Action:** Before using `NSBatchDeleteRequest`, check the entity's relationships for
`deletionRule="Cascade"`. If any exist and the intent is "delete this and everything that
depends on it," fetch the objects and delete them through the context instead. Batch delete
is only safe when the entity has no cascade relationships that need to fire, or the bypass
is intentional and documented.

### IOS-002 - Core Data: `fetchOffset` pagination is O(n²) on SQLite [MEDIUM]

**Seen:** A paginated list used `NSFetchRequest.fetchOffset` to skip to the next page. On
the SQLite store, `fetchOffset` is a linear skip - the engine walks and discards every row
before the offset on every single page fetch, making a full scroll through a large dataset
O(n²) total row-touches instead of O(n).
**Action:** For any Core Data-backed pagination, use a keyset/cursor predicate (e.g.
`sortKey > lastSeenValue`) instead of `fetchOffset`, especially once the dataset can reach
thousands of rows.

### IOS-003 - Core Data: context confinement and object lifetime [CRITICAL]

**Seen (rubric-derived, recurring class):** `NSManagedObject`/`NSManagedObjectContext`
created on one queue and accessed on another; `NSManagedObject` instances passed across
threads directly instead of `NSManagedObjectID` + re-fetch; a faulted object's properties
read after its context was reset/deleted.
**Action:** Never pass `NSManagedObject` across threads - pass `NSManagedObjectID` and
re-fetch via `context.perform`. Never call `performAndWait` from the queue you're already
on. Batch operations must merge changes into the view context afterward.

### IOS-004 - Concurrency: `Task {}` needs its own actor isolation, not incidental timing [CRITICAL]

**Seen:** `Task { await someMainActorFunc(); showLogin() }` - `showLogin()` touches UI, but
after the `@MainActor` `await` returns, the continuation isn't guaranteed to still be on the
main thread, because the enclosing `Task` (created from a bare closure or a Combine `.sink`)
had no actor context of its own.
**Action:** If anything in a `Task {}`'s body - before or after an `await` - touches
`@MainActor` state, UIKit/SwiftUI, or a documented main-thread-only singleton, mark the
`Task` itself `@MainActor`. Don't rely on incidental timing.

### IOS-005 - Sync a UI affordance to actual completion, and audit every exit path [HIGH]

**Seen:** A loading indicator shown right before starting async work, dismissed immediately
after *creating* the `Task` rather than after the work inside it finished - so the
indicator vanished while work was still running, and nothing stopped a duplicate tap.
Separately: a loader correctly moved to dismiss on completion, but a `guard let else {
return }` sitting between `show()` and the `Task` (added for an unrelated reason) returned
before ever reaching `dismiss()`, leaving the loader on screen indefinitely when that
guard's optional was genuinely nil.
**Action:** Set the indicator/re-entrancy guard before the async call; reset it inside the
`Task`'s own continuation, after the `await`. Then trace *every* `return`/`throw`/early-exit
between `show()` and `dismiss()` - not just the success and completion paths - and confirm
each one dismisses too.

### IOS-006 - Don't silently fall back or silently swallow a failure [HIGH]

**Seen (recurring across multiple PRs):** A malformed regex silently passing validation
instead of falling back to a real check; a plausible-but-wrong fallback chosen silently
instead of erroring; a Core Data cleanup failure logged only via `debugPrint` instead of
Crashlytics on a PR specifically about cleanup correctness.
**Action:** For any "the happy path didn't work" branch, ask whether the fallback is
provably correct for every caller, and whether the failure needs to be observable (a
non-fatal log at minimum) rather than a local debug print only.

### IOS-007 - Fallback chains that silently collapse (`a ?? b ?? c`) [HIGH]

**Seen:** `totalPages = response.totalPages ?? response.currentPage ?? pageIndex` looks like
a safe default, but when the first value is nil and a later one isn't, it can produce a
value that makes a downstream comparison trivially true/false (`currentPage >= totalPages`
becomes always-true once `totalPages` silently becomes `currentPage`), silently truncating
a list instead of erroring.
**Action:** Trace what each fallback tier actually does to the code that consumes it, not
just whether it compiles. A fallback that changes a comparison's outcome needs to be an
explicit branch, not a chained `??`.

### IOS-008 - A new storage domain needs a migration path for existing installs [HIGH]

**Seen:** Introducing a new isolated storage location (a new UserDefaults suite, a new Core
Data model version) to fix a data-segregation bug is correct, but existing installs still
have the data in the *old* location - without an explicit one-time copy, it silently resets
to nil/default on next launch. Invisible on a fresh simulator install, which is exactly why
it's easy to miss.
**Action:** Whenever a value moves to a new storage domain, write a guarded one-time
migration - copy forward once, remove from the old location, flag so it never re-runs - and
test both "migrates once" and "never migrates twice."

### IOS-009 - Don't read a value after clearing one of its sources [HIGH]

**Seen:** A getter checked one store first, falling back to a second. A clear-everything
function (which cleared *both* sources) was called before code that still needed to read
the value to clear a dependent resource (a token) keyed by it - the getter returned empty
at that point, and the dependent resource was never cleared.
**Action:** When a function both reads a value and later clears one of its sources, capture
the value in a local constant before any clearing starts.

### IOS-010 - Generation/epoch guards must cover every mutating entry point [HIGH]

**Seen:** A counter/token introduced to discard stale async completions (a common fix for
"two calls race, the older one clobbers the newer one's state") only guarded the method the
original bug was found in - a sibling method touching the same guarded state was left
unprotected, leaving the identical race reachable via the other path.
**Action:** When adding a generation/epoch guard, check every method that mutates the same
guarded state, not just the one where the bug was reported.

### IOS-011 - Recursive or repeatedly-triggered async operations need an explicit bound [HIGH]

**Seen:** A paginated fetch recursed into "get the next page" whenever a page came back
empty-but-not-last, with no delay, backoff, or recursion cap - a long run of filtered-out
rows fired that many requests back-to-back with zero throttling. Separately, a per-page
background save spawned an unstructured `Task` per call with no cap, so fast scrolling
piled up concurrent tasks.
**Action:** Any loop that recurses on a condition (empty result, retry-on-failure) or spawns
a task per UI-triggered event needs an explicit cap, backoff, or cancellation mechanism -
don't rely on the triggering condition naturally becoming false quickly.

### IOS-012 - Session/login-boundary changes touch more surfaces than the one that triggered them [CRITICAL]

**Seen:** False auto-logouts traced to token-refresh/401 handling spanning the API layer,
the auth module, and the login flow - never contained to one file. Deep links arriving
while logged out silently dropped with no queue/replay. "Shown once" flags racing under
rapid triggering.
**Action:** For any change touching login, logout, tenant switch, or token refresh,
enumerate every session boundary (first login, add org, tenant switch, single-org logout,
full logout, token refresh, unauth recovery) and confirm the fix applies consistently
across all of them - not just the one that triggered the change.

### IOS-013 - Test-only helpers and boilerplate duplicated across sibling files/methods [MEDIUM]

**Seen:** A wait-for-async-completion helper or mock-response builder repeated per test
file with the same signature and body instead of a shared test-support file. Separately, a
fix applied to one method (a guard, a retry loop) copy-pasted into a sibling method in the
same diff instead of extracted into a shared helper both call.
**Action:** If a diff's own fix introduces duplication across two methods or files it also
touches, extract a shared helper before calling the fix complete - this counts even though
the duplicated code is "new," not legacy debt.

### IOS-014 - Design System / theming consistency [MEDIUM]

**Seen:** Raw `Color.*`/`UIColor.*` literals, hardcoded opacity, or magic-number
frame/spacing/corner-radius constants introduced in a file that already uses the project's
Design System tokens elsewhere.
**Action:** Check the same file for an established token pattern before introducing a new
raw value - this is a real consistency bug affecting dark-mode correctness, not just style.

### IOS-015 - Entitlements/capability config gets source-code-level rigor [CRITICAL]

**Seen:** A `.entitlements` change edited `keychain-access-groups` without confirming the
app's own default access group (`$(AppIdentifierPrefix)$(CFBundleIdentifier)`) was still
present - once this key is declared explicitly, any Keychain item saved without an explicit
access group becomes unreadable if the app's own default group isn't listed, silently
breaking Keychain-backed features the PR never touched.
**Action:** Any diff touching `.entitlements`, `Info.plist` capability keys, or provisioning
config gets the same review rigor as source code. Check every target/variant's entitlements
file individually - a fix applied to one target and missed in a sibling is a common,
easy-to-miss inconsistency. Verify current Keychain sharing behavior against Apple's docs
if uncertain rather than asserting from memory.

### IOS-016 - Green build and passing tests are not proof new logic is correct [MEDIUM]

**Seen (repeatedly):** Existing tests only prove "didn't regress what was already covered" -
they say nothing about new edge cases a change introduces, because nothing exercises them
yet. A deep review run once early in a multi-round PR caught issues that "build + existing
tests pass" on every later round of fixes did not, because those later rounds were all new
logic no existing test covered.
**Action:** For the specific new failure mode a fix addresses, write a test that actually
exercises that scenario. For a PR touching concurrency, ordering, or multi-store cleanup,
re-run the full adversarial pattern search after *every* round of edits, not just the first
commit.

### IOS-017 - Platform currency check: this stack's specifics [see quality-gate.md]

The project's declared minimum target is its deployment target (check the `.xcodeproj`/
`Package.swift`, or infer from existing `@available` usage). New API usage requiring a
later OS version than that, without a corresponding `@available(iOS X, *)` /
`if #available` guard, is a straightforward crash-on-older-devices bug - easy to miss since
it compiles and runs fine on the developer's own (usually newest) device/simulator.

Common deprecated-vs-superseded patterns worth checking: old completion-handler
networking/location/photo APIs where a structured-concurrency `async`/`await` equivalent
now exists; `UIScreen.main`; `UIApplication.shared.keyWindow`/`.windows` used instead of the
active window scene; older `ObservableObject`/`@Published` patterns where `@Observable` is
both available and a clear win given the deployment target. Verify current status against
`developer.apple.com` or `swift.org` before asserting something is deprecated - don't guess
from memory on this fast-moving surface, and mark Confidence: Low if unverified this run.

An `#available`/`@available` check with an empty, TODO, or silently-feature-dropping
`else` branch is technically safe but often an incomplete implementation - flag it.

### IOS-018 - Project-level default actor isolation silently isolates plain data types [HIGH]

**Seen:** A project built from a recent Xcode template had
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` set at the project level. This silently makes
every type's protocol conformances (`Decodable`, `Equatable`, etc.) main-actor-isolated
too, unless the type is explicitly marked `nonisolated` - invisible until something crosses
an isolation boundary (a `Sendable`-constrained async API from a third-party library, or a
`nonisolated` test context), at which point it surfaces as a confusing isolation error far
from the type that actually needs the fix.
**Action:** Before writing any plain data/infra type (models, protocols meant to be
concurrency-safe, non-UI utilities) in a project, check the build settings for
`SWIFT_DEFAULT_ACTOR_ISOLATION`. If it's `MainActor`, mark genuinely concurrency-safe types
`nonisolated` explicitly rather than relying on them happening to work - don't assume
"it's just a struct" is enough once this setting is in play.

### IOS-019 - `.xcodeproj` structural edits may need to bypass the standard Ruby tooling [MEDIUM]

**Seen:** The installed `xcodeproj` Ruby gem could not parse a project using Xcode's newer
`PBXFileSystemSynchronizedRootGroup` format at all - it crashed on open. Adding an SPM
dependency and a new unit-test target had to be done by hand-editing `project.pbxproj`
directly instead.
**Action:** Before assuming a `.xcodeproj`-manipulating tool/gem will work, check whether
the project uses the newer synchronized-root-group format (a `PBXFileSystemSynchronizedRootGroup`
section in `project.pbxproj`) - if so, expect to hand-edit `project.pbxproj` directly, and
verify incrementally with `xcodebuild -list` and a build/test run after each chunk rather
than trusting a large hand-edit blind.

### IOS-020 - Marking a checkpoint verified before the write it attests to has actually persisted [HIGH]

**Seen:** Both `saveItemList` and `updateItems` called a verification-checkpoint's
`markVerified` inside a `performBackgroundTask` closure, before that helper's own implicit
auto-save (which runs *after* the closure returns) had a chance to fail. A save failure
would leave the checkpoint claiming the data was verified when the actual write never
persisted, silently reintroducing the exact staleness bug the checkpoint existed to fix,
for a full TTL window. Not caught at implementation time, and not caught by a same-session
self-review that carefully checked a *different* checkpoint's concurrency but didn't apply
the same scrutiny to this one added in the same general timeframe. Only caught by a
separate, later, explicitly adversarial review pass that traced the actual implementation
of the auto-save helper instead of assuming its timing.
**Action:** When a checkpoint/cache is used to gate future trust in a write, explicitly
save (and check the result) before marking that checkpoint - never rely on an enclosing
helper's implicit deferred save happening first. See IOS-021 for the process gap this also
exposes: a same-session self-review is not sufficient coverage for this bug class.

### IOS-021 - A same-session self-review is not a substitute for a separate adversarial pass [see quality-gate.md]

**Seen (three times now, independently):** In one incident, a same-session self-review of
a fix missed a compile-breaking type error and an actor-isolation violation in its own
change, both caught only by a separately-requested independent re-review. In another, a
dedicated self-review carefully re-checked one checkpoint's concurrency but didn't apply
the same scrutiny to a second checkpoint added in the same window, missing an ordering bug
that shipped to production before a later, explicitly-requested "all angles" pass caught it
by tracing a framework helper's actual save-timing behavior instead of assuming it. In a
third, a self-review explicitly cited an existing sibling function as a trusted reference
pattern ("mirrors fetchRoles()") without auditing whether that pattern was itself correct -
it wasn't - and only a fresh-context independent pass caught it. In this third incident,
the fix that resulted from the independent review's findings was itself then committed and
pushed without a further independent pass - the rule was cited and understood in the same
session it was then skipped for the follow-up fix, until the person asked directly what had
been missed.
**Action:** This is now the generalized mandatory check in `memory/quality-gate.md` -
"Independent re-review for high-risk domains." Treat it as required, not optional, for
anything touching concurrency, persistence ordering, or shared checkpoints/contracts -
including every round of a multi-round fix, not just the first. Citing an existing pattern
as a trusted reference is itself a claim that needs verifying, not an exemption from
verification.

### IOS-022 - A stale-response guard's identity value must only change at an actual session boundary [HIGH]

**Seen:** Two functions compared an access-token string as a proxy for "did the session
change" to decide whether to discard a stale in-flight response. A routine token refresh
rewrites the access token under the *same* tenant/session without ending it - so a refresh
landing mid-flight tripped the comparison and silently discarded a valid response. Present
in both functions sharing the same underlying implementation; a same-session self-review
of the first function explicitly treated the second as a trusted reference pattern without
auditing it, so the same defect went unnoticed in both until an independent pass checked
the actual session-boundary semantics rather than trusting the existing code as ground
truth.
**Action:** Never use a value that merely *correlates* with session identity (an access
token, a cached credential) as a stale-response guard's identity check. Use a dedicated
counter/epoch that is incremented exactly at the real session boundary (login, logout,
tenant switch - wherever the codebase's actual session-clearing function runs) and nowhere
else. See IOS-010 for the related generation/epoch-guard-coverage pattern this specializes.

### IOS-023 - A regression test's setup can stop exercising what its name claims after a later fix changes the mechanism [MEDIUM]

**Seen:** A regression test named for "discards a response when the token changes mid-
flight" mutated a stubbed token store's access token during the test, matching its name at
the time it was written. A later fix (IOS-022's fix) replaced the token-comparison
mechanism with a dedicated session-generation counter - after which the guard code no
longer read the token store at all. The test still passed, and its setup still ran, but it
no longer exercised anything different from the plain "unchanged session" test sitting next
to it - the token-mutation setup became dead weight implying a regression check that wasn't
actually happening through that mechanism anymore. Not caught when the mechanism change was
made; only found while assembling an unrelated report, prompted by being asked to find
what else had been missed.
**Action:** When a fix changes the underlying mechanism a passing test was written to
guard, re-check that test's setup still exercises the new mechanism - don't treat "it's
still green" as sufficient. A test that no longer touches the field/path it was named for
needs renaming or reworking, even though it isn't lying about current behavior; a future
reader will reasonably assume the name still describes what's being tested.

### IOS-024 - A test failure dismissed as "pre-existing, unrelated" needs independent diagnosis before being dismissed [HIGH]

**Seen:** A test run reported "1302 passed, 3 failed" with the 3 failures described to the
user as pre-existing and unrelated to that session's own change - an observation, not a
diagnosis. A later, independent review pass traced the actual failing tests line-by-line
against the diff and found they were a direct, real regression introduced by that same
session's own change (a silently-swallowed error and a stale-fallback path both introduced
in the diff), not pre-existing at all. The failures had been sitting there, correctly
observed, for the whole session - just never actually root-caused before being waved off.
**Action:** A test failure occurring alongside a change is not "pre-existing" or "unrelated"
until that's actually been checked - diff the failing test against what the change touches,
or check whether the same tests failed before the change (e.g. on the base ref), before
describing a failure as unrelated. This is the same "verify before asserting" discipline
applied to a claim about the codebase's current state, not just a claim about a symbol's
type or behavior - see the mandatory checks in `memory/quality-gate.md`.

### IOS-025 - A stale-data fallback must distinguish "the call failed" from "the call succeeded and returned nothing" [HIGH]

**Seen (twice now, independently):** A function caught every error a remote call could throw
and converted it to `nil`, then treated that `nil` identically to "the call succeeded with an
empty result" - falling back to serving stale cached data in both cases. But a remote call
that explicitly returns nothing for a given id can legitimately mean "this record no longer
exists or is no longer visible to you" (exited, made private, deprovisioned), not just "I'm
offline" - and serving stale data in that case reintroduces exactly the staleness bug the
fallback mechanism (a verification checkpoint, in this instance) existed to prevent.
Confirmed against two live-failing tests written specifically to guard this distinction,
both broken by the same diff that introduced the swallow-and-conflate pattern. A second,
independent session hit the same underlying shape again at two separate call sites sharing
one implementation - not yet confirmed whether this is the same code path as the first
incident or a second occurrence of the same design mistake made elsewhere; treat both as the
same rule regardless.
**Action:** Keep "the call threw" and "the call succeeded but returned nothing" as two
separate branches with different fallback behavior. Only a genuine failure (a caught
exception, a connectivity error) justifies falling back to stale data past its freshness
window; an explicit empty/nil success response should be treated as authoritative and
propagated, not silently overridden by a cached value the server just told you is no longer
valid.

### IOS-026 - `async let` into a `@MainActor` call from a nonisolated context fails Swift 6 region isolation [MEDIUM]

**Seen:** Multiple tests wrote `async let x = mainActorObject.method()` from a nonisolated
test function to call into a `@MainActor` type. Swift 6's region-isolation checker rejects
this: the `async let` child task itself is nonisolated, so starting it would require sending
the main-actor-isolated value across an isolation boundary before the child task can even
begin awaiting it. Hit three times in one session across two test files once Swift 6 mode
was turned on by an unrelated merge.
**Action:** Replace `async let x = mainActorObject.method()` with
`let x = Task { @MainActor in await mainActorObject.method() }` followed by `await x.value` -
the `Task` itself carries the actor context the bare `async let` lacks.

### IOS-027 - A `@Sendable` mock closure can't capture a mutable `var` or a non-`Sendable` iterator [MEDIUM]

**Seen:** A mock's `resultProvider` closure, marked `@Sendable` (required by the protocol it
mocks), captured a local `var callCount` and a non-`Sendable` `AsyncStream` iterator directly
- both are compile errors under Swift 6's strict concurrency checking once the closure is
actually `@Sendable`-checked, since a plain captured `var` isn't safe to mutate from
whatever isolation context invokes the closure, and the iterator itself isn't `Sendable`.
Seen across three overlapping-cycle concurrency-race tests in the same file, all needing the
same fix.
**Action:** Wrap the mutable counter/gate state in a small reference type marked
`@unchecked Sendable` and guarded by a lock (e.g. `NSLock`), or use an actor, instead of
capturing a local `var` or a non-`Sendable` iterator directly inside a `@Sendable` closure.

### IOS-028 - A merged file can compile against the old shape of a type the other side changed [HIGH]

**Seen:** During a `main` merge into a long-running branch, a view model's API extension
kept calling a use case method as if it still returned the pre-merge model
(`NoteModel` with a `referencedUserIDs` property), when `main` had
changed that method's return type to a tuple and moved author resolution into the
repository. No textual merge conflict fired on this file - it merged cleanly and then failed
to compile, which is exactly the case a "resolve the conflicts" pass doesn't catch, because
there wasn't a conflict to resolve. It surfaced only because a build was run afterward, not
because anything in the merge-conflict-resolution process checked call sites of a
changed signature.
**Action:** After resolving a merge (conflicted files or not), for every type/method whose
signature changed on either side of the merge, run the cross-call-site check from
`memory/quality-gate.md` against every file the merge touched or that calls into it - not
just the files that showed textual conflicts. A clean-looking merge is not the same as a
semantically compatible one.

### IOS-029 - After any `project.pbxproj` merge, run the structural checker even without a visible conflict [MEDIUM]

**Seen (second time in the same branch's merge history):** A `project.pbxproj` merge with no
textual conflict markers still left stale group-membership entries behind (files this branch
had moved or deleted, still listed under a group in the merged file) - caught only because a
`pbxcheck.py`-style structural checker was proactively re-run out of habit from a prior
incident. The first time this happened (an earlier session in this same branch's history) it
wasn't checked proactively and broke a build.
**Action:** Treat running a `.pbxproj` structural checker (verifying every listed file
reference still exists on disk and every referenced group/target membership is consistent)
as a standing step after *any* merge that touches `project.pbxproj` - not conditional on
whether git reported a textual conflict in that file. `plutil -lint` alone does not catch
this class of staleness; it only validates plist syntax.

### IOS-030 - A root-cause claim about async/notification-driven behavior needs a confirmed log line, not just a traced call path [MEDIUM]

**Seen:** A suspected root cause for a logout/session-isolation bug was built by tracing the
call path through async and notification-driven code (a plausible sequence of what could be
calling what) rather than from an actual confirmed log line showing that sequence occurring.
Later manual testing showed the bug still reproduced - the traced path either wasn't the
actual cause, or wasn't the only one - and a previously-shared writeup describing the traced
path as the fix had already gone stale/misleading in the meantime.
**Action:** For a root-cause claim about a race, a retry loop, or any notification/async-
driven interaction, get a confirmed log line (or equivalent runtime evidence) showing the
actual sequence before presenting it as the cause - a traced call path is a hypothesis, not
a diagnosis, however plausible it reads. (Third sighting: a cause guessed from "HTML whitespace" before any log was seen; the log showed otherwise.) (Second occurrence: a "most likely" cause was
shipped as a fix and a device retest showed no change; the log then showed the real cause.
Ask for the log before proposing the fix.) State explicitly when a root cause is still a
hypothesis pending that confirmation, per the Execution-verified vs. reading-verified
distinction in `memory/quality-gate.md`.

### IOS-031 - Appending to an HTML/CSS `style` attribute needs a separator and opposite-quote escaping [HIGH]

**Seen:** Code appended additional CSS declarations into an existing `style="..."` attribute
string. Two bugs at once: the existing value had no trailing `;`, so the appended
declaration merged into the previous one's value instead of starting a new declaration;
separately, the appended text used the same quote character the attribute itself was
delimited by, closing the attribute early and leaving the rest as stray text. Both corrupted
the rendered style silently - no parse error, just wrong visual output (caught by the
person's own manual test run, not by static checks).
**Action:** When appending to an existing attribute-style string built by concatenation,
never assume the existing value already ends cleanly - add a separator (`;`) if the value
doesn't already end with one, and quote the new fragment with the opposite quote character
from the one the attribute itself uses (or escape it). Prefer building the whole value from
structured pieces and joining once, rather than repeated ad hoc string concatenation.

### IOS-032 - Restoring a file from version control must diff against current `HEAD`, not an arbitrary ancestor [HIGH]

**Seen:** A file was "restored" to an earlier commit to undo an unwanted local change, which
also silently reverted an unrelated fix that had been merged into that file since that
ancestor commit - the restore target was older than the fix, not just older than the
unwanted change. The regression wasn't caught until a later review pass compared the
restored file's actual content against current `HEAD`.
**Action:** Before restoring a file to any non-`HEAD` revision, diff that revision against
current `HEAD` for the specific file and confirm nothing landed in between that the restore
would also discard. If something did, restore then selectively reapply, don't restore
wholesale and assume the gap is empty.

### IOS-033 - BSD/macOS `sed` lacks GNU extensions and can silently no-op instead of erroring [MEDIUM]

**Seen:** A bulk find-and-delete across multiple project files used `sed` with `\|`
alternation in the pattern - a GNU extension. On macOS's BSD `sed`, the pattern simply
doesn't match anything; the command exits 0 with no error, and the files are untouched. The
run was reported as successful based on the tool's exit status and a `plutil -lint` pass
(see the quality-gate.md note on validators not being effect-checks); only a later `grep`
showed nothing had actually changed. This is the same class of GNU/BSD divergence already
hit once in `scripts/drift-check.sh`'s `date` usage.
**Action:** On macOS, assume GNU-only `sed`/`grep`/`date` syntax (`\|`, `-r` without `-E`,
`-d` on `date`) will silently do nothing rather than error - use `sed -E` for extended regex
and verify every bulk edit afterward with a `grep` confirming the target pattern is actually
gone/changed, never trust exit code or a format validator alone.

### IOS-034 - A completion-hook parameter can silently change a view's own dismiss behavior for every caller that passes one [HIGH]

**Seen:** A detail view popped itself automatically, but only in the branch where no
completion hook (`onActionCompleted`-shaped closure) was passed in; once any caller
started passing that hook (to react to the completion itself), the view's own self-pop
branch was skipped on the assumption the caller would now handle navigation - but the caller
didn't, leaving the screen open after an action that should have dismissed it.
**Action:** When a view's own dismiss/pop behavior is conditioned on whether an optional
completion hook was supplied, treat that as a contract change for every caller passing the
hook, not just the one being written - audit each caller to confirm it actually performs
the pop/dismiss the no-hook path used to do implicitly, or document explicitly that passing
the hook opts out of auto-dismiss and callers must handle it themselves.

### IOS-035 - Deleting a legacy screen needs its privilege/permission checks grepped and confirmed present in the replacement [HIGH]

**Seen:** A legacy view model enforced privilege-gated actions (e.g. `allowActionA`,
`allowActionB` controlling whether a cancel action was shown) that existed only in that
legacy code - not yet ported to the replacement screen being built to retire it. Found
during a parity check partway through the retirement, not before it started, because the
first pass checked navigation/feature parity but not permission-check parity specifically.
**Action:** Before deleting or retiring a legacy screen/view-model, grep it specifically for
privilege/permission/feature-flag checks (not just business logic) and confirm the
replacement enforces each one - permission gating is easy to miss in a parity review because
its absence doesn't crash or look broken, it just silently widens who can do what.
A deep link or router rebuilt on a new screen: see IOS-039 for the argument comparison.

### IOS-036 - Decide ownership from the loaded record, never from an absent id or the entry route [MEDIUM]

**Seen:** A detail screen treated a record as the user's own - offering self-only actions -
because `ownerId == nil`, an inference from the way the screen was opened rather than a
check on the loaded record. Reached through a deep link, the same screen could be showing
someone else's record with the self-only actions still on offer: a latent permission
widening. The risky case ("the loaded record belongs to someone else") had no test, and the
same inference was made at more than one site. Three reviewer comments on one PR; the sibling
check had been run on one instance only.
**Action:** Decide "is this mine?" by comparing the loaded record's owner id to the current
user's id - not from an id being nil, a flag set by the caller, or the entry route. Write
the "someone else's record" test explicitly (IOS-016), and run the sibling check over every
place the same inference is made. If the API might omit the owner id, confirm it always
returns it before relying on it, and treat a missing owner id as "not mine".

### IOS-037 - Set every input before an `init` starts async work [MEDIUM]

**Seen:** A view model's `init` kicked off asynchronous loading before all of its inputs had
been assigned, so the started work could observe a partially configured object. Raised by a
reviewer on a PR (details beyond the pattern were not retained in the report).
**Action:** In an initializer, assign every stored property and input first; start async or
observable work last, or move it to an explicit `start()`/`load()` the owner calls once the
object is fully built.

### IOS-038 - Derive a test's expected value from the requirement, never from what the code returns [MEDIUM]

**Seen:** A test asserted `"Hi </span> there"` - malformed HTML the code itself produced - so
it passed while locking in the bug. The expected value had been copied from the
implementation's output. A human reviewer found it.
**Action:** Write the expected value from the requirement or from a well-formed reference
(balanced tags, valid JSON, a hand-computed number). If a test would also pass on the buggy
behavior, it asserts nothing. When an assertion string looks odd, check it is something the
requirement would allow.

### IOS-039 - A new call site of an existing initializer must be diffed against every existing call site [HIGH]

**Seen:** A deep-link route built a detail display model without
`currentUserID`, which every feed route passes; header and comment rights
broke. Earlier in the same line of work a rebuilt deep link also dropped `showPrivilegedActions`
and the status the legacy call received, losing the approver case. Both found by human
reviewers, not by the author's checks.
**Action:** For every new construction of a type or call of an API that other routes already
use, list the arguments each existing call site passes and account for each one the new
call leaves out (needed, defaulted safely, or deliberately dropped - and say which). Also
compare against the legacy call when a screen is being replaced.

### IOS-040 - A value captured once must be checked against every later mutation in the same flow [MEDIUM]

**Seen:** A chat input took `type` at creation while `setData` changed `type` a few lines
later, so the input was built for the wrong mode; a `@StateObject` read the author id
once, before the response that supplies it. Companion to IOS-037 (inputs before async work).
**Action:** For any value captured at init, by `@StateObject`, or by a closure, trace every
later write to its source in the same flow. If the source can change after capture, resolve
it first, make the consumer observe it, or delay building the consumer until it is known.

### IOS-041 - When a field's source changes, sweep every test that asserts that field [MEDIUM]

**Seen:** Sending parsed tags instead of `tagData.tags` broke an existing converter
test in CI that the author had not run or searched for.
**Action:** After changing where a field's value comes from or what it means, grep the test
targets for every assertion on that field and classify each as still valid, to update, or
now meaningless. Do it before pushing, not after CI.

### IOS-042 - A non-editable inline element at the end of editable web content loses its caret anchor [LOW]

**Seen:** In a web-view editor, deleting the last character after a `contenteditable=false`
tag made WebKit drop the empty caret span, leaving a visible gap and a first backspace that
only moved the caret. Only a Swift-side restore was possible; a clean fix needs key handling
in JavaScript the package does not expose. Shipped as a known limitation.
**Action:** Keep a caret anchor after non-editable inline elements and restore it when
removed. When restoring, locate the affected tag by identity (the unchanged tag that lost
its span), not by a diff start position - prefix/suffix diffs are ambiguous when neighbouring
characters match. Record the limitation instead of stacking more patches.

### IOS-043 - New logic must ship with tests that compile into a target and count toward the CI diff-coverage gate [MEDIUM]

**Seen:** A feature added about ten new functions and adapters without tests; CI's 90%
diff-coverage gate failed at 88% only after the push. Separately, a planned test file sat in
a folder that is in no Xcode target (some test folders are plain groups needing manual
`pbxproj` entries, some are file-system-synchronized, some are in no project), so it would
never have run. Two unreachable `default:` branches also counted as uncovered lines.
**Action:** While writing code, add its tests in the same task. Before writing a test file,
confirm its folder belongs to a compiled target (check the project file). Know the repo's
diff-coverage threshold, run the coverage tool locally if one exists, and fix uncovered new
lines (including unreachable branches) before pushing.

### IOS-044 - A numeric text field bound straight to a stored number eats partial input [MEDIUM]

**Seen:** An hours field showed a stored `0` as an empty string and re-rendered the number on
every keystroke. Typing `0`, then `.`, then `5` wiped the `0` and the `.` (neither parses on
its own), so `0.5` was saved as `5`. A client reported it. The first root-cause note blamed
the decimal limit; only keystroke sequences that start with `0` or `.` expose it.
**Action:** Keep the typed text in view state while it still parses to the stored value;
normalise only on blur or submit. Test keystroke sequences, not just final values: starting
with `0`, starting with `.`, ending in `.`, and clearing the field.

### IOS-045 - Seeding state that used to be empty needs invalidation on every input it depends on [HIGH]

**Seen:** An Edit screen started passing a record's saved hourly details where it used to
pass `[]`. Changing the dates never cleared them, so the hours sheet showed the old days and
the request sent hours for dates outside the new range. A reviewer's suggested fix cleared one
of the two lists that held the same data; the old days would have come back from the other.
**Action:** When a value that was always empty becomes populated, grep every reader of it and
every input it depends on (dates, type, selection) and clear or rebuild it when those change.
Clear all copies of the data, not the one the comment names. Test: change the input and
assert the seeded value is gone; reselect the same input and assert it is kept.

### IOS-046 - `==` on a type with associated values may compare less than you think [MEDIUM]

**Seen:** A feature gated on `deskType == .inbox` worked in one flow and silently never fired
in another, because the type's hand-written `==` compared only raw values and treated cases
carrying associated values as unequal to the plain case.
**Action:** Before relying on `==` (or `!=`, `contains`, a `Set`) for an enum or struct with
associated values or a custom `Equatable`, read the `==` implementation. Prefer a `switch` or
`if case` on the case you mean.

### IOS-047 - A rule applied on one path must be checked on every entry point, surface and row type [HIGH]

**Seen:** One feature's rules were each applied on only one path: a closed-ticket check ran
for list entry but not a deep link; a "no results" state and a self-tag block existed on one
screen but not a sibling screen sharing the component; a self-exclusion matched person rows
but not people reached through a role row. Each was found by someone else after "done".
**Action:** For every rule in the spec, list the entry points (list, push, deep link, restore),
the surfaces that share the component, and the row/item types, and confirm the rule on each.
When a reviewer says "niche case", read how the existing path computes the value before
deciding it is out of scope.

### IOS-048 - New UI built from an API shape should be compared with other platforms and the design before building [MEDIUM]

**Seen:** Suggestion rows were built one per person straight from the API payload, so a role
held by two people showed twice; web and Android showed one row per role. A label was reused
from an existing string ("Department head") and differed from the design's casing. Both came
back as QA bugs.
**Action:** If web or Android already ships the feature, compare how it presents real data
(grouping, duplicates, empty states, labels) before building rows from the payload, and check
labels against the design file. Test with data that has two items sharing a group.

### IOS-049 - A build that fails after a branch switch with a toolchain-mismatch message may be stale precompiled modules [LOW]

**Seen:** After switching branches, the test build failed on a precompiled framework module
and reported a Swift toolchain mismatch. The toolchain was fine; the cached explicit
precompiled modules were stale.
**Action:** Before debugging the toolchain, delete the project's `SwiftExplicitPrecompiledModules`
folder inside DerivedData (or clean DerivedData) and rebuild.

### IOS-050 - `@unknown default` turns a missing case into a warning, not an error [MEDIUM]

**Seen:** A `switch` over an enum from the app's own module ended in `@unknown default`. When a
new case was added later, the build still passed and the new case fell through to the default
branch without anyone noticing. `@unknown default` makes a missing known case a warning instead
of an error, and on an enum without library evolution it can also warn that the default will
never run.
**Action:** Use `@unknown default` only for enums from the SDK or a library that can grow. For
enums in your own modules, write an exhaustive `switch` with no default, so adding a case breaks
the build at every switch that needs a decision.

### IOS-051 - A tone drawn as text, border and background at once must be readable in every combination [MEDIUM]

**Seen:** A status tone was applied to a label's text colour, border and fill together. One tone,
and the fallback tone used when the value was unknown, were nearly unreadable in dark mode
because the three colours were close to each other.
**Action:** For any style that colours text, border and background from one value, check every
tone, including the fallback, in light and dark, at every place it is drawn. Look at the
fallback tone first: it is the one nobody designs for.

### IOS-052 - After moving a type out of a file, remove the imports only that type needed [LOW]

**Seen:** A type was moved into its own file. The old file kept the imports the moved type had
needed, so it kept depending on modules it no longer used. Swift does not warn about unused
imports, so nothing flagged it.
**Action:** When a type moves, list the imports it used and remove each from the old file if no
remaining code there needs it. Check the new file imports what it needs and nothing more.

### IOS-053 - HTML-to-attributed-string import inside a SwiftUI `body` can abort the app [HIGH]

**Seen:** A view converted an HTML string to rich text with the system HTML importer from inside
`body`. That importer is built on the web engine and spins the main run loop while it works, so
the view graph was re-entered mid-update and the app aborted in the attribute graph.
**Action:** Never call the system HTML importer from a view's `body` or any code `body` runs.
Convert once, outside `body` (when the model loads), or use a converter that does not use the web
engine. Check every call site, not just the one that crashed.

### IOS-054 - List every producer of an input before narrowing the code that parses it [MEDIUM]

**Seen:** A text converter was written for output from one rich-text editor. The same field was
also fed by archived email templates containing tables, a head section, comments and link tags.
A reviewer found four behaviours the converter got wrong; the author had assumed one source.
**Action:** Before writing or narrowing a parser, name every place the field is written from
(editors, imports, backend templates, migrations) and test one sample from each. Put the
assumption about the input in the spec's "Decisions & why", with the sources checked.

### IOS-055 - A promise fulfilled off the main actor must not reach main-actor code directly [HIGH]

**Seen:** A Combine `Future` was fulfilled from a background pool and its result flowed straight
into `@MainActor` code. The runtime's queue assertion failed and the app crashed on one of the
failure paths, which no test covered.
**Action:** Deliver publisher results on the main actor explicitly before they reach UI code.
Test the success path and every failure path with the delivery thread asserted, not just the
success path.

### IOS-056 - Changing a shared enum's raw values or order must name every client and migrate saved data [HIGH]

**Seen:** The backend and the web client reversed the order of a rating enum together. A shared
mobile module was missed and kept the old order, so ratings saved from mobile came out inverted.
Data saved before the change is also inverted unless a migration converts it.
**Action:** A contract change to enum raw values or ordering lists every client that reads or
writes it (web, each mobile app, shared modules) and states what happens to data already saved.
Prefer sending explicit names over ordinals.

### IOS-057 - Crash reports from framework targets merge into one issue when their symbol files are missing [LOW]

**Seen:** Two unrelated crashes (a networking one and a migration one) landed in the same
crash-reporting issue because the frameworks' debug symbols were not uploaded, so frames showed
the same unsymbolicated memory-copy function.
**Action:** Upload symbol files for every framework target, not only the app target. When a
crash issue's frames look generic, check symbolication before concluding two reports share a
cause.

### IOS-058 - Inserting at a fixed index into an array another path can empty traps [HIGH]

**Seen:** A screen built its card list by inserting a card at a fixed position. A settings call
elsewhere cleared the same array, so a later insert at position 1 ran against an empty array and
trapped with index out of range. The trigger was timing, so it was hard to reproduce.
**Action:** Do not insert at fixed positions into a list that other code can reset. Rebuild the
derived list in a fixed order from current state, or guard with the array's count. Search for
every writer of the array before deciding it is always populated.

### IOS-059 - A claim written into a fix is a check to run, not a fact [MEDIUM]

**Seen:** A fix added defensive layout code on the stated reason that a configuration callback
"can arrive more than once". The callback had one caller, called once, so the change did nothing
and QE notes were written for a behaviour that could not happen.
**Action:** For each defensive change, find every caller that would make its premise true. If
there is none, drop the change. Name the evidence the fix addresses (crash frame, breadcrumb,
log line) and check the change sits on that path before describing it as a fix.

### IOS-060 - A debugger exception breakpoint pauses on caught exceptions and looks like a crash [LOW]

**Seen:** A reported crash in a screen backed by a cross-platform module had no crash report. The
app had stopped because an all-exceptions breakpoint paused on an exception the module throws
and catches normally, and the app was then reinstalled by the IDE.
**Action:** Before treating a stop as a crash, check for a crash report, or rerun without the
debugger attached or with exception breakpoints off. Ask for the backtrace and the console lines.

### IOS-061 - `Identifiable` keyed on a server id that can be zero gives every row the same identity [MEDIUM]

**Seen:** A list model used the server's `id` for `Identifiable`. A new payload shape sends `0`
for every item, so all rows shared one identity and the list misbehaved; analytics also lost a
field that had come from the old shape.
**Action:** When a payload shape can change, derive a stable id in the mapping layer (for
example a prefix plus the underlying id) instead of using a server value that may be zero or
repeated. Test a list with two items that share the raw id.

### IOS-062 - Resetting a navigation flag right after the push allows a double push [MEDIUM]

**Seen:** A button set a "navigating" flag, pushed a screen, and cleared the flag in the same
call. A fast second tap ran before the first screen was on the stack, so the destination was
pushed twice.
**Action:** Clear the guard when the destination actually appears or is dismissed, not when the
push is issued. Check the other entry points that reach the same destination. Test a double tap.

### IOS-063 - After an async fetch, re-check the account before saving [HIGH]

**Seen:** A background fetch wrote settings to local storage when it finished. If the user had
logged out or switched tenant meanwhile, the data landed in the next account's storage. A copy
step also carried settings from one tenant's cache to another.
**Action:** Capture the account or tenant key before the request and compare it with the current
one before any write, or key the cache by account. For every new async write, ask what happens
after logout. Search for code that copies settings between accounts.

### IOS-064 - A new app extension or widget needs its own checklist [MEDIUM]

**Seen:** New widgets shipped with missing localisation, absent plist keys, no stated refresh
cadence, a signing variable defined for one pipeline only, and local data cleared on logout
that the widget kept reading.
**Action:** For each new extension, check: string catalog entries, Info.plist keys, refresh
policy, signing and provisioning in every pipeline, shared storage and what clears it on
logout or tenant change, and the layer the extension target is allowed to import.
