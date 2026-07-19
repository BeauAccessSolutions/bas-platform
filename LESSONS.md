# BAS-Platform Cross-App Lessons

**What this is:** transferable mistakes and hard-won lessons that recur **across Beau Access
Solutions apps** but nowhere else — the shared `packages/ui` design system, the Keycloak login
theme + OIDC integration, the §4 accessibility spine, mobile-wrapper patterns, and cross-app
safety conventions. `@import`ed only by BAS app repos' `CLAUDE.md` (alongside the machine-wide
`~/.claude/shared/LESSONS.md`).

**Scope rule:** a lesson belongs here only if *another BAS app would make the same mistake* and
a non-BAS project would not. Truly universal lessons go in `~/.claude/shared/LESSONS.md`;
single-app facts go in that app's own `CLAUDE.md` or memory. Prune if this grows past ~1 page
(**~85 lines**) — it is a narrower file than the machine-wide one (budget ~200), so it earns a
tighter ceiling.

**Governing doc:** [`docs/design-principles.md`](docs/design-principles.md) — the UX/a11y standard
these lessons defend. When a lesson hardens into a reusable primitive, graduate it into
`packages/ui` and cite it in §4 rather than leaving it as prose here.

Format per entry: **Lesson** — what broke → the fix. `(source-app, YYYY-MM-DD)`

---

## Accessibility spine & shared UI

The **normative contracts and their gates are C1–C4** in
[`docs/design-principles.md` §4.1](docs/design-principles.md) — read those for what to *do*. Kept
here is what that table can't hold: how each one actually broke, and where it is still unenforced.
Gates audited 2026-07-18 by reading the tests; **partials marked**. CIT included (it is checked out at
`~/Chronic-Illness-Tracker`, not under `~/projects/`).

- **C1 — live-region spine.** page-repair routed labeling errors, extension errors and clipboard
  failures through the same polite `role="status"` region as the success summary, so a failure queued
  behind the user's current utterance or was missed if they'd navigated on (SC 4.1.3). *Enforced:*
  page-repair `test/unit.mjs` drives the real content script and asserts both regions exist **before**
  any message, failures land assertive, progress stays polite — CI-gated. BN is more complete still
  (`tests/test_assistant_template.py` + `tests/js/assistant.a11y.test.mjs`); KindredAccess has only the
  markup half — no routing test, so the bug C1 exists to catch is untested there. *Unenforced:* Access
  Atlas, Disability Wiki, CIT (verified: no live-region test in `tests/unit/`). (page-repair, 2026-07-13)

- **C2 — streaming announce + focus.** BN's assistant re-announced its response region on every
  streamed token (machine-gunning the screen reader), and the assertive *error* announce left focus
  stranded on the now-removed "Stop generating" button. *Enforced:* the inline template script was
  extracted to `static/js/assistant.js` so it could be tested — `tests/js/assistant.a11y.test.mjs`
  pumps 200 deltas, asserts via MutationObserver that the polite region never changes, and checks focus
  lands on the answer / recovery control; CI as `npm run test:js`. ⚠️ `tests/e2e` is **excluded** from
  BN's pytest run, so a Playwright test there gates nothing. *Unenforced:* KindredAccess's chat
  surface. (benefits-navigator, 2026-07-13)

- **C3 — double-read.** KindredAccess added a single `ChatStatusAnnouncer` but left
  `role="status"`/`aria-live` on the visible typing/connection/presence nodes, so every change was
  read twice — the design review caught the spec reproducing the very double-read it set out to
  kill. Same trap for a `role="log"` transcript that already voices incoming messages.
  *Enforced:* KindredAccess `test_visible_status_nodes_are_at_silent`, shipped with the fix in
  `1b3506c` — but a regex over three named node ids, blind to a fourth indicator, nested regions, or
  `role="log"`. page-repair's is structural, but guards a surface whose announcer only writes into
  hidden regions — regression gate, not a fix. *Unenforced:* BN, CIT.
  (kindredaccess, 2026-07-13; page-repair gate, 2026-07-18)

- **C4 — color-scheme + contrast.** page-repair's options page declared no colors and no
  `color-scheme`, so contrast held in light but was unverified in dark; a `kbd` border at `#999` was
  already sub-3:1 even in light. *Enforced:* page-repair `test/contrast.mjs` recomputes every pair from
  the token hexes in both themes, **fail-closed** — a `:root` token in no verified pair fails the run.
  *Partial:* KindredAccess does real luminance math but two hardcoded 3:1 spot-checks only; CIT
  `tests/unit/a11y-css.test.ts` asserts ≥4.5:1 status text off `globals.css` but doesn't cover both
  themes. *Unenforced:* `packages/ui`, Keycloak theme, BN (declares `color-scheme`, asserts nothing).
  (page-repair, 2026-07-13)

## Identity, OIDC & mobile wrappers

- **Changing the shared IdP host silently strands every native wrapper — and each wrapper tech hides
  the host in a different place.** Migrating Keycloak to `id.beauaccesssolutions.com` was a one-line
  env change for the web apps, but three native surfaces had the old host baked in and would have
  bounced in-app login to Safari or blocked it: Access Atlas's Capacitor `server.allowNavigation`;
  KindredAccess with **no** `allowNavigation` *and* `WKAppBoundDomains` locked to its own domain under
  `limitsNavigationsToAppBoundDomains: true`; and CIT/Baseline baking `EXPO_PUBLIC_KEYCLOAK_ISSUER`
  into `eas.json` at **build** time. A green web `/oidc/…` redirect proves nothing about any of them.
  → Treat any issuer change as a **native release**: enumerate every wrapper in the same change, and
  keep the OLD host serving until the replacement builds ship. (bas-platform, 2026-07-17)

- **BAS realm client IDs are NOT uniformly suffixed — infer one and you'll wire an app to a client
  that doesn't exist.** The `bas` realm holds `cit-web`, `kindredaccess-web`, `benefits-navigator-web`,
  `disability-wiki-web` … but `access-atlas` (bare). Setting Disability Wiki's id to `disability-wiki`
  by analogy pointed it at a nonexistent client: fully configured-looking, failing only at login. →
  Verify against the realm — no admin creds needed: GET the authorize endpoint with the candidate id
  and **read the HTTP status, not the page body**: `302` = exists; `400` + "Invalid parameter:
  redirect_uri" = exists but that redirect isn't registered; `400` + "Client not found" = wrong id.
  ⚠️ Never discriminate on the themed "Sign in to bas" heading — Keycloak's *error* page carries an
  identical `<title>`, so grepping for it reports missing clients as present (an earlier draft of this
  entry recommended exactly that). (bas-platform, 2026-07-17)
