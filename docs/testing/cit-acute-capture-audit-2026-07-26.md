# CIT — vertical-slice audit: Reaction now / acute capture

**Slice:** #7 acute capture · **Priority:** P0 · **Date:** 2026-07-26
**Method:** `vertical-slice-audit` skill, Phase 2 full chain walk
**Verdict class:** `VERIFIED-CODE` (static). No build was run — nothing here is `VERIFIED-RUN`.

**Provenance**
- native: `bas-apps` @ `4a5ef1b` (master) — `apps/cit`
- web: `Chronic-Illness-Tracker` @ `458571e` (fix/ios-home-screen-title)

**Surfaces covered:** native iOS source. Android source is shared (same files) but no
platform-specific behavior was checked. Web was read only for the parity link.

---

## REVISION 2026-07-26 — audited against stale checkouts

A parallel Codex audit surfaced that **both checkouts above are behind what is shipped**, and I
verified that independently:

- native `4a5ef1b` is behind `origin/master`; the shipped OTA is **`68ab379`** (EAS build 22 at
  `c57c516`). Both commits exist locally and were read directly.
- web `458571e` is on branch `fix/ios-home-screen-title`, and `git merge-base --is-ancestor 51afc45
  HEAD` returns **false** — this checkout is not merely behind production, it is *divergent* and has
  never contained the production commit. The repo's default branch is `main`, not `master`.

Consequences for this document, applied inline below:

- **F-2 is FIXED in shipped source** (`68ab379`). Superseded; retained for the method lesson.
- **Link 2 (Navigation) — my PASS was WRONG.** See the revised row.
- **F-1 is CONFIRMED LIVE**: re-read at production `51afc45`, the leak is still on line 85.
- **F-4 is half-closed** by the shipped OTA. See the revised finding.

**Method lesson (the important one):** I marked link 2 PASS because the Cancel `Pressable` was
present in the JSX. The shipped fix commit records that `presentation: 'modal'`, set from an
in-component `<Stack.Screen>`, *suppressed the header entirely* — taking Cancel with it — so the
screen had **no exit at all except saving**. A user who opened Reaction now mid-reaction and could
not type (F-2) was trapped. That is strictly worse than anything this audit reported, and a static
read cannot see it: **presence in JSX is not evidence of rendering.** Any link whose verdict depends
on what actually renders must be `UNVERIFIED`, never `PASS`, in a `VERIFIED-CODE` pass. This applies
to links 1, 2, 3 and 11 as a class.

---

## Chain

| # | Link | Verdict | Evidence |
|---|---|---|---|
| 1 | Entry point | PASS | `apps/cit/src/app/app/index.tsx:22` — primary button on home, one tap, always visible (no gating needed) |
| 2 | Navigation | ~~PASS~~ → **FAIL (audited stale; fixed in `68ab379`)** | Cancel was present in JSX at `acute.tsx:54-63` but `presentation:'modal'` suppressed the header, so it **did not render** — no exit but Save. My PASS was wrong; see Revision |
| 3 | Initial state | PASS (code) / UNVERIFIED (render) | `acute.tsx:23-26` — `openedAt` lazy-init once at mount; name `''`; saving `false`; error `null` |
| 4 | Input | **FAIL (fixed in `68ab379`)** | `acute.tsx:46-65` — see **F-2** |
| 5 | Validation | PASS | client `disabled={!name.trim()}` `acute.tsx:85`; server `symptomName: z.string().min(1).max(200)` `schemas.ts:106`. Note N-1 |
| 6 | Draft | N-A | Deliberate, documented `acute.tsx:10-16`. Contrast `log-symptom.tsx:81` which does draft. Risk R-1 |
| 7 | Request | PASS | `entries.ts:37` → `POST /entries/symptoms`, body `{symptomName, isAcuteCapture:true, timestamp:openedAt}` `acute.tsx:32-36` |
| 8 | Authz | PASS | `symptoms/route.ts:44` `requireAuth()`; bearer resolved per-request from secure storage `http.ts:78-81`, `cit.ts:19-21` |
| 9 | Persistence | PASS | `schema.prisma:257` `isAcuteCapture Boolean @default(false)`; `route.ts:80` honors supplied timestamp |
| 10 | Idempotency | **FAIL** | see **F-4** |
| 11 | Success feedback | **FAIL** | `acute.tsx:37` — `router.back()` only, nothing announced. See **F-5** |
| 12 | Failure path | PARTIAL | `acute.tsx:38-41` — input + `openedAt` preserved, retry reachable ✓; announcement fails, see **F-5** |
| 13 | Read-back | **FAIL** | `review.tsx:44-52` never reads `isAcuteCapture`. See **F-3** |
| 14 | Mutation | NOT-BUILT | No edit path for a symptom entry on native |
| 15 | Deletion | PASS (server) / NOT-BUILT (native) | `symptoms/[id]/route.ts:13-18` ownership-checked (`findFirst {id,userId}` → 404); client `remove()` exists `entries.ts:39`; **no native UI calls it** |
| 16 | Export | PASS (web) / NOT-BUILT (native) | `src/lib/export/index.ts:255` `acute: s.isAcuteCapture ? 'yes' : ''`; column asserted `tests/unit/export.test.ts:30` |
| 17 | Account deletion | PASS | `delete-account/route.ts:57` `prisma.user.delete` + `schema.prisma:263` `onDelete: Cascade` |
| 18 | Leakage | **FAIL** | see **F-1** (P0) and **F-7** (web-adjacent) |
| 19 | Parity | **FAIL** | web review labels it a reaction (`review/page.tsx:291-292`); native does not. Regression, not a gap |
| 20 | Tests | **FAIL** | see **F-6** |

