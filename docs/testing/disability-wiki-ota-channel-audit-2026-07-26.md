# Vertical-slice audit — Disability Wiki OTA content-update channel

**Date:** 2026-07-26 · **Commit audited:** `332772ec` (main) · **Slice:** signed OTA content channel
**Verdict class:** mixed — `VERIFIED-RUN` for links exercised in the iOS Simulator earlier today,
`VERIFIED-CODE` for links read only, `UNVERIFIED` where a device or a real failure is required.
**Auditor bias disclosure:** this channel was rebuilt by the same session, the same day
([DW #71](https://github.com/BeauAccessSolutions/disability-wiki/pull/71)). This is a self-audit and
should be read as one; the walk was deliberately weighted toward what the rebuild might have missed.

**Slice scope.** The chain a corrected crisis hotline number travels to reach an installed app
without App Review: publish → manifest+signature → client fetch → integrity check → stage →
activate → serve → roll back. Not in scope: the web site's own delivery, the app's native
affordances, App Store submission.

---

## Why this slice's chain differs from a data-entry slice

Nine of the standard twenty links are genuinely `N-A` here: there is no account, no database, no
user input beyond one button, no draft, no export, no account deletion, no PHI. They are marked
`N-A` rather than `PASS` — an absent boundary is not a passed one. The links that *do* apply map
onto analogues: **authz → signature verification**, **persistence → content root + pointer**,
**idempotency → repeated staging of the same build**, **read-back → what the WebView serves**,
**deletion → rollback**.

---

## Chain

| # | Link | Location | Verdict |
|---|---|---|---|
| 1 | Entry point | `WikiRouter.swift:129,133` (launch) · `NativeAffordances.swift:191` (Check now) | PASS · VERIFIED-RUN |
| 2 | Surfacing | StatusSheet via long-press Crisis button / quick action | PASS · quick-action path UNVERIFIED (springboard menu not drivable in sim) |
| 3 | Initial state | `OTAUpdater.swift:246` "No update check yet" | PASS · VERIFIED-CODE |
| 4 | Input | — | N-A (no user-supplied data) |
| 5 | Validation | `OTAUpdater.swift:452-476` schema 1\|2, path prefix/`..`/trailing-slash, 64-char lowercase hex sha, size ≥ 0 | PASS · VERIFIED-CODE |
| 6 | Draft | — | N-A |
| 7 | Request | `OTAUpdater.swift:336,337,386` — manifest, sig, blobs; ephemeral session | PASS · VERIFIED-RUN |
| 8 | Authz analogue — signature | `OTAUpdater.swift:338-344` verify **before** parse | PASS · VERIFIED-RUN (tampered sig → `signatureRejected`) |
| 9 | Persistence | staging → `moveItem` → `finalRoot` → pointer write | PASS · VERIFIED-RUN |
| 10 | Idempotency | `versionName` derived from `manifest.builtAt`; `removeItem` + `moveItem` | PASS · VERIFIED-CODE |
| 11 | Success feedback | status sheet; "Update ready — close and reopen" | PASS · VERIFIED-RUN |
| 12 | Failure path | 8 outcomes + detail line | PARTIAL — 4 of 8 exercised (see matrix) |
| 13 | Read-back | WebView serves the OTA root | PASS · VERIFIED-RUN (sentinel rendered from a root present in no bundle) |
| 14 | Integrity of mutation | staging loop iterates the **new** manifest, so upstream deletions propagate | PASS · VERIFIED-CODE |
| 15 | Deletion analogue — rollback | `OTAUpdater.swift:140-150` current → previous → bundle | UNVERIFIED — proven 2026-07-23, **not re-run since the refactor** |
| 16 | Export | — | N-A |
| 17 | Account deletion | — | N-A |
| 18 | Leakage | logs carry paths, hashes, dates only | PASS · VERIFIED-CODE |
| 19 | Parity | iOS only; Android deferred | N-A |
| 20 | Tests | publish side covered; **client has none** | **FAIL — F-3** |
| + | Bundle-integrity interaction | no OTA counterpart to the build-time contribute tripwire | **FAIL — F-1** |
| + | Re-entrancy | two entry points, one shared staging path, no guard | **FAIL — F-2** |

---

## Findings

### F-1 · P1 · OTA silently reverts the in-app contribute hand-off — and will fire on the next update

`app/tools/native-contribute.mjs` rewrites the bundled `/contribute` page into a live-site hand-off,
because the web page's two forms POST to a **relative** `/api/contributions` that 404s under
`capacitor://localhost` (remediation-plan finding #2, P1, marked resolved). `verify-bundle.mjs`
enforces it — **at build time only**. Nothing re-applies or re-checks it after an OTA update.

`/contribute/index.html` is in the OTA manifest (`sha=a6a9b37af3`), and the live page still carries
`action="/api/contributions"`. Whenever that page's bytes differ from the bundle's, it enters the
delta, is downloaded from the blob store, and **overwrites the hand-off with the dead-end form**.
It is then sticky: later diffs run against the OTA root's manifest, which carries the website hash,
so it never self-heals.

**This is not hypothetical.** Build 7 was cut at `eae4400` (2026-07-25 12:32). The reuse-footer
component landed at `332772ec` (2026-07-26 11:50) and changes the rendered bytes of **all 1110 HTML
pages**, contribute included — the live page now contains `dw-reuse-note`, which build 7's bundle
cannot. The hashes therefore differ today.

**Failure scenario:** a build-7 install performs its first successful OTA → `/contribute/index.html`
is in the delta → the website version is staged and activated → on the next launch, tapping
Contribute shows a form that POSTs to `/api/contributions` → 404 inside the app, typed draft lost.
Every build-7 install, on its first update.

**Fix direction (do not apply during the audit):** the client cannot run Node, so the honest options
are (a) exclude `/contribute/**` from the manifest at generation time and let the bundle's copy
always win, (b) have the site emit a native-safe contribute page the app prefers, or (c) re-apply
the hand-off transform in Swift after staging and before `validate()`. (a) is smallest and matches
the existing "the bundle owns this page" intent; it also needs the staging loop to keep the file
rather than treating it as upstream-deleted.

### F-2 · P2 · No re-entrancy guard; concurrent checks share one staging directory

`checkForUpdateInBackground` has two callers — launch (`WikiRouter.swift:129,133`) and the sheet's
"Check for updates now" (`NativeAffordances.swift:191`) — and there is no `isChecking` flag, lock,
actor, or task handle anywhere in `OTAUpdater.swift`. Both runs use `versions/staging`
(`OTAUpdater.swift:371`).

**Failure scenario:** cold launch on a slow connection begins a large delta. The reader long-presses
Crisis → Content status → *Check for updates now* (an invitation the sheet makes explicitly, and the
natural move for someone who just saw "no internet connection" and reconnected). Run B executes
`removeItem(staging)` and recreates it while run A is mid-loop. A keeps writing into the recreated
directory, unaware the files it already wrote are gone, then completes, writes its manifest, and
moves the directory to `finalRoot`. `validate()` checks only three `/crisis/**/index.html` probes
plus `index.html` — if the wiped files are not among those four, an **incomplete content root passes
validation and is activated**, and it persists until the next successful update because it keeps
passing the same four-file check.

Given `maxDeltaBytes` is 300 MB and the current site is ~87 MB, the download window is wide enough
for a reader to do this.

### F-3 · P2 · The Swift client has zero automated coverage

`find app/ios -iname '*test*'` returns nothing and the pbxproj has **0** `Test` references. The
publish side is well covered — `ota-sign.selftest.sh` (sign → verify → tamper-reject → every
manifest entry has a blob), `verify-bundle.selftest.sh`, and `check-live-deploy.mjs` post-merge
against production. The client, which holds all the logic that can strand a device — delta
computation, hard-link vs download, staging, atomic activation, rollback, new-binary-wins, the
error taxonomy — is exercised **only** by hand in a simulator.

**Failure scenario:** any future refactor of `OTAUpdater.swift` (including this one) can regress
rollback or activation with nothing to catch it; F-1 and the pre-existing dead channel both survived
precisely because no automated check spanned these boundaries. Note this is the same class of gap as
the original bug, one layer up.

---

## Notes and risks (not findings)

**R-1 · `activeContentRoot()` mutates state and is called mid-session from a background thread.**
`OTAUpdater.swift:351` calls it inside `checkForUpdate`, and the function can `removeItem(contentDir)`
(lines 131, 147) — deleting the directory the live WebView is currently serving from. Requires a root
that validated at launch to fail mid-session (disk corruption), so the probability is low, but the
consequence is in-session 404s. `captureServing` is correctly guarded against re-capture.

**R-2 · `validate()` is a spot check by design.** Three crisis probes plus `index.html`. Documented
as a deliberate launch-cost tradeoff; worth restating because F-2's severity depends on it, and
because it means "validated root" is a much weaker claim than it sounds.

**R-3 · Rollback is destructive in two silent steps.** `removeItem(currentPointer)` then
`moveItem(previous → current)`, both `try?` (lines 141-142). If the first succeeds and the second
fails, the pointer state is briefly inconsistent — but it converges on the next launch, and the
bundle remains the ultimate fallback. Also, after a rollback there is no `previous` left; the bundle
is the only remaining fallback. Both are acceptable, neither is written down.

**R-4 · A pending update is only discoverable by seeking out the status sheet.** No banner or badge
says one is waiting. Low impact — activation happens on the next launch regardless.

**Corrected mid-audit:** I initially suspected duplicate `checkForUpdate` invocations from two
`manifest.json` GETs in a local server log. Those were my own `curl` probes from the same minute, not
the app. No finding.

---

## Environment matrix

**Covered** (iOS Simulator, iPhone 17 Pro, content signed with the production key so the pinned
`publicKeyB64` was the code under test):

- staged → activated on relaunch → Source flipped → OTA-only content rendered
- second relaunch → `upToDate`; pending flag cleared
- server down (dead port) → `serverUnavailable`
- tampered `manifest.sig` → `signatureRejected`
- corrupted blob → `contentRejected`, nothing staged, previous root still serving
- production edge, post-merge: schema 2, sampled crisis blobs hash correctly

**Not covered — state plainly rather than imply coverage:**

| Cell | Status |
|---|---|
| Real device (any) | **NOT COVERED** — TestFlight build 7 has never been run against this code |
| Network lost mid-download | NOT COVERED |
| Slow / cellular link | NOT COVERED |
| `noNetwork`, `manifestInvalid` (via bad JSON), `storageFailed`, disk-full | NOT COVERED — 4 of 8 outcomes never exercised |
| Rollback after the refactor | NOT COVERED — last proven 2026-07-23, pre-refactor |
| VoiceOver / Dynamic Type on the status sheet | NOT COVERED |
| Device restart, expired session | NOT COVERED / N-A |
| Timezone + DST on the "Content from" date | NOT COVERED |
| Android | N-A (deferred) |

---

## Verdict

**SHIP-WITH-KNOWN-GAPS**, with one caveat that is close to blocking.

The channel itself is sound: signature-before-parse holds, integrity is enforced against the signed
manifest, activation is atomic and deferred to next launch, and the production path is verified
end to end through the real Cloudflare edge.

**F-1 should be fixed before build 7's installs update**, because it is not a latent risk — the
current live manifest already differs from build 7's bundle on `/contribute/index.html`, so the
regression fires on the first successful OTA. It degrades one page rather than crisis content, which
is why this is not BLOCKED, but it silently un-resolves a P1 that was closed deliberately.

F-2 and F-3 are P2 and can follow.

**This audit does not claim the channel is bug-free.** It claims each boundary above was inspected
and named, with evidence or an explicit `UNVERIFIED`. The largest single gap is that **no part of
this has ever run on real hardware.**
