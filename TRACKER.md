# Platform Tracker

Living status board for the Beau Access Solutions accessibility-app platform. Update as
things move — this is the single place to see where everything stands.

**Last updated:** 2026-07-07
**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ⏳ blocked / waiting on input

---

## 1. Portfolio & platform onboarding

| App | Platform role | Stack | Remote | CLAUDE.md pointer | Onboarding |
|---|---|---|---|---|---|
| **Chronic Illness Tracker** | App #1 (PHI) | Next.js + Postgres | `kbeaudoin001/Chronic-Illness-Tracker` | ✅ branch pushed · ⬜ PR not opened | 🟡 leading |
| **KindredAccess** | App #2 | Django + Channels | `Beaudoin0zach/kindredaccess` | ✅ branch pushed · ⬜ PR not opened | ⬜ |
| **Benefits Navigator** | Candidate (sensitive) | Django + AI | `Beaudoin0zach/benefits_navigator` | ✅ branch pushed · ⬜ PR not opened | ⬜ |
| **Access Atlas** (access-directory) | Member (identity) | Astro | `Beaudoin0zach/access-atlas` | ✅ on `main` (no PR needed) | 🟡 onboarded (identity pending) |
| **a11y-probe** | Standalone / CI a11y | Reddit Devvit | none | ⏳ untracked (unborn repo) | n/a |
| **page-repair** | Standalone; patterns → `ui` | Browser extension | `LangworthyWatch/page-repair` | ✅ branch pushed · ⬜ PR not opened | n/a |
| **Marketing site** | Company site (not a platform app) | Astro + Netlify | local only (unpushed) | — | n/a |

**Pointer-PR rollout — all four are now clean one-commit branches off `main`, ready to open.** Open them here:
- CIT — <https://github.com/kbeaudoin001/Chronic-Illness-Tracker/compare/main...docs/bas-platform-pointer> (rebased onto main + squashed)
- KindredAccess — <https://github.com/Beaudoin0zach/kindredaccess/compare/main...docs/bas-platform-pointer> (direct merge-to-main blocked by safety classifier — open the PR, or add a Bash permission rule)
- Benefits Navigator — <https://github.com/Beaudoin0zach/benefits_navigator/compare/main...docs/bas-platform-pointer> (rebased onto main)
- page-repair — <https://github.com/LangworthyWatch/page-repair/compare/main...docs/bas-platform-pointer> (third-party repo)

---

## 2. Roadmap (from [PLATFORM.md](PLATFORM.md))

- **Phase 0 — Foundation** 🟡
  - ✅ Execution scoped ([docs/phase-0-execution.md](docs/phase-0-execution.md)) — owner split + decisions
  - ✅ DO deploy runbooks written ([Keycloak](docs/deploy/keycloak-digitalocean.md) · [CIT backend](docs/deploy/cit-backend-digitalocean.md))
  - 🟡 Keycloak: local dev scaffolded ([identity/dev/](identity/dev/)) · ⬜ prod stand-up on DO (needs Droplet + `id.` DNS)
  - ⬜ Deploy CIT backend to DO App Platform (spec: CIT `.do/app.yaml`)
  - ⬜ Monorepo scaffold (pnpm + Turborepo) + Expo skeleton
  - ⬜ Port CIT themes → reusable a11y-first `ui` primitives
  - ⬜ CI a11y + import-boundary gates
- **Phase 1 — Identity contract** ⬜
  - ⬜ OIDC clients + scopes on Keycloak
  - ⬜ `packages/auth` PKCE login + secure token storage
  - ⬜ Step-up (ACR) policy defined
- **Phase 2 — CIT as resource server** 🟡
  - ✅ Token-exchange spec (CIT `docs/mobile/auth-token-exchange.md`) — reconciled with the login-path seam
  - 🟡 `POST /api/auth/session` implemented — branch `feat/oidc-session-endpoint` (draft PR), 177 tests green. Verifies Keycloak OIDC (JWKS, `iss`/`aud`/`azp`), pairwise `oidcSub`, mints CIT session; `getSessionToken()` accepts Bearer. Inert until `KEYCLOAK_ISSUER`/`KEYCLOAK_CLIENT_ID` set. Guard/routes/middleware unchanged.
  - ✅ Rate-limiting / revocation / timing-equalized login preserved (OIDC-only accounts guarded in login + delete)
  - ⬜ Retire the password login path once Keycloak is live; wire the OIDC **step-up** for delete/export/regimen
  - ⬜ Test end-to-end against the local dev Keycloak ([identity/dev/](identity/dev/))
