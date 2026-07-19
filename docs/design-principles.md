# Design Principles — UX Standards for the BAS Portfolio

The cross-cutting UX/interaction standard for Beau Access Solutions apps. It governs the
two things this umbrella repo owns across apps: the shared **`packages/ui` design system**
and the **Keycloak-hosted login theme**. App-specific detail (screens, flows, copy) lives
in each app's own repo — this doc is the baseline every app inherits, not a spec for any one app.

> Companion to [PLATFORM.md](../PLATFORM.md) (architecture) and [INVARIANTS.md](../INVARIANTS.md)
> (platform invariants). Where those define *what the system is*, this defines *how it should feel*.

**Governing principle:** the highest a11y bar forges the best design system. If a pattern
here is born passing WCAG 2.2 AA + axe gates, every later app inherits it proven. Accessibility
is not a section at the end of this doc — it is threaded through every standard below.

---

## 1. Fundamentals (table stakes)

These are the things whose *absence* is felt immediately. Non-negotiable in every app.

### Navigation
- Every non-root screen has a working way back; never trap the user. Respect platform back:
  iOS back + edge-swipe, Android system Back (chronological) vs. Up (hierarchical), and on
  web the **browser back button must work** and preserve place.
- Back returns to where the user *came from*, not a fixed parent (deep-links make Back ≠ Up).
- Always show "you are here" — active tab highlighted, screen titled.
- Every modal/dialog has an escape hatch (X, Cancel, tap-outside, Esc).

### Input & typing
- Immediate feedback (<100ms); right keyboard per field (`inputmode`/`type`); never block paste.
- **Validate on blur or submit, not mid-first-entry**; once a field has errored, re-validate
  live so it turns valid as the user fixes it. Errors sit next to the field, name the problem,
  and say how to fix it.
- Show constraints up front (counters, rules), don't spring them as errors.
- **16px minimum font on web inputs** — below that, mobile Safari auto-zooms on focus.

### Feedback & system status
- Every async action has **loading / success / empty / error** states. Prefer skeletons over
  spinners for in-place content. Anything >1s shows progress.
- Errors are plain-language, blame-free, and paired with a recovery action. No raw stack traces.

### Touch targets & layout
- **44×44px (Apple) / 48×48dp (Android)** minimum tap target; WCAG 2.2 floor is 24×24px
  (SC 2.5.8). Applies to the *hit area*, not just the visible glyph. ~8px min between targets.
- Primary actions in the thumb zone (bottom third) on mobile.

### Forms & auth
- Label above the field (placeholder is not a label). One clear primary action per screen.
- Support autofill / password managers; support paste on password and OTP fields.
- On failed login, preserve the username; never clear the whole form.

---

## 2. The delight layer — and the rules that gate it

Fundamentals keep users from being frustrated; the delight layer is what makes an app feel
premium. Well-designed micro-interactions correlate with materially higher retention and
store ratings — but only when they feel *earned*, not decorative.

**Patterns worth adopting**
- **First-time celebrations** — reward milestones (first message, first reaction), not every action.
- **Presence signals** — a soft pulse on typing/reaction; "seen" that fades rather than snaps.
- **Optimistic UI** — the action registers instantly; the network catches up behind it.
- **Themed transitions** — cross-fade light/dark instead of a hard flip; persist the choice.

**The rules that keep delight from becoming annoyance (enforce these):**
1. **Purpose** — every micro-interaction confirms, shows status, or guides. Cut pure decoration.
2. **Fast** — animations under ~**300ms**, natural easing (ease-in-out). Slower reads as lag.
3. **Don't repeat the surprise** — a celebration that fires every time becomes friction.
4. **`prefers-reduced-motion` is mandatory** — the delight that wows one user nauseates another.
   Every animation in this section must have a reduced-motion path. This is a gate, not a nicety.

---

## 3. Interaction standards (from competitor teardown)

Opinionated defaults for the four interactions that define a messaging/assistant app, derived
from how iMessage, WhatsApp, Signal, Slack, and Telegram actually implement them.

### 3.1 Send behavior
- **Desktop:** Enter sends, Shift+Enter newline — but ship a Slack-style preference toggle
  (default Enter-sends). **Mobile:** never send on Return; a dedicated send button is the only
  send affordance (structurally prevents accidental sends).
- **Render optimistically.** Model explicit states: `queued → sending → sent → delivered → read → failed`.
- **Failed messages persist** with an inline Retry — never silently dropped, never retyped.
  Offline, queue locally and flush on reconnect.

### 3.2 Typing & presence
- **Debounce typing:** emit after ~300ms of typing, clear after ~1–2s idle. Ephemeral — never persisted.
- Make typing, read receipts, and last-seen **independent toggles.** Be *more generous* than
  WhatsApp's forced reciprocity: let users keep typing private without losing the feature.
- Default to **coarse presence** (active/away) over exact "last seen" — lower privacy cost, which
  fits our accessibility/disability-focused audience.