---

## Findings

### F-1 · P0 · **CONFIRMED LIVE IN PRODUCTION** · PHI written to production logs, bypassing the project's own PHI guard

> Re-verified 2026-07-26 against production commit `51afc45` — line 85 is unchanged there. This is
> live now. A parallel Codex audit that ran 489 web tests, a real-Postgres suite, dependency audits,
> security-header checks and a production log review did **not** surface it, and reported
> *"production runtime logs showed no application errors"* — true, and orthogonal: this is an
> `info`-level line, not an error. Nothing in the current gate looks at what `info` logs contain.

`src/app/api/entries/symptoms/route.ts:85`
```js
logger.info('Symptom entry created', { userId, entryId: entry.id, isAcute: data.isAcuteCapture });
```
`isAcuteCapture` is explicitly classified as PHI in `src/lib/logger/index.ts:104`, under the comment
*"Booleans that assert a health fact about the user, not a preference."* The redactor
(`sanitize()`, `logger/index.ts:169-178`) matches **exact object keys** against `PHI_FIELD_SET`. The
key here is `isAcute` — not in the set. The boolean is not a string, so `scrubString()` never sees
it either. Production log level is `info` (`logger/index.ts:16`), so this line emits.

**Failure scenario:** a user taps "Reaction now" and saves. Production stderr receives
`{"userId":"clx…","entryId":"clz…","isAcute":true}` — a durable, user-identified assertion that this
person had an acute reaction at that timestamp. Exactly what non-negotiable #3 forbids.

**Why the guard missed it:** `tests/unit/phi-fields-drift.test.ts` reconciles *Prisma columns* against
`PHI_FIELDS`. It has no visibility into log **call sites**, so renaming a field at the call site
silently defeats it. The same pattern would hide any PHI field under an abbreviation.

**Fix:** log `isAcute: undefined` out entirely (the entryId is sufficient for diagnostics), or use the
exact key `isAcuteCapture` so redaction fires. The durable fix is a lint rule or drift-test extension
that flags `logger.*` payload keys not in `SAFE_FIELDS ∪ PHI_FIELDS`.

### F-2 · P0 · ~~Acute screen reconfigures navigation on every keystroke~~ — **FIXED IN SHIPPED SOURCE**
`apps/cit/src/app/acute.tsx:46-65` (as audited, `4a5ef1b`) → fixed in `68ab379`

> **Superseded.** The shipped fix memoizes `screenOptions` with all-primitive deps, drops
> `presentation` entirely, and calls expo-router's module-level `router` singleton in `headerLeft`
> so the closure needs no dep. The commit records a simulator reproduction of the exact mechanism I
> inferred: *"with the inline version, 13 typed characters produced an empty field; memoized, the
> same input types normally."* The static differential below was correct and is kept as the record
> of how it was found from source alone — but note it was found in code that had **already been
> fixed upstream**, which is a checkout-hygiene failure, not an analysis success.


The `<Stack.Screen options={{…}}>` object literal is constructed inside the render body, so every
keystroke (`setName` → rerender) hands React Navigation a **new options object containing a new
`headerLeft` closure**, and re-asserts `presentation: 'modal'`.

This screen is the **only** one in the app that does either thing. Every other screen passes a flat
object of primitives: `log-symptom.tsx:77`, `log-food.tsx:66`, `log-prn.tsx:65`, `log-note.tsx:58`,
`regimen.tsx:119` — all `{ headerShown: true, title: … }`. And `presentation` appears exactly once in
the entire source tree, at `acute.tsx:50`. The one screen with a reported typing defect is the one
screen doing something different in its options.