- **Phase 3 — Rebuild CIT in Expo** ⬜
  - ⬜ Rebuild 7 screens + 3 auth flows in RN
  - ⬜ Re-run a11y gates to parity (VoiceOver + TalkBack)
  - ⬜ i18n reusing CIT `locales/*.json`
  - ⬜ In-app account deletion (Apple 5.1.1(v))
- **Phase 4 — Ship to testers** ⬜
  - ⬜ EAS Build → TestFlight + Play internal + web
  - ⬜ Privacy nutrition labels / data-safety form
  - ⬜ Human-reviewed store copy (incl. Spanish)
- **Phase 5 — Generalize** ⬜
  - ⬜ KindredAccess consumes shared packages
  - ⬜ "Add a new app" playbook

---

## 3. Identity service (Keycloak) — [ADR-001](docs/adr/001-platform-architecture-and-identity.md)

Setup & hardening steps live in **[docs/keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md)** (drafted, not yet executed).

- ✅ Decision: standalone, self-hosted Keycloak
- ✅ Stand-up + hardening checklist drafted ([keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md))
- ⬜ Instance stood up (own DB, own deploy)
- ⬜ Hardening executed (admin-console lockdown, patching cadence)
- ⬜ Login theme re-themed to pass WCAG 2.2 AA
- ⬜ OIDC clients per app + `aud`/`azp` isolation
- ⬜ Pairwise subject identifiers per client ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md))
- ⬜ 2FA + step-up (ACR/LoA) policy
- ⬜ DR: Keycloak DB backup/restore + token signing-key rotation + availability target
- ⬜ Existing-user migration runbook — CIT first ([ADR-004](docs/adr/004-existing-user-migration.md))

---

## 4. App Store / Play prerequisites (CIT first)

- ⬜ Apple Developer Program — **$99/yr** (enrollment can take days — start early)
- ⬜ Google Play Developer — **$25 one-time**
- ⬜ Published privacy policy URL (CIT has a `/privacy` route — publish it)
- ⬜ In-app account deletion reachable (Apple 5.1.1(v))
- ⬜ App Privacy nutrition labels / Play data-safety form
- ⬜ No medical/diagnostic claims in copy or AI output (CIT non-negotiable #4)
- ⬜ App name availability check (both stores)

---

## 5. Open items / blockers

- ✅ **access-directory (Access Atlas) now has a remote** — `Beaudoin0zach/access-atlas` (public), onboarded on `main` with a governance pointer + inlined invariants (`docs/platform-membership.md`). Scoped as a full identity member: browsing stays account-free; identity gates contribution only; browsing surface stays Astro/zero-JS (no RN rewrite).
- ⏳ **a11y-probe is an unborn repo** (0 commits, no remote); pointer sits untracked until it's initialized.
- ⬜ **Open + merge the four pointer PRs** — branches are pushed but **no PR is open yet**; use the compare links in §1 to open them.
- ✅ **Push governance repo** — done (`main` live).
- ⬜ **Cross-app correlation** — adopt pairwise `sub` ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) before any app stores a shared identifier.
- ⬜ **Existing-user migration** into Keycloak ([ADR-004](docs/adr/004-existing-user-migration.md)) — CIT reference runbook, then KA + Benefits Navigator.
- ⏳ **Benefits Navigator data posture** — veteran data may carry Privacy Act / VA obligations distinct from HIPAA; determine like CIT's HIPAA question.
- ⬜ **Marketing-site GitHub repo name** — governance owns `Beau-Access-Solutions`; the site needs a different repo name (e.g. `bas-website`) when pushed.
- ⬜ Decide the shared-frontend repo name (`design-system`) when Phase 0 needs shared code.

---

## 6. Decision log

- [PLATFORM.md](PLATFORM.md) — architecture anchor
- [INVARIANTS.md](INVARIANTS.md) — the five platform invariants
- [ADR-001](docs/adr/001-platform-architecture-and-identity.md) — shared platform + standalone Keycloak identity
- [ADR-002](docs/adr/002-umbrella-org-and-repo-topology.md) — BAS umbrella, repo topology, no committed cross-repo symlinks
- [ADR-003](docs/adr/003-pairwise-subject-identifiers.md) — pairwise subject identifiers (no cross-app correlation)
- [ADR-004](docs/adr/004-existing-user-migration.md) — migrating existing users into Keycloak
- CIT `docs/adr/004` — CIT-side pointer to the identity decision
- CIT `docs/mobile/PLAN.md` — native build plan; `docs/mobile/auth-token-exchange.md` — token-exchange spec