### 3.3 Login / onboarding
- **Passkey-first**, with **OTP (email or SMS) as universal fallback**; magic link as alternate.
  Skip passwords. (Login is Keycloak-themed, not app-implemented — see PLATFORM.md.)
- **One-field entry** (email/phone) → verify → *then* progressive profile setup. No registration wall.
- Wire autofill: `autocomplete="one-time-code"` for OTP, WebAuthn hints, proper `username`/`email` tokens.
- **Theme:** default to `prefers-color-scheme` implicitly; offer explicit Light/Dark/System in
  settings later. Don't interrupt onboarding to ask about theme.

### 3.4 Empty & error states
- Every empty thread: one-line explanation + a single primary CTA (or 3–4 starter chips on first run).
  **The first empty screen is onboarding** — coach, don't leave it blank.
- **Offline** = persistent non-modal banner ("You're offline — messages will send when you
  reconnect") + local queueing. Never a dead-end error.
- Error copy: plain-language, no blame, recovery action attached, user input preserved.

---

## 4. Accessibility spine — dynamic status

The four riskiest spots in any of our apps are all **dynamic status**: typing, send status,
presence, and connectivity. Each is naturally built as a color-only or animation-only cue —
which fails **WCAG 2.2 SC 4.1.3 (Status Messages)**, **1.4.1 (Use of Color)**, and reduced-motion
expectations *simultaneously*.

**Standard:** `packages/ui` provides **one live-region + reduced-motion utility**, and all four
status types route through it. Requirements:
- Status is conveyed as **text/shape, never color or animation alone**.
- Failures → `role="alert"` (assertive). Success/delivery/typing/connectivity → `aria-live="polite"`.
  ⚠️ **This is the web spelling of the contract, not the contract.** On React Native surfaces
  (`bas-apps`/native CIT) `accessibilityRole="alert"` announces **nothing** on either platform —
  announcing needs `accessibilityLiveRegion` (Android-only) or `AccessibilityInfo` (iOS, and
  delayed past the layout pass or the utterance is cut off). Taking this line literally on native
  is what shipped 14 silent status messages in CIT. Native surfaces route through
  `StatusMessage`/`announce` in `packages/ui`; the intent (failures interrupt, the rest waits) is
  what ports, not the attribute names.
- **Debounce announcements** so screen readers aren't re-reading "typing…" on every keystroke.
- OTP entry is a **single labeled field**, not 6 unlabeled boxes (which break paste + screen readers).
- Visible focus everywhere (SC 2.4.11 Focus Not Obscured, 2.4.13 Focus Appearance); no cognitive
  auth puzzles (SC 3.3.8 — passkeys/OTP-autofill satisfy this cleanly).
- Contrast ≥ 4.5:1 text / 3:1 large text & UI components — verified in **both** light and dark themes.

### 4.1 The four contracts the standard assumes

Each of these shipped wrong at least once. They are the implementation details the standard above
takes for granted; treat each as a gate. Where a gate exists it is named — note every one is
**per-repo**, so the rule still applies unenforced on every other surface.

Gates audited 2026-07-18 against the actual test files; every citation below was read, not inferred.
Coverage is uneven and **partial gates are marked as such** — a named gate does not mean the whole
contract is enforced there. Surfaces with **no gate for any contract**: Access Atlas
(`access-directory`), Disability Wiki, `a11y-probe`, and `bas-apps` (native CIT — no test suite at
all; [bas-apps#1](https://github.com/Beaudoin0zach/bas-apps/pull/1) adds its first). CIT's Next.js
web app **is** audited — it is checked out at `~/Chronic-Illness-Tracker`, outside `~/projects/`,
which is why an earlier revision of this note wrongly called it unavailable.

| # | Contract | Gate |
|---|---|---|
| **C1** | **Two regions, both pre-created.** A polite-only region announces failures as politely as successes. Keep a second `role="alert"`/assertive region and route **only genuine failures** to it (partial progress stays polite). **Both must be in the DOM before the first message** — a region injected together with its content is dropped by screen readers. | page-repair `test/unit.mjs` "live-region spine" section (CI, drives the real script) · BN `tests/test_assistant_template.py::test_assistant_page_keeps_both_live_regions` + routing tests in `tests/js/assistant.a11y.test.mjs` (CI) · KindredAccess `core/tests/test_views.py::test_chat_has_exactly_two_status_live_regions` (CI, **partial** — markup only, no routing test). CIT web: **unenforced** (no live-region test in `tests/unit/`) |
| **C2** | **Streaming announces once, on completion — and an announcement is not focus management.** Keep the region `aria-busy` and the live region silent while it fills; announce **once** on done. Separately, on *every* state transition move focus somewhere sensible (finished answer on done, recovery control on failure) — never leave it on a removed control. | BN `tests/js/assistant.a11y.test.mjs` (`npm run test:js`, CI) — **the only C2 gate anywhere**; asserts `aria-busy` while filling, exactly one completion announcement, and focus on done/error/stop |
| **C3** | **Routing a status type through the utility means the visible node goes AT-silent.** `role="status"` *is itself* a polite live region, so a visible node that keeps it while also feeding the shared utility is read **twice**. Strip `role="status"`/`aria-live` from the visible element (`aria-hidden="true"` or plain text) so exactly one path speaks. Same trap for a `role="log"` transcript that already voices messages. | KindredAccess `core/tests/test_views.py::test_visible_status_nodes_are_at_silent` (CI, 3 named nodes); page-repair `test/unit.mjs` "no double-read (§4 C3)" section (CI, structural) |
| **C4** | **Declare `color-scheme`; compute contrast in both themes.** Without a `color-scheme` declaration a UI is only verified in whichever theme you happened to view, and browsers may auto-darken it. Declare `color-scheme: light dark` (meta + `:root`), drive colors from tokens with a `prefers-color-scheme: dark` override, and verify every text (≥4.5:1) and UI-boundary (≥3:1) pair **numerically**, not by eye. | page-repair `test/contrast.mjs` (CI, recomputes every pair in both themes; fails closed on an unclaimed token) · KindredAccess `core/tests/test_settings.py::FocusVisibilityTests::test_toggle_off_states_meet_contrast` (CI, **partial** — real luminance math but two hardcoded 3:1 spot-checks; **no 4.5:1 text pair, no `color-scheme` assertion**). CIT web `tests/unit/a11y-css.test.ts` (CI via `npm test`) splits the `:root` and `prefers-color-scheme: dark` blocks and recomputes **both** thresholds in **both** themes — 3:1 UI boundaries and 4.5:1 status text across every surface used; it asserts the dark override exists but not the `color-scheme` declaration itself. BN declares `color-scheme` in `static/js/assistant.js` and `mobile/www/index.html` but **asserts neither it nor any contrast pair** |

Full failure stories and per-repo enforcement scope live in [`LESSONS.md`](../LESSONS.md).

---

## 5. How this applies per app

App-specific UX docs live in each app's own repo. This is the pointer to what matters most for each.

| App | Highest-value surfaces | Notes |
|---|---|---|
| **KindredAccess** (Django + Channels) | §3.1 send, §3.2 typing/presence, §4 spine | The real-time chat app — the send/presence/status standards apply most directly. Channels websockets make the `queued→…→failed` state machine and reconnect-flush a core requirement, not a nicety. |
| **VA Benefits Navigator** (Django + AI) | §3.1 send, §3.4 empty/error, §4 spine | AI-assistant shape: first-run needs starter-prompt chips; streaming responses need optimistic + interruptible UI; hallucination/uncertainty need calm error framing. Sensitive data → same PHI treatment as CIT. |
| **Access Atlas** (Astro, zero-JS) | §1 navigation, §3.4 empty/error, §4 contrast | Not a chat app — browsing stays account-free and zero-JS. Focus: search empty-results coaching, resilient navigation without client JS, and login *only* at the contribution boundary (pseudonymous). Delight layer is minimal by design. |
| **page-repair** (browser extension) | §2 delight rules, §4 spine | Overlay/injection UX on *someone else's* page — non-intrusive by default, must not fight host-page focus/contrast, and its accessibility patches inform shared `ui`. Reduced-motion and never-block-paste matter doubly here. |

---

## Appendix — PR / review checklist

Copy into an app PR when the change touches UI. The `bas-design-review` skill checks against this.

```
UX & a11y review
- [ ] Back/escape works on every new screen; browser-back preserves place (web)
- [ ] Inputs: right keyboard, autofill tokens, paste allowed, 16px+ font, validate on blur/submit
- [ ] Every async action has loading / empty / error / success states
- [ ] Touch targets ≥ 44/48px hit area; primary action in thumb zone (mobile)
- [ ] Animations < 300ms AND have a prefers-reduced-motion path
- [ ] Delight is purposeful, non-repeating — no decoration-only motion
- [ ] Dynamic status (typing / send / presence / connectivity) is text/shape, not color/animation alone
- [ ] Status routed through the shared aria-live utility; failures=alert, rest=polite, debounced
- [ ] Contrast ≥ 4.5:1 text / 3:1 large & UI — verified in BOTH light and dark
- [ ] Visible focus everywhere; no cognitive auth puzzle (SC 3.3.8)
- [ ] Empty states coach (explain + 1 CTA / starter chips); errors are blame-free + recoverable, input preserved
- [ ] Optimistic send with explicit queued→sending→sent→delivered→read→failed; failed persists + retry
```

## Sources

Competitor teardown and trend research (2025–26): Apple HIG, Material Design 3, Nielsen Norman
Group heuristics & empty-state research, WCAG 2.2; plus app-specific behavior from Slack, WhatsApp,
Signal, and Telegram help docs and W3C ARIA techniques. Full link set in the design-principles
research thread; refresh before any major redesign — the generic "trends" layer dates fast, the
teardown decisions and WCAG mappings do not.
