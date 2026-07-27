# Four-app remediation tracker

Consolidated from the multi-role matrix audit sweep (2026-07-23) and the four-app visual review
(2026-07-24). **§0 merge queue closed 2026-07-24 — all sweep PRs merged.** Sources: the four per-app
[audit docs](.) and the [visual-review capture](four-app-visual-review-2026-07-24.md).

Legend: ✅ shipped/merged · 🟡 in progress · ⬜ not started · ⏳ blocked on a decision/gate

---

## 0. Merge queue — ✅ CLOSED. Every sweep fix is merged (2026-07-24).

All 13 landing PRs merged; the 14th (BN #64) was correctly abandoned as redundant. Two PR numbers
changed because stacked bases were deleted on merge and their dependents auto-closed — re-landed
fresh. `--admin` was needed only for BN (branch protection); KA/CIT/Atlas merged without it.

**KindredAccess** — all merged:
- [x] **#20** — chat send-acknowledgement (F1).
- [x] **#24** — staff-media audit log (F2). *(was #21; auto-closed when #20's base branch was deleted → rebased onto main, reopened as #24.)*
- [x] **#22** — iOS safe-area inset.
- [x] **#23** — home-screen label.

**Chronic Illness Tracker** — all merged (each rebased to union the shared `CHANGELOG.md` `[Unreleased]` block):
- [x] **#72** — draft persistence (C1).
- [x] **#73** — OIDC sign-in diagnostics.
- [x] **#74** — iOS safe-area inset.
- [x] **#75** — home-screen label.

**Access Atlas** — both merged:
- [x] **#31** — CSRF origin fix (unblocks all prod form submission).
- [x] **#32** — iOS safe-area inset.

**Benefits Navigator** — merged (all via `--admin`):
- [x] **#74** — audit integrity, append-only log + real client IP (F2/F4). *(was #62; auto-closed with its deleted stack base → cherry-picked onto main, reopened as #74.)*
- [x] **#71** — iOS safe-area inset (rebased past ~5 peer merges).
- [x] **#72** — home-screen label (web meta + native `CFBundleDisplayName`).
- [x] ~~**#64**~~ — CI staticfiles-manifest fix. **Abandoned as redundant:** a peer session fixed the same red-`main` a different way (`#65 "don't require a collectstatic manifest under tests"`, merged). Left closed.

> **Lesson (logged):** never squash-merge a stack base with `--delete-branch` before retargeting its
> dependent — the deleted base auto-closes the dependent PR (hit twice: KA #21, BN #62).
>
> Pre-existing PRs NOT from this sweep, left to their own threads: BN #73/#70/#54/#28/#27/#24/#22,
> KA #16/#12/#7, Atlas #17.

---

## 0.5 Mobile-client architecture — a fix "reaching users" depends on this (2026-07-25)

Discovered while chasing why CIT fixes weren't showing on the user's phone. **The web/backend
remediation only reaches a mobile app if that app renders the hosted web app.** Three of four do;
CIT does not.

| App | Mobile client | Web/backend fixes reach it? |
|---|---|---|
| Access Atlas | Capacitor → loads hosted URL | ✅ automatically (verified on sim) |
| Benefits Navigator | Capacitor → loads hosted URL | ✅ automatically |
| KindredAccess (`kindredaccess-ios`) | Capacitor → loads `kindredaccess.org` | ✅ automatically, **once KA web is deployed** |
| **Chronic Illness Tracker** | **Baseline** = native Expo app (`bas-apps/apps/cit`, own UI) | ❌ **no — needs native porting** |

**CIT/Baseline is the sole native rewrite.** Its web-fix equivalents had to be re-implemented:
- [x] ✅ **Draft persistence** ported to the native entry forms — [bas-apps#2](https://github.com/BeauAccessSolutions/bas-apps/pull/2), **merged**. SecureStore-backed, mirrors CIT-web C1.
- ✅ **OIDC diagnostics (#73)** already reached Baseline — it's backend, shared via the CIT API.
- N/A **safe-area** — native nav headers + `safe-area-context` handle it.
- N/A **home-screen label** — native name comes from `app.json`, not `apple-mobile-web-app-title`.

### Baseline sign-in — root-caused and fixed (2026-07-25)
The review's "sign-in fails deterministically, persists across restarts" was **Baseline's native
OIDC screen**, and it was a **stale TestFlight build**, not a code/config bug. Every server-side
layer verified clean: CIT `/api/health` 200, email+password login works, signup works, backend
`KEYCLOAK_ISSUER`/`KEYCLOAK_CLIENT_ID` (`cit-web`) match Baseline, `cit-web` exists in Keycloak
with the native redirect registered (authorize → 302), URL scheme registered, zero OIDC failures
logged. The smoking gun: the native OIDC issuer wasn't pointed at the real BAS Keycloak host until
`9f8e54a` (**2026-07-17**), and `EXPO_PUBLIC_*` is compiled in at build time — so the installed
build (≤ build 8) had the wrong issuer baked in. **Fixed by EAS build 9** (`--profile production
--auto-submit`, correct issuer + the draft fix), submitted to TestFlight.
- [ ] ⏳ **Confirm sign-in on build 9** once installable — the real proof of the diagnosis.
- Note: CIT **web** is fully usable today (email/password) regardless.

---

## 1. Post-merge verification gates — merging is not "done"

- **On-device notch check (2026-07-24, iPhone 17 Pro / Dynamic Island sim):**
  - [x] ✅ **Access Atlas** (#32) — **visually verified**. Built + launched the Capacitor app (loads the
    deployed site full-screen in WKWebView). Top-of-page AND scrolled: the teal `--brand` fixed strip
    fills the Dynamic Island zone at every scroll position; no content renders under it. The fixed-strip
    mechanism works — this is the pattern Atlas/KA/BN all share.
  - [x] ✅ **Benefits Navigator** (#71) — **verified by mechanism-parity + live delivery.** Same fixed-strip
    mechanism Atlas visually proved. BN's one unique risk (linked `safe-area.css` under `style-src 'self'`,
    no unsafe-inline) confirmed on the live site: HTML references the manifest-hashed
    `safe-area.80db95ad16c3.css`, served **HTTP 200** with the `position:fixed` / `env(safe-area-inset-top)`
    / `#1e3a8a` rule — not CSP-blocked, not 404. (Full Capacitor rebuild skipped: needs `npm install` +
    `cap sync` in `mobile/`; not worth it given Atlas proved the mechanism and curl confirmed BN's delivery.)
  - [~] 🟡 **Chronic Illness Tracker** (#74) — **fix confirmed shipped, not visually confirmed.** Deployed
    output has `viewport-fit=cover` AND the header's `env(safe-area-inset-top)` rule (in
    `/_next/static/chunks/…css`). But CIT uses the *padded sticky-header* variant (not the fixed strip Atlas
    proved), and as a Next.js PWA its standalone-notch rendering needs a manual "Add to Home Screen" — and the
    sticky header lives behind the (known-fragile) login. Standard iOS pattern, passed CI; a real-device
    standalone check is still worthwhile.
  - [ ] ⏳ **KindredAccess** (#22) — **cannot check: not deployed.** `kindredaccess.org` serves no
    `viewport-fit=cover` yet (KA deploys manually over SSH — merge ≠ live). Re-run this check after the KA deploy.
- [ ] ⏳ **BN TestFlight rebuild** — two BN changes only take effect in a new native build, not a web deploy:
  the `CFBundleDisplayName` "Benefits" (#72) and any Capacitor/native-shell change. Schedule a build.
- [ ] ⏳ **Apply migrations on deploy** — KindredAccess `0045` (client_msg_id) + `0046` (StaffMediaAccess).
  KA deploys manually over SSH; merge ≠ live. CIT/BN/Atlas sweep PRs need no new migrations.
- [ ] **KA/CIT home-screen labels** reach the web instantly, but existing home-screen installs keep the
  old label until re-added — note for testers.

---

## 2. Filed blockers (GitHub issues) — open, not yet fixed

**Benefits Navigator:**
- [ ] **#59** `AUTHZ-05` — least-privilege caseload scoping is `default=False`; every caseworker sees every
  case in the org. One-line default flip + a migration decision for existing orgs.
- [ ] **#60** `REV-01` — no idempotency on any state-changing POST; `case_create`/`invite_veteran`/`add_case_note`
  double-submittable (duplicate invitations = outbound email to a veteran). Real work; own PR.
- [ ] **#61** `AUDIT-01` — audit entries carry no acting role, so dual-hat access is unattributable. Add
  `organization`+`role` columns (also enables the `AUDIT-04` anomaly queries).

**KindredAccess** — from the [report/block slice audit](kindredaccess-report-block-audit-2026-07-26.md) (2026-07-26):
- [ ] **#25** `K-1` — report `description` has no server-side length limit at the form or model layer;
  `maxlength=2000` is a widget attribute only. *Revised down:* `DATA_UPLOAD_MAX_MEMORY_SIZE` caps the
  body at 5 MB, so the gap is 2,000 chars advertised vs ~5 MB enforced, not unbounded.
- [x] ~~**#26** `K-2` — no rate limit on report/block~~ **RETRACTED, closed invalid.**
  `RateLimitMiddleware` gives `/report/` a dedicated 5-writes-per-minute per-user bucket whose own
  comment names the urgent-lane threat model. The finding came from grepping `core/views.py` and
  concluding absence; rate limiting is middleware. Method fix landed in the audit skill.

**KindredAccess — P0s from the parallel Codex audit of the deployed build (2026-07-26), confirmed from source:**
- [ ] ⬜ **Production dynamic routes returning HTTP 429.** `RATE_LIMIT_TRUSTED_PROXIES` defaults to
  empty (`settings_production.py:372-374`); behind Nginx over a Unix socket, requests collapse onto
  one shared bucket. `deploy/README.md:83` warns about this exact configuration. **Availability
  outage — highest priority in the portfolio right now.**
- [ ] ⬜ **Protected media delivery broken.** Django emits `X-Accel-Redirect: /internal-media/...`
  (`media_proxy.py:330`, `settings_production.py:210`) but `deploy/nginx-kindredaccess.conf:71` has
  no such location — the file literally says *"If you later add X-Accel-Redirect, expose an
  `internal;` location here."* The app was upgraded; the nginx conf never was. Authorized profile
  photos, chat images and moderation evidence cannot be served.
- [ ] ⏳ **NCMEC escalation path unresolved** while public Terms promise CSAM is reported to NCMEC
  (`core/templates/core/terms.html:159`). Counsel decision, not engineering — see
  `docs/audits/LAUNCH_DECISIONS_COUNSEL_BRIEF_2026-07-23.md`.
- [ ] ⬜ **Production lags `main` by four merged fixes** — chat send-acknowledgement, iOS safe area,
  iOS title, and the **staff-media audit log**. That last one means privileged staff media access is
  unaudited in production despite the fix being merged. No automated deployment attestation ties
  production to a tested artifact.

**KindredAccess — remaining P1/P2 from the same Codex audit.** Full record with per-finding
verification status in [KA `docs/audits/CODEX_AUDIT_2026-07-26.md`](../../../kindredaccess_files/docs/audits/CODEX_AUDIT_2026-07-26.md).
Not independently re-checked here — treat as leads:
- [ ] ⬜ **P1** WebSocket messages can be silently lost — deployed client clears an optimistic message
  with no server ack or idempotency key; the fix is merged and undeployed.
- [ ] ⬜ **P1** Account export omits received messages, chat images, availability history, consent
  metadata, profile views, subscription info, read receipts, user-linked analytics, Keycloak linkage.
- [ ] ⬜ **P1** Deletion vs evidence preservation — open-report evidence held indefinitely with no
  expiry or access review, against public 30-day deletion language.
- [ ] ⬜ **P1** Privacy / App Store declarations conflict with behaviour — the checklist says no crash
  data while Sentry is on (`docs/app-store/APP_PRIVACY_CHECKLIST.md:113`); the privacy page's deletion
  link points at feedback rather than account deletion.
- [ ] ⬜ **P2** CSP permits inline scripts/styles, and 429 responses bypass CSP middleware.
- [ ] ⬜ **P2** CI has no formatter, linter, type checker, dependency audit, JS tests, browser E2E, or
  **Nginx integration test** — the last would have caught the `internal-media` P0 above.
- [ ] ⬜ **P2** Dependencies not locked or hash-pinned; docs drifted (README, roadmap, test counts).

---

## 3. Audit findings NOT yet filed as issues (from the per-app audit docs)

Decide file-or-fix. None are the fixed ones.

**KindredAccess** ([audit](kindredaccess-blocker-audit-2026-07-23.md)):
- [ ] **F3** — 2-week sessions, no idle timeout (`SESS-05`). AAL judgment call — see P1 below; **fix F1 first** (already #20).
- [ ] **F4** — chat/match denials distinguish existing-but-forbidden from nonexistent → match IDs enumerable (`AUTHZ-12`). Raise `Http404` on the authz failure.
- [ ] **F6** — media ownership resolved by `photo__endswith` suffix match; availability/correctness bug (not a leak — verified). Key on the stored path.

**Chronic Illness Tracker** ([audit](cit-blocker-audit-2026-07-23.md)):
- [x] **C2** — no idempotency on entry creation (`REV-01`) → **[CIT#82](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/82) merged 2026-07-26**,
  native client follows in [bas-apps#4](https://github.com/BeauAccessSolutions/bas-apps/pull/4).
  Not the natural-key pattern the audit suggested: entries have no natural key, and every candidate
  (user + timestamp + name) is a payload hash by another name, which cannot tell a retry from a real
  second entry and so silently swallows real data — two doses an hour apart, the same symptom twice
  in a flare. Instead a **client-minted key per submission attempt**, held across retries of that
  attempt and cleared on success; `(userId, key) → entryId` written in the entry's own transaction.
  **Fails open** (no key creates as before), which is what let the backend ship before the native
  client and is why the rule "never block logging" survives. Reasoning and rejected alternatives in
  CIT `docs/adr/009-entry-idempotency.md`.
  Verified by reproducing the bug in a browser — patched `fetch` so the first save reached the
  server and the reply was lost, then pressed Save again: one row where there would have been two —
  plus 10 real-Postgres cases including the concurrent-duplicate race.
  ✅ **Live**: deployment `d6c9bf2d` ACTIVE 2026-07-26 22:5xZ, `/api/health` 200. This one carried a
  schema migration, applied by the app's `PRE_DEPLOY` job (`.do/app.yaml:50-59`) — a failed migrate
  fails the deploy, so ACTIVE is real evidence it ran, not an inference from the health check.
- [ ] **C3** — 24h absolute session, no idle timeout (`SESS-05`). At the AAL2 ceiling; add idle only **after C1 ships** (it now has, #72).
- [x] **C5** — no auth-event history → **[CIT#83](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/83)**.
  `AuthEvent` records sign-in (password and platform), failed sign-in, password change, session
  ended, other sessions ended, export created — and **the account can read its own history** in
  Settings → Security, which is the half that makes it useful rather than merely compliant ("was
  that export me?"). Three constraints worth carrying to other apps: a failed sign-in is recorded
  **only against an account that exists** (otherwise the log becomes the enumeration artifact the
  signup flow is designed not to leak); recording **never throws**, so it cannot fail the operation
  it observes; 90-day retention **swept on write**, not by a scheduled job — this repo already has
  two crons that no-op until their secrets are set, and a third would have been three.

**Chronic Illness Tracker — closed 2026-07-26** (acute-capture audit + the Codex check-in findings;
all four merged to `main` the same session, each with a real-Postgres or browser check, not just a
green unit suite). **All four are live**: deployment `b1f3ccee` (commit `ee50955`, the last of them)
went ACTIVE 22:06Z with `/api/health` 200:
- [x] **F-1** PHI in production logs → [#78](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/78). See §6.
- [x] **Codex check-in P0 — stale dose metadata** → [#79](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/79).
  Prisma reads `undefined` as "leave this column alone", so `SKIPPED`/`RAN_OUT` → `TAKEN` stayed
  *taken because they ran out*, and that contradiction was in the CSV people take to appointments.
  Ships a data migration repairing existing rows (Zach approved the backfill in-PR). 5 of its 6
  real-Postgres cases fail without the fix.
- [x] **Codex check-in P0 — schedules generate no dose slots** → [#80](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/80).
  BID/TID collapsed to one toggle (the two doses shared a row, so marking one overwrote the other);
  WEEKLY appeared daily. Now one slot per dose. **Slots are ordinal, not clock times** — a
  `RegimenItem` stores a schedule and no times, so labels are "1st dose"/"2nd dose"; "Morning"/
  "Evening" would assert something the user never entered. Slot 1 keeps the `''` key every existing
  row carries, so no dose history is orphaned. Verified in a browser, not only in tests.
- [x] **F-7** acute flag in the URL → [#81](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/81).
  `/log?acute=true` → `/log#reaction`; a fragment is never sent to the server. `?type=` deliberately
  stays a query param — which form you opened is preference-level, the class the logger classifies
  non-PHI.
- **Not covered:** C2/C3/C5 above are untouched, and F-3/F-4/F-5/F-6 are native (`bas-apps`), not web.

**Chronic Illness Tracker (native, `bas-apps`)**:
- [x] Bottom tab bar had **no icons at all** (five labels in a row) → [bas-apps#3](https://github.com/BeauAccessSolutions/bas-apps/pull/3),
  Ionicons, outline/filled for active state, labels kept. Reported as "upside down triangles" on
  TestFlight; **that symptom was never reproduced from source** — expo-router 57's `Tabs` is the JS
  navigator and renders `null` for an undefined icon, so this adds icons where there were none. If
  triangles survive the next EAS build, they are something else and need a screenshot.
  Reaches TestFlight only via an **EAS build** — it ships font assets, so an OTA update will not carry it.

**Access Atlas** ([audit](access-atlas-blocker-audit-2026-07-23.md)):
- [ ] **A1** — 30-day sessions at the AAL1 ceiling; complicated by the access-identity (disability) tag. AAL/counsel call — see P1.
- [ ] **A2** (outside matrix) — no rate limiting on public write endpoints. KA's `MessageRateLimiter` is the in-portfolio precedent.
- [ ] Suppress the two documented `security_definer_view` Supabase lints with an inline rationale so they stop reading as open items.

**Benefits Navigator:**
- [ ] **F6** — unvalidated `order_by` from the query string (`vso/views.py:389`); 500 + weak inference channel. Allowlist sortable columns. (Minor; not filed.)

---

## 4. Visual-review UI backlog (2026-07-24) — not yet started unless noted

**Cross-cutting:**
- [x] ✅ **X1** content under status bar → fixed ×4 (§0).
- [ ] 🟡 **X2/X3** error states & data loss: KA send-failure (#20) and CIT drafts (#72) done; **not done** —
  the shared error-state component (real message + preserved input + working recovery + `role="alert"`),
  Atlas CSRF blank error page, and **KA sign-out-mid-compose** (the composer is
  still the only copy of un-sent text at logout — #20 covers send, not this).
  **CIT's sign-in error screen is done** ([#84](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/84)):
  real message, both fields preserved, the unverified case offers the resend control inside the same
  announced region — and never parks that control in the tab order for people not in that state.
- [ ] **X4** internal copy leaking to users: KA Jinja comment renders as body text; Atlas design-rationale
  copy; BN raw markdown (same as BN #1 below). Grep each codebase for developer commentary in user strings.
- [ ] **X5** header/nav bloat (all four) — collapse to hamburger/bottom-tab below a breakpoint; shorten wordmarks.
  **CIT done** ([#85](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/85)): it already
  collapsed to a hamburger under `md`, so only the wordmark was outstanding — phones now show the
  `shortName` already shipped for the iOS home-screen icon. Worth carrying to the other three: the argument
  that decided it was not bar space but that **a phone screen is read by more people than its owner**, and
  "Chronic" tells a waiting room less than "Chronic Illness Tracker". KA/BN/Atlas still open.
- [ ] **X6** screen-reader announcement of errors — audit; ensure `role="alert"`/`aria-live` on error paths.
  **CIT done** ([#84](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/84)) — and the
  finding is more specific than the item reads. The regions *had* `role="alert"`; they were written
  `{error && <p role="alert">{error}</p>}`, so the region and its text were created in the same instant,
  which is **silent** to a screen reader. Auditing for the attribute would have passed all 15 of them.
  Grep the other three for that shape, not for missing roles. A source-scanning test now guards CIT's.
  Two things axe found that reading did not: `autocomplete="username email"` is invalid (one field name,
  not two) so password managers had stopped filling — check the other apps' login forms — and an error
  boundary that replaces the page in place announces nothing, because no navigation happens.
- [ ] **X7** KA icon-only controls without accessible names (green dot, dark dot, ⋮, ✓) — `aria-label` + legend.

**VA Benefits Navigator** (confirmed against screenshots):
- [ ] Markdown stored but rendered literally (`## `, `**bold**`, `- `) — add a render-time markdown filter + sanitizer.
- [ ] Duplicated headings (styled H1 + the content's own `##`).
- [ ] allauth templates unstyled — signup form AND the `socialaccount` "Sign In Via Beau Access → Continue" page (plain-text "Continue", fails 44pt).
- [ ] Password rules as a text wall above the field → move below, live checklist; "Sign Up" appears twice; no show-password toggle; verify `autocomplete` attrs (`WCAG 3.3.8`).
- [ ] Feedback widget occludes body text on claims-prep pages → bottom padding + dismissible.
- [ ] "93% of C&P exams by contractors" — unsourced/undated → source + as-of date, or soften (→ counsel/content).
- [ ] "AI-powered assistance for VA disability claims" framing — liability for a VSO audience → reframe as drafting-with-rep-review (→ counsel, §5).

**KindredAccess** (confirmed):
- [ ] Timezone bug — message stamped `1:06 PM` while device reads `9:06` (UTC unconverted). Two timestamp renderers; unify to one localized formatter.
- [ ] Caption/bubble contrast (dark-on-rust `[Baby]` etc.) — verify hex vs 4.5:1; rust needs near-white text.
- [ ] `[Being reviewed…]` bracket text → designed moderation badge.
- [ ] Composer unusable width; "Press Enter / Shift+Enter" desktop hint on mobile; Sign Out is the most prominent nav control (demote + confirm on unsaved draft); no back-stack ("Back to Matches" only); "Clear" adjacent to "Apply Filters".

**Access Atlas** (confirmed):
- [ ] Gated "Suggest a place" form rendered fillable to signed-out users → gate the form, or carry a draft through the auth round-trip.
- [ ] Fieldset legend collision ("Where is it? …") overlaps the border → `float`/restyle.
- [ ] Confirm the logo is a working home link.
- Strengths to preserve: trust-labeling copy, teal contrast, compass mark.

---

## 5. Decisions & counsel — gate the largest work; not engineering's to settle

- [ ] ⏳ **§4.5 — the VSO scope fork (highest leverage).** Will VSOs enter veteran *case data* into Benefits
  Navigator, or is it a reference/prep tool alongside their existing system of record? Reference → fix UI &
  ship. System-of-record → POA-scoped ReBAC (VA Form 21-22/22a), org-tenancy in Keycloak, **§7332** segmentation,
  view-level audit, break-glass all become launch requirements. **Replace self-serve signup with org-scoped
  invitation BEFORE any veteran data enters** — the one hard prerequisite regardless of the answer.
- [ ] ⏳ **§7332** (VA's stricter 42-CFR-Part-2 analog: SUD/HIV/sickle-cell, written-consent redisclosure) —
  new; add to the [BN data-posture brief](../legal/bn-data-posture-counsel-brief.md).
- [ ] ⏳ **P1 session timeouts** — adopt the per-app values now in the matrix (`P1_session_timeouts.per_app`:
  BN 15m/12h · KA/AA/CIT their AALs). `testmatrix.py gate` fails until `status: adopted`. Resolves KA F3, CIT C3, AA A1 together.
- [ ] ⏳ **P5 minors / age-of-majority** — `pending_counsel`; the [minors-delegation brief](../legal/minors-delegation-counsel-brief.md).
  Includes the **KindredAccess age posture** (18+ by a self-attested checkbox + typed integer, no verification, while the
  safety apparatus assumes minors may be present — both can't be load-bearing).

---

## 6. Log & exception PII/PHI hygiene — cross-app sweep (opened 2026-07-26)

**Origin.** A CIT vertical-slice audit found a PHI boolean logged under an *abbreviated key*
(`isAcute` for `isAcuteCapture`), which defeats CIT's field-name redaction allowlist by construction
and is invisible to `phi-fields-drift.test.ts` because that test reconciles **Prisma columns**, not
log call sites. Confirmed live at web production `51afc45`. See
[cit-acute-capture-audit-2026-07-26.md](cit-acute-capture-audit-2026-07-26.md).

**Why this is a platform item, not a CIT bug.** [`INVARIANTS.md`](../../INVARIANTS.md) has no
invariant governing what an app writes to its own logs — "no PHI in logs" exists only as *CIT's*
app-level non-negotiable #3. And a grep across every BAS repo found **CIT is the only app with any
redaction layer at all.** Two apps independently built a schema-shaped guard (CIT's drift test, BN's
`check_security_invariants.py` Check 1) and **both have the same blind spot**: they inspect field
definitions, never the log or exception surface.

- [ ] ⬜ **Platform — add invariant #6, log hygiene**, enforced by construction per that document's
  own standard. For logs that means a lint rule over `logger.*` payload keys and `str(e)`/`{e}`
  interpolation — a schema-based check provably cannot catch a call-site rename.
- [ ] ⬜ **Platform — promote CIT's `src/lib/logger` to a shared package.** Its `scrubString()` was
  built for exactly the exception-passthrough class found in BN, and today one app has it.

Per-app status — **only BN has been swept; the rest are unexamined, not clean:**

- [x] **Benefits Navigator — swept 2026-07-26, then independently re-found by a Codex audit.** Own
  logging is disciplined (325 call sites; the 20 user-adjacent ones log ids/counts/lengths, not
  content), `send_default_pii=False` is set and CI-guarded. Residual risk is third-party exception
  text: Sentry stack-frame locals (`include_local_variables` unset → SDK default `True`, independent
  of `send_default_pii`), plus 8 `str(e)` interpolations. **Codex confirmed it at `settings.py:696`,
  closed our open question — the *installed* SDK defaults locals capture on — and widened the
  surface: every Celery task frame retains OCR text and document analysis, not just the two
  `ocr_service` sites.** Filed in [BN `TODO.md`](../../../benefits-navigator/TODO.md) with fixes.
- [x] **Chronic Illness Tracker — swept 2026-07-26; fix MERGED to `main` 2026-07-26 (deploys on push).**
  **CIT has no Sentry or any error-reporting SDK**, so the `include_local_variables` defect that hit
  BN, KA and (differently) page-repair does not apply here — CIT's variant was the `isAcute` rename.
  **[CIT#78](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/78)
  (`fix/log-payload-fail-closed`, `df7b616`) fixes it, and fixes it better than recommended:** the
  runtime now **fails closed** on an allowlist (`SAFE_LOG_KEYS`) instead of a PHI denylist, so an
  unknown key is redacted by default and a rename cannot defeat it *by construction*. Adds
  `tests/unit/log-call-site-keys.test.ts`, which reads `logger.*` call sites — the layer
  `phi-fields-drift.test.ts` structurally cannot see — and handles un-analysable spread payloads via a
  `REVIEWED_SPREADS` allowlist that fails until each is deliberately listed.
  **#78 merged 2026-07-26 21:00Z** (squash, CI green). The guard was mutation-tested before merge:
  re-introducing the exact leak fails the new test with `…/symptoms/route.ts:87 → isAcute`. Three
  generic neighbouring keys were renamed rather than allow-listed (`type` → `insightType`, `subject`
  → `emailSubject`, `categories` → `safetyCategories`), on the reasoning that generic names are
  precisely the ones that get reused for health content later.
  ✅ **Deployed.** DO deployment `c8c7c16a` (commit `d8d6529`, which contains the F-1 fix) reached
  **ACTIVE** 2026-07-26 21:48Z and `/api/health` returns 200. Note the deploy for `747468a` (#78
  itself) shows CANCELED — superseded by the next push, not failed; every deploy builds the whole
  tree, so the fix went live in its successor. **F-1 is out of production.**
- [x] **KindredAccess — swept 2026-07-26.** Own logging is **clean**: all 55 `core/` call sites log
  identifiers, never content, and `photo_moderation.py:274` already uses `type(exc).__name__` over
  `str(exc)`. The gap is Sentry: `send_default_pii=False` is set but `include_local_variables` is
  unset (SDK default on, independent setting), and `LoggingIntegration(event_level='ERROR')`
  promotes every `logger.error`/`exception` to an event. `core/consumers.py:553-563` binds `body`
  two lines above a `logger.exception` in the message-create path → a DB error while sending a chat
  message serializes the **message body** to Sentry. **Worse-positioned than BN's**, which needed an
  unhandled exception to reach Sentry at all. Filed in
  [KA `docs/audits/LOG_PII_SENTRY_AUDIT_2026-07-26.md`](../../../kindredaccess_files/docs/audits/LOG_PII_SENTRY_AUDIT_2026-07-26.md).
  *Pass carries no test/dependency signal — both declined as writes under a read-only budget.*

> **Three apps, three hits, two independent auditors: the leak is never the log statement.** BN and
> KA both write disciplined log calls and both ship frame locals to Sentry with
> `send_default_pii=False` set and `include_local_variables` unset; a separate Codex audit re-found
> it in BN without seeing this sweep. `send_default_pii` governs request bodies, cookies and user
> identifiers — **it does not touch frame locals**, and every team here has read it as though it
> does. Treat this as one portfolio-wide config defect, not N app bugs, and **check the
> error-reporter config before auditing any app's log statements** — doing it in that order would
> have cut both of our sweeps to a fraction of the work.
>
> - [ ] ⬜ **Add to `check_security_invariants.py`-style gates in every app:** fail the build if
>   `sentry_sdk.init` omits `include_local_variables=False`, and pin `sentry-sdk` exactly so the
>   default cannot shift underneath the decision.
- [ ] ⬜ **Disability Wiki** — 16 log call sites, no redaction layer. Unexamined.
- [x] **page-repair — swept 2026-07-26.** [Full audit](../../../page-repair/docs/audit-2026-07-26.md).
  **Strongest codebase of the six**; no P0/P1. Logging is counts-only except one site:
  `proxy/src/index.ts:299-300` logs the upstream Anthropic error body (300 chars, 100% sampling), and
  4xx bodies can quote the request — whose prompt carries allowlisted `href`/`innerHtml`/`nearbyText`.
  **P2 not P1** because `sanitizeContext` allowlists and length-caps before the prompt is built, so
  the worst case is a few hundred chars of structured control context, not a whole document.
  Second finding, same weight: the refund closure is `.catch(() => {})`, so a failed refund on the
  money path silently costs a user a paid credit with no log or retry.
  ⚠️ **Correction:** this entry previously said page-repair has "no test config." It does have tests
  (`npm test` → a Node harness); the claim came from globbing for jest/vitest/pytest only.
- [ ] ⬜ **Access Atlas** — has `moderation.ts`/`photo-reports.ts` redaction-adjacent code but no
  logger scrubber. Account-free browsing limits exposure; still unexamined.
- [ ] ⬜ **bas-apps (native)** — `@bas/api`, `@bas/auth` and the CIT client have no scrubber, and the
  monorepo has **no test config at all**, so nothing here is regression-guarded.

> **Method note.** The per-app counts above are call-site counts, not leak counts — I counted, I did
> not read them (BN excepted). They establish that no mechanism would stop a leak, not that one has
> occurred. Do not downgrade any ⬜ to "clean" without reading its sites.

---

## Suggested next actions (once merges clear)

1. **Merge the queue** in stack order (§0), starting BN #64 and KA #20; run `--admin`.
2. **On-device notch check** (§1) — the one gate that can't be automated.
3. **Settle §4.5** (§5) — it decides whether §2/§3 BN items are "fix & ship" or "launch blockers."
4. **Adopt P1** (§5) — closes three audit findings at once.
5. Pick off the cheap, correctly-scoped UI items: BN markdown render, KA timezone unify, Atlas legend.
