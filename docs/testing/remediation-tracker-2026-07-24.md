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

## 1. Post-merge verification gates — merging is not "done"

- [ ] ⏳ **On-device notch check for all 4 safe-area PRs** (#71/#22/#74/#32). The mechanism is verified
  (builds/tests pass) but the visual result on a real notched iPhone is NOT — a simulator's default may
  not surface the inset. Check top-of-page AND scrolled, both light/dark, and that no modal/toast is
  clipped by the `z-index: 40` strip.
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

---

## 3. Audit findings NOT yet filed as issues (from the per-app audit docs)

Decide file-or-fix. None are the fixed ones.

**KindredAccess** ([audit](kindredaccess-blocker-audit-2026-07-23.md)):
- [ ] **F3** — 2-week sessions, no idle timeout (`SESS-05`). AAL judgment call — see P1 below; **fix F1 first** (already #20).
- [ ] **F4** — chat/match denials distinguish existing-but-forbidden from nonexistent → match IDs enumerable (`AUTHZ-12`). Raise `Http404` on the authz failure.
- [ ] **F6** — media ownership resolved by `photo__endswith` suffix match; availability/correctness bug (not a leak — verified). Key on the stored path.

**Chronic Illness Tracker** ([audit](cit-blocker-audit-2026-07-23.md)):
- [ ] **C2** — no idempotency on entry creation (`REV-01`); duplicate symptom/sleep/food entries **skew the correlation analysis** that is the app's point. Follow the dose-event natural-key pattern.
- [ ] **C3** — 24h absolute session, no idle timeout (`SESS-05`). At the AAL2 ceiling; add idle only **after C1 ships** (it now has, #72).
- [ ] **C5** — no auth-event history (login/password-change/export/session-terminate). The narrow, applicable slice of `AUDIT-01` for a single-user app.

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
  Atlas CSRF blank error page, CIT sign-in error screen, and **KA sign-out-mid-compose** (the composer is
  still the only copy of un-sent text at logout — #20 covers send, not this).
- [ ] **X4** internal copy leaking to users: KA Jinja comment renders as body text; Atlas design-rationale
  copy; BN raw markdown (same as BN #1 below). Grep each codebase for developer commentary in user strings.
- [ ] **X5** header/nav bloat (all four) — collapse to hamburger/bottom-tab below a breakpoint; shorten wordmarks.
- [ ] **X6** screen-reader announcement of errors — audit; ensure `role="alert"`/`aria-live` on error paths.
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

## Suggested next actions (once merges clear)

1. **Merge the queue** in stack order (§0), starting BN #64 and KA #20; run `--admin`.
2. **On-device notch check** (§1) — the one gate that can't be automated.
3. **Settle §4.5** (§5) — it decides whether §2/§3 BN items are "fix & ship" or "launch blockers."
4. **Adopt P1** (§5) — closes three audit findings at once.
5. Pick off the cheap, correctly-scoped UI items: BN markdown render, KA timezone unify, Atlas legend.