`presentation` is a mount-time native-stack property; re-asserting it after mount is the mechanism
most likely to re-present the screen, which would drop the keyboard and re-trigger `autoFocus`
(`acute.tsx:76`) into a focus fight.

**Failure scenario (reported, not yet reproduced by this audit):** type three characters into
"Reacting to" — the keyboard dismisses and characters are dropped mid-reaction.

**Confidence:** the anti-pattern is CONFIRMED by reading. The causal link to the observed symptom is
PLAUSIBLE and needs a device run to settle — that run is the single highest-value next step.

**Fix:** hoist the options object to module scope, injecting only what is static; where the Cancel
button needs `router`, memoize with `useCallback`/`useMemo` so identity is stable across renders. Set
`presentation: 'modal'` **declaratively in the layout** (`src/app/_layout.tsx:14`, as
`<Stack.Screen name="acute" options={{presentation:'modal'}} />`) rather than from inside the screen.

### F-3 · P1 · Review cannot distinguish an acute capture from an ordinary symptom (parity regression)
`apps/cit/src/app/app/review.tsx:44-52`

The timeline maps symptoms to `{title: symptomName, detail: severity ?? freeformNotes}` and never
reads `isAcuteCapture`. An acute capture has neither severity nor notes (the screen collects only a
name), so `detail` resolves to `null`.

**Failure scenario:** a user logs "flushing" via Reaction now, then logs "flushing" later as a routine
symptom. In native review both render as an identical bare row — the acute flag, the whole point of
the capture, is invisible. Web gets this right (`review/page.tsx:291-292` renders a `reaction`
kindLabel and an `isAcute` prop), so this is a **native parity regression**, not an unbuilt feature.

Two adjacent read-back limits, in scope for this link: review is capped at `WINDOW_DAYS = 7`
(`review.tsx:17`), and day grouping uses **device** timezone (`dates.ts:11-16`, `getFullYear/Month/Date`)
rather than the account's timezone preference — a traveling user sees different day buckets on native
than on web. Both affect every entry type, not just acute; flagged here, to be owned by slice #19.

### F-4 · P1 · No idempotency and no request timeout
`acute.tsx:28-42`, `http.ts:83-88`

Double-tap is prevented client-side (`Button` computes `isDisabled = disabled || loading`,
`components.tsx:58`), and that is the only protection. There is no server-side dedup and no
`AbortSignal` — `http.ts` accepts `opts.signal` (`http.ts:33`) but `acute.tsx` passes none.

**Failure scenario A (duplicate):** save on a flaky connection; the request reaches the server and
creates the row, the response is lost. The user is still on the screen with an error and taps Save
again → two acute records at the same frozen timestamp.
**Failure scenario B (hang):** the request never settles. `saving` stays `true` forever, Save is
permanently disabled, and the only exit is Cancel — which discards the entry, with no draft (R-1) to
recover it.

**Fix:** pass an `AbortSignal` with a timeout so a hung save fails into the existing error path; for
the duplicate, an idempotency key on the create is the durable answer.

> **Revised 2026-07-26.** Scenario B (hang) is **closed** in shipped source: `68ab379` adds a
> `DEFAULT_TIMEOUT_MS` deadline at the http layer (`packages/api/src/http.ts`, AbortController +
> setTimeout, with a `TimeoutError` distinct from caller-initiated abort), so it covers the acute
> save without any change to `acute.tsx`. `apiErrorMessage` has no `TimeoutError` branch, so it
> falls through to `networkError` — acceptable copy, worth a dedicated string later.
> Scenario A (duplicate) is **still open**, and the deadline makes it *more* reachable: a request
> that reached the server but timed out client-side now surfaces an error and invites the retry that
> creates the second row. An idempotency key is now the remaining work.

### F-5 · P1 · Neither success nor failure is announced to a screen reader
`acute.tsx:37` (success), `acute.tsx:79-83` (error)

Success calls `router.back()` with no announcement. The error uses `accessibilityRole="alert"` — which
on React Native **marks a trait but does not announce**, on either platform (see the RN caveat in
`bas-design-review`). Announcing requires `AccessibilityInfo.announceForAccessibility`, with a delay
so the layout pass doesn't truncate it.

**Failure scenario:** a VoiceOver user saves a reaction. Nothing is spoken; the modal closes. On
failure, nothing is spoken and the error text sits below the field unread. The user cannot tell
whether their reaction was recorded — during a reaction.

