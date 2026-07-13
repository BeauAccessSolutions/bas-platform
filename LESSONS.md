# BAS Platform Lessons

**What this is:** lessons that transfer **between Beau Access Solutions apps** but are
too platform-specific for the machine-wide `~/.claude/shared/LESSONS.md`. Identity/
Keycloak/OIDC gotchas, shared-UI and cross-app conventions, wrapper/deploy patterns.
Each BAS app's `CLAUDE.md` should import this file alongside the shared one:

```
@~/.claude/shared/LESSONS.md
@~/projects/bas-platform/LESSONS.md
```

**Scope rule:** BAS-wide only. Machine-wide transferable lessons (tooling, generic ops,
process) go in the shared file. Single-app facts go in that app's own `CLAUDE.md` or
memory. If an entry stops being true (e.g., an IdP config lands), update or delete it —
stale platform facts are worse than none.

Format per entry: **Lesson** — what broke / what's true → the fix or rule. `(source-app, YYYY-MM-DD)`

---

## Identity & OIDC (Keycloak)

- **Pairwise `sub` is an invariant (ADR-003), but the dev realm doesn't emit it yet —
  verify from a real token, not from config.** The `cit-web` pairwise mapper was
  silently rejected because multi-host redirect URIs require a **Sector Identifier
  URI**; the provisioning script's `|| echo` masked the failure and a correlatable
  `sub` shipped. → Before onboarding any app to the IdP: decode an actual token and
  confirm the `sub` differs per client; set a Sector Identifier URI whenever a client
  has redirect URIs on more than one host. (bas-platform, 2026-07-08)

- **The proven RP integration shape is KindredAccess's: inert-by-default, confidential
  client + PKCE, legacy login kept as a migration-window fallback.** `OIDC_ENABLED`
  gates everything (settings, middleware, URL mounts, auth backends) so the branch can
  merge without the IdP being ready, and `/accounts/login/` keeps working during
  cutover. → Reuse this pattern (see `mysite/oidc_config.py` on
  `feat/bas-keycloak-oidc`) for the next app instead of designing a new integration.
  (kindredaccess, 2026-07-08)

- **Local auth hardening must not silently vanish at SSO cutover.** KindredAccess now
  enforces TOTP 2FA at login, per-username failure lockout, and strict-path rate
  limits **locally**. When an app's login moves to Keycloak, those protections stop
  applying unless the realm provides equivalents (Keycloak OTP policy, brute-force
  detection). → SSO-cutover checklist per app: enumerate the local auth protections
  and confirm each has an IdP-side equivalent turned on *before* the legacy form is
  retired. (kindredaccess, 2026-07-13)

- **Account linking by email requires identical normalization at every auth entry point.**
  CIT's local signup stored emails verbatim while the OIDC session exchange lowercased
  before lookup — a mixed-case local account never linked, so platform login silently
  created a **second empty account** (user experience: "my health data vanished"). A code
  comment even claimed the shared normalization existed when it didn't. → One shared
  normalizing schema (trim + lowercase) used by *every* path that reads or writes the
  identifier, and the data migration fails loudly on case-variant duplicates — merging two
  people's records is never a migration's call. Check this on every app that adds the
  Keycloak exchange. (chronic-illness-tracker, 2026-07-13)

## Mobile wrappers

- **iOS App-Bound Domains must include every domain the auth flow touches.** The
  KindredAccess Capacitor wrapper locks `WKAppBoundDomains` to `kindredaccess.org`;
  when OIDC goes live, the in-app browser must also reach the IdP host or the login
  redirect dead-ends inside the wrapper. → When wrapping any BAS app, list the IdP
  domain (and any consent/payment hosts) in `WKAppBoundDomains` and test the full
  round-trip login inside the wrapper, not just Safari. (kindredaccess-ios, 2026-07-13)

## Accessibility engineering & user testing

