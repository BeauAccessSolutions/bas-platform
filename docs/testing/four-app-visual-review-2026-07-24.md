# Four-app visual review — 2026-07-24 (verified against code)

Source: a screenshots-only UX/design review of KindredAccess, Access Atlas, Chronic Illness
Tracker, and VA Benefits Navigator, produced 2026-07-24 by the user with chat Claude. The full
review is preserved verbatim in the session transcript. This file records **what code access
adds to it** — corrections, confirmations, and the overlap with the multi-role-matrix remediation
already in flight — so the review's stack inferences don't get acted on where they're wrong.

The review flagged its own confidence levels (`[Confirmed]` / `[Likely]` / `[Hypothesis]`) and
was explicit that stack guesses were inferred from screenshots for someone with code access to
confirm. This is that confirmation.

## The two Tier-1 "blocking" fixes are aimed at the wrong framework

Both are the review's top-priority items, and both would waste a session as written.

**CIT sign-in (review §5 Tier-1 #1, §3.3).** The review infers *Django + django-allauth* and
prescribes checking `SESSION_COOKIE_SAMESITE` in Django settings, on the theory that allauth
stores the OAuth `state` in the Django session and `SameSite=Strict` drops the cookie on the
Keycloak round-trip.

**CIT is Next.js + Prisma, not Django** (`package.json`: `next`, `@prisma/client`; no Django
anywhere). It has two auth paths: local email+password with argon2 and custom sessions
(`/api/auth/login`), and a platform-OIDC path that **verifies** a Keycloak id_token against JWKS
(`/api/auth/session` → `src/lib/auth/oidc.ts`). The session cookie is already `sameSite: 'lax'`
(`src/lib/auth/session.ts:60`), not Strict, and the OIDC path is token-verification, not a
redirect flow that stashes `state` in a session cookie — so there is no OAuth-state cookie to
lose. The entire primary hypothesis is off-target.

Where the real lead is: the last CIT commit before this review was
`5a49975 chore(auth): remove TEMPORARY OIDC verification diagnostics`, i.e. someone was recently
debugging OIDC *verification* 401s. A deterministic, restart-surviving failure of a token
verification points at issuer/audience/clock, not cookies:
- `KEYCLOAK_ISSUER` / `clientId` mismatch — and per platform memory, **client IDs across BAS
  Keycloak are not uniformly named; they must be verified, never inferred**, so a wrong audience
  is a known live risk here.
- Clock skew failing `iat`/`nbf` (the review's *secondary* hypothesis, which does apply to a
  verification path even though the primary one doesn't).
- The review's two stack-agnostic tips are good and stand: the Keycloak server log emits a typed
  `LOGIN_ERROR` with an `error=` field that names the cause, and a private-window attempt splits
  client-state from server-config. Start there.

This is worth its own focused session; it was not fixed in this pass.

**Access Atlas CSRF (review §5 Tier-1 #2, §3.2).** The review infers *SvelteKit + adapter-node*
and prescribes setting the `ORIGIN` env var (plus `PROTOCOL_HEADER`/`HOST_HEADER`) and never
setting `csrf.checkOrigin: false`.

**Access Atlas is Astro, not SvelteKit** (`package.json`: `astro`; `astro.config.mjs`,
`src/pages/*.astro`, `src/middleware.ts`). The "Cross-site POST form submissions are forbidden"
symptom is real and it is a CSRF origin rejection — but the SvelteKit `ORIGIN` env var does
nothing in Astro. Astro's equivalent is `security.checkOrigin` (on by default for SSR), which
compares the request `Origin` header against the derived site origin; behind a reverse proxy the
fix is making Astro trust the forwarded host/proto (the `Host`/`X-Forwarded-Host` the adapter
sees), or setting `site` in `astro.config.mjs` to the exact public URL. The review's underlying
advice — don't disable the check, fix the origin derivation — is correct; only the framework-
specific mechanism is wrong. The zero-JS posture (`src/lib/security.ts`, `script-src 'none'`)
also means any client-side CSRF-token scheme is out; this has to be solved at origin config.

## What the review found that the matrix sweep already fixed or is fixing

The review's dominant theme — "happy paths built, failure paths not; recovery from a bad state
missing" — is the same failure class the matrix targets, independently observed. Direct overlaps:

- **X3 / KindredAccess "Sign Out destroys a typed message" and send-failure data loss** overlaps
  [PR #20](https://github.com/BeauAccessSolutions/kindredaccess/pull/20) (F1), which makes a chat
  send survive connection loss with a pending/failed/retry state. *Caveat:* #20 covers the
  **send** path; a Sign Out mid-compose is a different trigger and is NOT yet covered — the
  composer is still the only copy of un-sent text at logout. Worth folding into the same model.
- **X3 / CIT draft loss** is closed by [PR #72](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/72)
  (C1) — draft persistence across navigation. Note the review's CIT finding is about *sign-in*,
  a different problem; the draft work still lands the review's cross-cutting X3 for CIT.
- **X2 / no recovery path** is the matrix's `ERR-01`/`ERR-02` and the research template's
  recovery-path section. The review's proposed shared error-state component is the right shape and
  is bigger than any single blocker fixed so far.

## Corrections and cautions on specific claims

- **KindredAccess timezone bug (§3.1 #1)** — plausible and not something the matrix tests; needs
  a code check of the two timestamp renderers. Not verified here.
- **KindredAccess `[Being reviewed…]` bracket text (§3.1 #3)** — this is real UI, and it is the
  same `image_moderation_status='pending'` path PR #20/#21 touch; the bracket copy comes from
  the chat template, not placeholder debris. A designed badge is a fair ask, separate from the
  audit work.
- **VA Nav "93% of C&P exams by contractors" (§3.4 #10)** and **"AI-powered assistance" framing
  (§3.4 #11)** — both are content/liability calls that belong with the same counsel review as the
  VSO pivot, not with engineering. #11 especially: for a VSO audience the accredited rep owns the
  work product, and the framing should say drafting-and-organizing-with-rep-review.
- **X4 leaked internal copy** — the KindredAccess Jinja comment rendering as body text is a real
  templating bug worth a grep sweep; the VA Nav "raw markdown" is the same defect as §3.4 #1
  (markdown stored, never rendered).

## The decision that gates the most work: §4.5

The review's structural section is correct that the VSO pivot turns VA Benefits Navigator into
exactly the caseload-scoped, multi-role app the research template and this whole matrix were built
for — and that **one question decides the scope**:

> Will VSOs enter veteran case data into this system, or will it stay a reference/preparation tool
> alongside their existing system of record?

- *Reference tool* → the segregation/audit/delegation layers defer; fix the UI defects and ship.
- *System of record* → POA-scoped ReBAC (VA Form 21-22 / 21-22a as the access primitive),
  org-as-tenant in Keycloak, 38 U.S.C. § 7332 segmentation, view-level audit, and break-glass all
  become launch requirements.

This connects directly to the existing [BN data-posture counsel brief](../legal/bn-data-posture-counsel-brief.md)
and [minors/delegation brief](../legal/minors-delegation-counsel-brief.md). The § 7332 point
(VA's stricter analog to 42 CFR Part 2, covering SUD/HIV/sickle-cell records with written-consent
redisclosure) is a genuinely new item those briefs don't yet cover and should be added. The
"replace self-serve signup with org-scoped invitation **before any veteran data enters**" point is
the one piece of §4 that is a hard prerequisite rather than a judgment call.

## Acted on (2026-07-24, same session)

- **Atlas CSRF** → fixed and PR'd, code-verified: [access-atlas#31](https://github.com/BeauAccessSolutions/access-atlas/pull/31).
  Root cause confirmed by reading `@astrojs/node@9.5.5` → `astro@5.18.2` internals: with
  `security.allowedDomains` empty, Astro refuses the proxy-forwarded host and falls back to
  `localhost`, so its computed origin is `https://localhost` while the browser sends the real
  host → the exact "Cross-site POST" rejection. Fix names the host via a build-time `SITE_ORIGINS`
  env (hostname-only patterns — a `protocol` field would route proto-validation through a dummy
  `example.com` and silently reintroduce the bug). Verified against the built standalone server
  with forged proxy headers: unset→403 (reproduces prod), set+real-origin→303, set+attacker→403.
- **CIT sign-in** → diagnosability fix PR'd: [Chronic-Illness-Tracker#73](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/73).
  The failing surface is the platform-OIDC path (`/api/auth/session` → `verifyIdentityToken`),
  which was blind by design — a deterministic failure logged nothing about *which* check failed.
  Now logs the jose error code + failing claim NAME (PHI-free; the decoded token is never touched),
  so the next failed login names its own cause (`aud`/`azp` client-id mismatch being the prime
  suspect, per the platform's non-uniform-client-id risk). Does not change auth behavior — the root
  config lives in the deployment/Keycloak registration, and the Keycloak `LOGIN_ERROR` event +
  a private-window retry remain the complementary diagnostics.

## Screenshot confirmations (2026-07-24)

The user's screenshots (`~/Desktop/SCREENSHOTS`) were reviewed and corroborate the review on screen:
- **KindredAccess** — the timezone bug is real and visible (a message stamped `1:06 PM` while the
  status bar reads `9:06` — UTC rendered without local conversion); the leaked Jinja comment
  (`{# Advanced filters live inside the SAME form… #}`) renders as body text; `[Baby]` /
  `[Being reviewed…]` bracket copy; Sign Out is the only bordered nav control; the composer wraps;
  "Press Enter … Shift+Enter" desktop hint on mobile; the status-bar toast overlap.
- **VA Benefits Navigator** — unstyled allauth confirmed across both the signup form AND the
  `socialaccount` "Sign In Via Beau Access Solutions … Continue" intermediate page (plain-text
  "Continue", no button); raw markdown (`## What is a C&P Exam?`, `**Key Facts:**`) rendered
  literally with a duplicated H1/H2; the "93% contractors" stat; Feedback widget occluding content.
- **Access Atlas** — the gated "Suggest a place" form shown to signed-out users; the fieldset
  legend collision; the status-bar overlap on the landing page; the praised trust-labeling copy.

Not located among the 9 reviewed: the CIT sign-in error screen itself (all 9 were BN/KA/AA) —
which is why #73 is a make-it-diagnosable fix rather than a root-cause fix.

- **X1 safe-area inset** → fixed across all four apps (one PR each): Atlas
  [#32](https://github.com/BeauAccessSolutions/access-atlas/pull/32), KA
  [#22](https://github.com/BeauAccessSolutions/kindredaccess/pull/22), CIT
  [#74](https://github.com/BeauAccessSolutions/Chronic-Illness-Tracker/pull/74), BN
  [#71](https://github.com/BeauAccessSolutions/benefits_navigator/pull/71).
  The review's guessed cause (viewport-fit=cover *without* padding) was close but incomplete: the
  real mechanism is (a) `env(safe-area-inset-*)` is `0` unless `viewport-fit=cover` is set — so KA's
  existing bottom-inset rules were already dead no-ops — and (b) padding the scroll container can't
  fix it because that padding scrolls away; only a FIXED backdrop stays over the status-bar zone.
  Three apps (Atlas/KA/BN) have non-sticky headers → fixed strip in the brand/header color. CIT's
  header is already sticky → pad the header instead (a fixed strip would clip it). BN's CSP forced a
  linked stylesheet (`style-src 'self'`, no unsafe-inline); KA's allows inline. All gated on
  `env()`=0 → inert on desktop/non-notched. **All four need on-device verification** — the mechanism
  is verified (builds/tests pass) but the visual result on a real notch is not.

## Not acted on in this pass

The rest of the review's backlog. Next quick, correctly-targeted move: the `short_name` manifest
truncation (icons), and the KA sign-out-mid-compose gap (#20 covers send-failure, not logout).