### F-6 · P1 · The native app has no test suite at all
`apps/cit/package.json` — scripts are `start / android / ios / web / typecheck / lint`; devDependencies
are `@types/react, eslint, eslint-config-expo, typescript`. No jest, no vitest, no test files anywhere
under `apps/cit`.

Every native verdict above is therefore static-only by necessity, and no native regression can be
caught by CI. The web side has real coverage for this slice (`tests/e2e/critical-paths.test.ts:303-314`
asserts `isAcuteCapture: true` reaches `prisma.create`; `tests/unit/export.test.ts:30` asserts the
`acute` export column) — the gap is native-specific.

### F-7 · P2 · Web puts the acute flag in a URL (adjacent — web, not this slice's surface)
`src/app/(app)/log/page.tsx:25` — `params.acute === 'true'`, i.e. `/log?acute=true`.

By the project's own classification (`logger/index.ts:104`, "booleans that assert a health fact"), this
is the same class of data F-1 protects, and URLs reach server access logs, browser history and
referrer headers. Slice #7's own criterion is "no health information appears in logs, URLs or
telemetry." Surfaced by the parity check; belongs to a web slice to fix.

---

## Notes and risks (not findings)

- **N-1** A `symptomName` over 200 chars passes the client and fails server-side as a generic
  `validation` message (`errors.ts:14`) with no field-level guidance. Low impact for this screen —
  a reaction name is short — but the mapping is lossy for every form using it.
- **R-1** The deliberate no-draft choice (`acute.tsx:10-16`) is defensible in isolation, but it
  compounds with F-4-B: a hung save gives the user no route that preserves the entry. Re-evaluate the
  choice against that combination rather than on its own.

---

## Not covered

Everything below needs a device or a second account and is `UNVERIFIED`:

- **The F-2 reproduction itself** — build 22 on device, type into "Reacting to".
- VoiceOver and TalkBack passes; large-text (the screen uses a centered `flex:1` `View` with no
  `ScrollView` — unlike `log-symptom.tsx:78`, which sets `keyboardShouldPersistTaps="handled"` — so
  under a raised keyboard at large text sizes the Save button may be unreachable).
- One-handed reachability of the home entry point; focus restoration to the trigger after Cancel.
- Connection-lost-during-save; slow connection; the F-4 duplicate and hang scenarios.
- Android behavior; timezone/DST behavior against a real account preference; expired-session save.
- Light/dark contrast verification on device.

---

## Cross-check against the parallel Codex audit (2026-07-26)

Codex's two check-in P0s were **independently confirmed by reading the source**, not relayed:

- **Schedule values generate no dose slots** — `check-in/route.ts:47` is
  `regimenItems.map(...)`, one row per regimen item per day, and the lookup key is
  `` `${item.id}:` `` (empty `scheduledTime`). `schedule` is returned as a display field and never
  expanded. BID/TID collapse to one toggle; WEEKLY/CUSTOM appear daily. Confirmed.
- **Stale metadata survives a status change** — the `update:` block (`route.ts:137-142`) passes
  `skipReason` / `skipReasonFreeform` / `doseTakenOverride` straight through, and Prisma reads
  `undefined` as "leave unchanged" (only `null` clears). SKIPPED→TAKEN keeps `RAN_OUT`. Confirmed by
  reading; Codex additionally confirmed it against real Postgres. Fix is status-specific clearing
  (`update.status === 'SKIPPED' ? update.skipReason ?? null : null`), not `?? undefined`.

Neither audit found the other's P0s. The split is structural, not a matter of thoroughness: Codex
ran the suites, the builds and the production surface, and caught defects that only appear when rows
actually round-trip a database. This audit walked one slice's boundaries in source, and caught a leak
that no green test asserts against. The `isAcute` rename defeats `phi-fields-drift.test.ts` *by
construction*, so no amount of test-running finds it.

---

## Verdict

**BLOCKED**, on **F-1 alone** after revision.

- **F-1** is a confirmed P0 privacy defect **live in production right now** (`51afc45`), fixable
  today: a one-line change, plus a guard extension so the class cannot recur.
- **F-2** is fixed in shipped source (`68ab379`) — no longer gating.

F-3 through F-6 are P1 and should not gate on their own, but F-3 is a parity regression against
already-correct web behavior and is cheap to close.

Codex's two check-in P0s are separately gating and are not scored here — they belong to slices #4
and #5, and this audit's one-slice-at-a-time rule means they get their own walk rather than being
absorbed into this one.

This audit inspected and named every boundary in the chain. It does not establish that the slice is
bug-free, and no passing checklist could.