- **A banner rendered into the initial HTML after a redirect is NOT reliably
  auto-announced, even with `role="status"`/`role="alert"`.** Our zero-JS pattern (POST →
  303 → server-rendered message) hits this everywhere; VoiceOver + Safari especially may
  not speak load-time live regions, so "you should hear it automatically" expectations
  generate false failures. → Write the requirement as "message at/near the top, before the
  h1, easy to find"; record whether it was auto-spoken as data, not pass/fail. Applies to
  every zero-JS BAS form flow. (access-directory, 2026-07-13)

- **Fieldsets defeat zoom reflow — `min-inline-size: min-content` + a `<select>`'s intrinsic
  width force horizontal scroll at high zoom.** Fix: `form fieldset { min-inline-size: 0 }`.
  *Enforced:* access-directory `tests/a11y/pages.spec.ts` "no horizontal overflow at 320px"
  runs on every route (WCAG 1.4.10 ≙ 400% zoom) — adopt as a platform-default CI check for
  every BAS app. (access-directory, 2026-07-13)

- **User-testing sessions must not collect the sensitive data the product refuses to
  collect.** "Fill the form honestly" plus optional disability-identity checkboxes would
  have logged real disability data against identifiable testers — the exact data our
  privacy rules forbid holding. → Scripts state that test answers never need to be true
  about the tester; facilitators supply values; notes carry tester codes only (mapping
  held off-repo); a db reset between testers wipes everything a session created. Adopt for
  any BAS study touching identity or health-adjacent fields. (access-directory, 2026-07-13)

## Shared UI & accessibility

- **Never hardcode `text-white` on themed fills — define `--on-<color>` tokens and
  machine-verify every used fg/bg pair in both themes.** White passed CIT's light-mode
  primary (5.0:1) but measured **2.1:1** on the lighter dark-mode fill — every primary
  button unreadable for users disproportionately in dark mode at night, and the palette's
  contrast comments had drifted from the real values. → Pair every themed fill with an
  on-color token (white in light, dark charcoal in dark) and add a test that reads token
  values from the stylesheet and asserts ≥4.5:1 (text) / ≥3:1 (UI boundaries) per used
  pair per theme. Applies to the shared Expo/RN-Web design system as it lands.
  (chronic-illness-tracker, 2026-07-13)

- **A per-route `script-src` relaxation must relax BOTH the meta and the header CSP, and
  `Permissions-Policy: geolocation=()` blocks `navigator.geolocation` even when the script
  loads.** Adding the on-device "sort by distance" enhancement to the zero-JS browsing
  surface needed `script-src 'self'` on two routes — but browsers enforce the INTERSECTION
  of the `<meta>` CSP and the HTTP-header CSP, so relaxing only one still blocks the script,
  and the platform-default `Permissions-Policy: geolocation=()` disables geolocation
  regardless of CSP. → When any BAS app scopes JS/geolocation/camera to a route, relax the
  meta and header together per-route AND flip the matching `Permissions-Policy` feature to
  `(self)` on that route only; assert the headers on the enhanced route vs. a sibling route
  in CI. (access-directory, 2026-07-13)

## Cross-app safety & compliance conventions

- **Adoption rule: the fail-closed safety/alert pattern (see shared LESSONS) is the
  platform default.** Any BAS app with report/flag/moderation flows uses fail-closed
  alert-recipient settings + negative tests; reference implementation is KindredAccess's
  `SAFETY_ALERT_EMAIL` → `ADMINS` + `notify_admins_*` tests. (kindredaccess, 2026-07-13)

- **Safety-critical actions must work without JavaScript.** Block/report/consent in
  KindredAccess were JS-only buttons that rendered but did nothing with JS off — for
  our audience (AT users, old devices, flaky rural connections) that's a hard fail.
  → Platform rule: consent grants and safety actions are real form submits with
  server-side validation and a server-rendered confirm fallback; JS is enhancement
  only. Test the no-JS path with the plain Django/HTTP test client. (kindredaccess,
  2026-07-13)
