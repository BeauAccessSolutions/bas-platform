# PLATFORM.md — Shared platform architecture

Status: **draft for review** · Owner: Beau Access Solutions LLC · Last updated: 2026-07-07

How the portfolio's apps become a shared platform that share **identity** and a
**design system** but keep their own backends and data. This is the canonical anchor
doc and contributor onboarding reference. The identity decision is
[ADR-001](docs/adr/001-platform-architecture-and-identity.md); the umbrella/repo
topology is [ADR-002](docs/adr/002-umbrella-org-and-repo-topology.md).

Canonical home: this repo (`Beaudoin0zach/Beau-Access-Solutions`). App repos reference
it by URL, never by filesystem path.

---

## 1. The shape

Shared identity across **mixed backends** (CIT = Next.js, KindredAccess = Django,
future apps = various) is the load-bearing constraint. You cannot put login inside any
one app's backend if the others run different stacks. So identity is a **standalone,
standards-based service** (OIDC/OAuth2) that every app's backend trusts. Everything
else that's safe to share — the frontend, the design system, the auth *client* — is
shared; anything security-, privacy-, or content-sensitive stays sovereign to each app.

```
                    ┌───────────────────────────┐
                    │  Identity service (IdP)    │   standalone, minimal, hardened
                    │  Keycloak, self-hosted     │   issues short-lived OIDC tokens
                    │  own DB · own deploy       │   stores identity only, never PHI
                    └────────────┬──────────────┘
                                 │ OIDC token (PKCE)
             ┌───────────────────┼────────────────────┐
             ▼                   ▼                     ▼
    ┌────────────────┐  ┌────────────────┐   ┌────────────────┐
    │ CIT (Next.js)  │  │ KindredAccess  │   │  future app     │
    │ resource server│  │ (Django, DRF)  │   │  (any stack)    │
    │ + its OWN       │  │ + its own      │   │                 │
    │ data-access    │  │ data-access    │   │                 │
    │ session        │  │ session        │   │                 │
    └────────────────┘  └────────────────┘   └────────────────┘
    Each validates the identity token, then mints its own revocable session.

Shared monorepo (pnpm + Turborepo) — low-sensitivity code ONLY:
  apps/*            Expo (React Native + RN Web) → iOS + Android + web
  packages/ui       accessibility-first design system (telemetry-free)
  packages/auth     OIDC/PKCE login flow + secure token storage
  packages/api-client typed clients per backend
  packages/config   tsconfig, eslint (incl. a11y + import-boundary rules), CI gates

Sensitive backends stay OUT of the shared monorepo, each in its own repo:
  CIT's Next.js backend  ·  KindredAccess's Django backend  ·  the IdP
  (trust boundary = repo boundary; PHI paths get their own review gate)
```

## 2. Identity: Keycloak, self-hosted, standalone from day one

**Decision:** a standalone, self-hosted **Keycloak** instance is the platform IdP.
Not bolted onto any app's backend. See
[ADR-001](docs/adr/001-platform-architecture-and-identity.md) for the full rationale
and the options weighed (Zitadel, Ory Hydra, managed+BAA).

Why standalone (not hosted inside an app): once an app's backend mints the token that
unlocks someone's symptom log, a compromise of that app's much larger attack surface
becomes a compromise of health-data authentication. That blast radius is unacceptable
for a PHI tenant. The IdP is therefore minimal, isolated, and hardened, with its own
DB and deploy, decoupled from any app's uptime or churn.

Why self-hosted (not managed): a shared IdP records which OAuth clients a user
authorized — i.e. that an account holds a grant for the *chronic-illness* app, which
is health-revealing. A managed IdP would sit in that sensitive path and require a BAA
on an enterprise tier. Self-hosting keeps no third party in the auth path.

Why Keycloak specifically: the boring, proven, hire-able option. Batteries-included
user store, 2FA (TOTP/WebAuthn), and step-up auth (ACR/LoA) — so security-critical
flows are battle-tested rather than hand-rolled. Cost accepted: a heavier service to
run/patch, and its login theme must be re-themed to pass each app's a11y bar (e.g.
CIT's WCAG 2.2 AA).

**Login is Keycloak-hosted, not re-implemented in the app.** Native (Expo) and web
clients open Keycloak's hosted login page in the system browser via the standard
Authorization-Code-+-PKCE (AppAuth) redirect; `packages/auth` orchestrates the PKCE
flow and secure token storage — it does **not** render a custom username/password form.
A custom in-app credential form would defeat federation, 2FA, and step-up, and is
treated as an anti-pattern. This is why Keycloak's *login theme* (not an app screen) is
the surface that must pass each app's a11y bar.

**Per-app pseudonymous identity.** Each OIDC client receives a different, stable
pairwise `sub` for the same user, so no two apps can correlate a shared user from
tokens or data — the health/dating/benefits correlation lives only inside the IdP. See
[ADR-003](docs/adr/003-pairwise-subject-identifiers.md).

## 3. The layered-session rule (the core auth invariant)

**Federate authentication; never surrender the sensitive-data session.**

- The IdP proves *who you are* → issues a short-lived OIDC token.
- Sensitive apps (CIT; KA for its own private data) **exchange** that token for their
  **own** short-lived, revocable, rate-limited data-access session, and require
  **step-up re-auth** for sensitive actions.
- So a stolen identity token does **not** hand an attacker an app's sensitive-data
  session; the app keeps its own revocation, throttling, and timing-equalized login.

> **"Exchange" here means validate-then-establish-a-local-session** — not RFC 8693
> token exchange. The app verifies the OIDC token's signature and claims against
> Keycloak's JWKS, then mints its own session. No special Keycloak token-exchange
> feature is required; don't reach for one.

For CIT the migration surface is tiny — but it lives in the **login path, not the
per-request guard**. CIT's own session layer (`src/lib/auth/session.ts` — hashed
tokens, TTL, revocation) already *is* the app-owned data-access session this rule calls
for, so it stays. Only session **establishment** changes: `createSession()` is called
in exactly two places (`src/app/api/auth/login/route.ts` and `.../signup/route.ts`),
plus a new OIDC callback — these swap *password-verification → `createSession()`* for
*Keycloak-OIDC-verification → `createSession()`*. The per-request guard (`requireAuth()`
/ `getAuthenticatedUserId()`), all ~30 route handlers, the 7 Server Components that read
the session directly, and the edge middleware are **untouched**, and there is no
per-request token exchange or JWKS call (that happens once, at login). Full spec:
CIT repo `docs/mobile/auth-token-exchange.md`.

## 4. Platform invariants

See **[INVARIANTS.md](INVARIANTS.md)** for the enforced-by-construction detail. In brief:
1. **Layered sessions** — identity token ≠ data credential; each sensitive app mints its own session + step-up.
2. **No platform tracking on sensitive pages** — telemetry-free `ui`; import-boundary lint; per-app CSP.
3. **Decoupled deletion/export** — identity stores identity only; each app owns its data lifecycle.
4. **Contribution boundary** — sensitive backends in their own repos behind review; shared packages open.
5. **i18n ownership** — no hardcoded strings in `ui`; per-app catalogs + human-review gates.

These map directly onto each app's own non-negotiables and never relax them. See also
[ADR-003](docs/adr/003-pairwise-subject-identifiers.md) (per-app pairwise `sub`, no
cross-app correlation) and [ADR-004](docs/adr/004-existing-user-migration.md)
(migrating existing accounts into Keycloak without a mass reset).

## 5. Sequencing — CIT is app #1

Once identity became a standalone service, KindredAccess lost its only structural
claim to leading (it was going to *host* identity). CIT leads because:

1. **Smallest surface = fastest proof** (7 app screens + 3 auth, vs KA's social app + chat).
2. **Highest a11y bar forges the best design system** — if `packages/ui` is born
   passing CIT's WCAG 2.2 AA + axe gates, every later app inherits components proven
   at the strictest level.
3. **Layered sessions mean CIT doesn't wait on a mature IdP** — it validates a token
   and keeps its own hardened session (already built). A minimal day-one Keycloak suffices.
4. **The repo-boundary invariant bounds risk** — platform experimentation lives in
   non-PHI shared packages + the IdP; CIT's backend only does its single
   `requireAuth()` swap after the contract is proven.

## 6. Roadmap

| Phase | What | Outcome |
|---|---|---|
| **0. Foundation** | Standalone Keycloak (own deploy + DB, hardened); monorepo (pnpm + Turborepo); Expo skeleton; port CIT's themes (dark / high-contrast / dyslexia / text-size / reduced-motion) into reusable a11y-first `ui` primitives; CI a11y + import-boundary gates | Skeleton that proves the shape |
| **1. Identity contract** | OIDC/OAuth2 clients + scopes on Keycloak; `packages/auth` PKCE login; secure token storage (`expo-secure-store`); step-up policy | Login all future apps reuse |
| **2. CIT as resource server** | Swap CIT's `requireAuth()` to token-exchange + own data-access session; keep rate-limiting/revocation/timing-equalized login; deploy CIT backend | CIT authenticating via the platform |
| **3. Rebuild CIT in Expo** | Rebuild the 7 screens + 3 auth flows in RN; re-run a11y gates to parity; i18n reusing CIT's `locales/*.json`; in-app account deletion (Apple 5.1.1(v)) | CIT running on the foundation |
| **4. Ship to testers** | EAS Build → TestFlight + Play internal + web deploy; privacy nutrition labels; human-reviewed store copy; community install guide | CIT in testers' hands |
| **5. Generalize** | KindredAccess consumes shared packages; document "add a new app"; contribution guardrails live | Portfolio velocity |

## 7. Risks to hold

- **Multi-month program, not weeks.** Rebuilding CIT's server-rendered flows in RN is real work.
- **Re-verify accessibility, don't assume it.** RN Web ≠ hand-authored WCAG-audited HTML; the axe gate must pass again on the new stack. Non-negotiable.
- **Over-building the platform before app #1 ships** is the failure mode. CIT-first discipline is the guardrail.
- **Keycloak operational hardening** — a self-run service in the auth path: patching, admin-console lockdown, login-theme a11y are ongoing owner work.
- **The IdP is the platform's single point of failure — plan its availability, not just its hardening.** Keycloak DB backup/restore (losing it loses all federated identity), token signing-key rotation, and an availability target are Phase-0 deliverables, not afterthoughts. Mitigating property worth noting: because of layered sessions (§3), a brief IdP outage does **not** log everyone out — apps hold their own data-access sessions; only *new* logins and token refresh fail while it's down.
- **Existing users must be migrated, not stranded.** CIT, KA, and Benefits Navigator have live accounts; onboarding each to Keycloak is a real workstream ([ADR-004](docs/adr/004-existing-user-migration.md)), gated ahead of that app's `requireAuth()` swap.
