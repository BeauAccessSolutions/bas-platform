# Platform Tracker

Living status board for the Beau Access Solutions accessibility-app platform. Update as
things move — this is the single place to see where everything stands.

**Last updated:** 2026-07-09 (reconciled against real repo state via `/platform-status`)
**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ⏳ blocked / waiting on input

---

## 1. Portfolio & platform onboarding

| App | Platform role | Stack | Remote | CLAUDE.md pointer | Onboarding |
|---|---|---|---|---|---|
| **Chronic Illness Tracker** | App #1 (PHI) | Next.js + Postgres | `Beaudoin0zach/Chronic-Illness-Tracker` | ✅ branch pushed · ✅ **pointer PR open** | 🟡 leading |
| **KindredAccess** | App #2 | Django + Channels | `Beaudoin0zach/kindredaccess` | ✅ branch pushed · ✅ **pointer PR #2 open** | 🟡 OIDC RP integrated ahead of seq. (PR #4) |
| **Benefits Navigator** | Candidate (sensitive) | Django + AI | `Beaudoin0zach/benefits_navigator` | ✅ branch pushed · ✅ **pointer PR #23 open** (+ 10 other open PRs incl. #20 privacy-hardening, #22 governance, #24 membership) | ⬜ |
| **Access Atlas** (access-directory) | Member (identity) | Astro | `Beaudoin0zach/access-atlas` | ✅ pointer on `main` · ✅ **invariant PR #1 open** | 🟡 onboarded · invariants #2/#3/#4 ✅ · identity #1 🟡 (drop-in Keycloak BFF auth on branch) · #5 ⏳ |
| **a11y-probe** | Standalone / CI a11y | Reddit Devvit | none | ⏳ untracked (unborn repo) | n/a |
| **page-repair** | Standalone; patterns → `ui` | Browser extension | `LangworthyWatch/page-repair` (canonical) · `Beaudoin0zach/page-repair` (origin) | ✅ branch pushed · ⏳ pointer PR status unverifiable from this account | n/a |
| **Marketing site** | Company site (not a platform app) | Astro + Netlify | local only (unpushed) | — | n/a |

**Pointer-PR rollout — the pointer/onboarding PRs are now OPEN, not just ready.** Review + merge:
- CIT — **pointer PR open** on `Beaudoin0zach/Chronic-Illness-Tracker` (`docs/bas-platform-pointer`)
- KindredAccess — **PR #2 open** <https://github.com/Beaudoin0zach/kindredaccess/pull/2> (`docs/bas-platform-pointer`)
- Benefits Navigator — **PR #23 open** <https://github.com/Beaudoin0zach/benefits_navigator/pull/23> (`docs/bas-platform-pointer`)
- page-repair — pointer PR status **unverifiable** from this GitHub account (`LangworthyWatch/page-repair` is third-party); confirm directly there.

---

## 2. Deployment & hosting

Where each app is meant to run, and whether it's actually there yet. "Artifact" =
what gets shipped; "Trigger" = how a deploy happens.

| App | Artifact | Host / platform | Config source | Trigger | URL / DNS | Status |
|---|---|---|---|---|---|---|
| **Chronic Illness Tracker** | Next.js web + managed Postgres 17 | **DigitalOcean App Platform** (region `nyc`, `basic-xxs`) | [`.do/app.yaml`](repos/chronic-illness-tracker/.do/app.yaml) — repo `Beaudoin0zach/Chronic-Illness-Tracker`, health `/api/health`, pre-deploy `prisma migrate deploy` | `deploy_on_push` on `main` | ⬜ no domain yet | ⬜ **not deployed** (spec ready) |
| **Benefits Navigator** | Django + Celery + Redis | **DigitalOcean App Platform** (region NYC, App ID `2119eba2-07b6-405f-a962-d40dd6956137`) | [`DEPLOYMENT.md`](repos/benefits-navigator/DEPLOYMENT.md), `Dockerfile.prod` | git push | 🟢 <https://benefits-navigator-staging-3o4rq.ondigitalocean.app> | 🟡 **staging live** · ⬜ prod |
| **KindredAccess** | Django web backend + Capacitor mobile shell | **DigitalOcean Droplet** (Ubuntu 22.04, $12–18/mo) | [`DIGITAL_OCEAN_DEPLOYMENT.md`](repos/kindredaccess/DIGITAL_OCEAN_DEPLOYMENT.md) + `deploy/` systemd units (Gunicorn HTTP + **Daphne WebSockets**, nginx `/ws/` routing) — KA PR #3 | manual (SSH) | ⬜ DNS TBD | ⬜ **not deployed** (WS deploy config now correct) |
| **Access Atlas** (access-directory) | Astro static (zero-JS) + Supabase | ⏳ **undecided** — data entity/hosting is an org/legal call, not a code one (README §13) | none committed | — | ⬜ | ⏳ **host not chosen** |
| **a11y-probe** | Reddit Devvit app (client + server bundle) | **Reddit Devvit** platform | [`devvit.json`](repos/a11y-probe/devvit.json) | `devvit upload` / `publish` | Reddit-hosted | ⏳ **unborn repo**, not published |
| **page-repair** (extension) | Browser extension (MV3) | **Chrome Web Store / AMO** | [`manifest.json`](repos/page-repair/manifest.json) v1.0.0 + icons · [`PRIVACY.md`](repos/page-repair/PRIVACY.md) · [`STORE_LISTING.md`](repos/page-repair/STORE_LISTING.md) · `dist/page-repair.zip` | store submission | store listing | 🟡 **submission-ready** · ⬜ not submitted (needs dev account + screenshots) |
| **page-repair** (credit proxy) | Cloudflare Worker + KV | **Cloudflare Workers** | [`proxy/wrangler.jsonc`](repos/page-repair/proxy/wrangler.jsonc) | `wrangler deploy` (manual) | 🟢 <https://page-repair-proxy.airboat-webcast-5u.workers.dev> | 🟡 **live but inert** — `ANTHROPIC_API_KEY` secret unset; health-route change pending redeploy |
| **Marketing site** | Astro static | **Netlify** | [`netlify.toml`](repos/marketing-site/netlify.toml) — build `dist`, SPA redirect, security headers | Netlify git deploy | ⬜ | ⬜ **local only, unpushed** |
| **Keycloak** (identity infra) | Self-hosted Keycloak + own DB | **DigitalOcean** (Droplet) | [docs/deploy/keycloak-digitalocean.md](docs/deploy/keycloak-digitalocean.md) | manual | ⬜ `id.<domain>` DNS TBD | ⬜ **prod not stood up** |

**What this shows:**

- **DigitalOcean is the platform default** — CIT, Benefits Navigator, KindredAccess, and Keycloak all target DO (App Platform for the first two, Droplets for KA + Keycloak).
- **What's actually live today:** Benefits Navigator **staging**, and the **page-repair credit proxy** (Cloudflare Worker) — though the proxy is inert until its `ANTHROPIC_API_KEY` secret is set. Everything else is spec-ready, unpushed, unborn, or undecided.
- **Two genuinely open hosting decisions:** Access Atlas (blocked on an org/legal data-entity call) and the marketing site (needs a repo — governance owns `Beau-Access-Solutions`; site needs e.g. `bas-website` — then a Netlify connect).
- **No production DNS is wired for anything yet**, including the `id.` subdomain Keycloak needs before OIDC can go live.
- **Non-server distribution:** a11y-probe ships through Reddit's Devvit platform and page-repair through browser extension stores — neither is a host we operate.

---

## 3. Roadmap (from [PLATFORM.md](PLATFORM.md))

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
  - ✅ **Branch reconciliation done** — a divergent duplicate (`feat/oidc-resource-server`, `keycloakSub`) was salvage-checked and deleted. It lacked the OIDC tests **and** the `azp` sibling-app-token rejection + clock-tolerance the canonical branch has, so nothing to cherry-pick (optional tiny follow-up: canonical could also read the `name` claim to seed `User.name`). `feat/oidc-session-endpoint` is the single canonical OIDC branch.
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
  - 🟡 **KindredAccess OIDC RP done ahead of sequence** (2026-07-08) — Django resource server integrated with `mozilla-django-oidc` (confidential client + PKCE S256), verified end-to-end against the local dev Keycloak incl. a genuinely pairwise `sub`. Layered session (validate vs JWKS → mint Django session), verified-email linking (ADR-004), `azp` sibling-app rejection. Inert until `KEYCLOAK_ISSUER`/`OIDC_RP_CLIENT_ID` set. Branch `feat/bas-keycloak-oidc` (KA PR #4), 346 tests green. Existing-user migration + prod still pending — see §6.
  - ⬜ KindredAccess consumes shared packages (`ui`/`auth`)
  - ⬜ "Add a new app" playbook

---

## 4. Identity service (Keycloak) — [ADR-001](docs/adr/001-platform-architecture-and-identity.md)

Setup & hardening steps live in **[docs/keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md)** (drafted, not yet executed).

- ✅ Decision: standalone, self-hosted Keycloak
- ✅ Stand-up + hardening checklist drafted ([keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md))
- ⬜ Instance stood up (own DB, own deploy)
- ⬜ Hardening executed (admin-console lockdown, patching cadence)
- ⬜ Login theme re-themed to pass WCAG 2.2 AA
- 🟡 OIDC clients per app + `aud`/`azp` isolation — **dev:** `cit-web` + `kindredaccess-web` created in the `bas` realm; KA verified to reject a sibling `azp`. ⬜ prod
- 🟡 Pairwise subject identifiers per client ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) — **dev:** working for `kindredaccess-web` (`oidc-sha256-pairwise-sub-mapper`, salted; sub ≠ raw user id, verified). Reference bootstrap corrected for both clients (was a no-op `oidc-sub-mapper`). ⬜ prod sector-identifier/salt strategy
- ⬜ 2FA + step-up (ACR/LoA) policy
- ⬜ DR: Keycloak DB backup/restore + token signing-key rotation + availability target
- ⬜ Existing-user migration runbook — CIT first ([ADR-004](docs/adr/004-existing-user-migration.md))

---

## 5. App Store / Play prerequisites (CIT first)

- ⬜ Apple Developer Program — **$99/yr** (enrollment can take days — start early)
- ⬜ Google Play Developer — **$25 one-time**
- ⬜ Published privacy policy URL (CIT has a `/privacy` route — publish it)
- ✅ In-app account deletion reachable (Apple 5.1.1(v)) — CIT: `POST /api/auth/delete-account` (password + typed `DELETE`) wired to the Settings danger zone; real cascade + on-disk export purge
- ⬜ App Privacy nutrition labels / Play data-safety form
- ⬜ No medical/diagnostic claims in copy or AI output (CIT non-negotiable #4)
- ⬜ App name availability check (both stores)

---

## 6. Open items / blockers

- 🟡 **CIT launch-readiness sweep (2026-07-08)** — landed on branch `chore/launch-prep` (pushed to `Beaudoin0zach/Chronic-Illness-Tracker`, 2 commits; **PR not opened** — <https://github.com/Beaudoin0zach/Chronic-Illness-Tracker/compare/main...chore/launch-prep>). ⚠ Branched off `fix/security-audit-batch-4`, so it currently stacks on the unmerged security work.
  - ✅ **Full-app i18n** — closes non-negotiable #10 (was a hard launch gate). next-intl is now actually wired (plugin + provider + dynamic `lang`); all ~35 pages/components render from `locales/en.json` (~250 new keys). `RELEASED_LOCALES=['en']` structurally blocks the unreviewed `es.json` from ever being served (#11). Reuses `locales/*.json` cleanly for the eventual Expo rebuild (Phase 3).
  - ✅ **CI backstop** — `.github/workflows/ci.yml` runs lint + 188 tests + build on every push/PR to `main` (there was none). Doubles as the a11y/import-boundary gate seam for Phase 0.
  - ✅ **Change-password + "log out other devices"** — new endpoints wired into Settings; first real trigger for session revocation. (Password login is retired later once Keycloak is live — Phase 2.)
  - ✅ **macOS PHI pre-commit hook** — was a silent no-op (`grep -P` on BSD grep); reimplemented in python3.
  - ✅ **Security-audit batches 1–4 are now merged to `main`** (`fix/security-audit-batch-1..4`), so that gate is cleared. `chore/launch-prep` itself may still be unmerged. Still to do before a live deploy: **rotate the Anthropic API key** (real key in local `.env`), and no scheduled AI-retention job yet.
  - ✅ **Signup account-enumeration closed** — email-verification signup via Postmark (**CIT PR #2 merged to `main`**). Replaces the `409 email_taken` oracle with a uniform `202`; login now blocked until verified. ⚠ **Deploy gate:** the live app needs `EMAIL_PROVIDER=postmark` + `POSTMARK_API_TOKEN` + `EMAIL_FROM` set or **no one can sign in** (main has `deploy_on_push`). Note CI did not gate this merge — the CIT repo's GitHub Actions have never fired since the migration to `Beaudoin0zach` (config is correct; needs the Actions tab enabled / a `workflow_dispatch` trigger).
- ✅ **access-directory (Access Atlas) now has a remote** — `Beaudoin0zach/access-atlas` (public), onboarded on `main` with a governance pointer + inlined invariants (`docs/platform-membership.md`). Scoped as a full identity member: browsing stays account-free; identity gates contribution only; browsing surface stays Astro/zero-JS (no RN rewrite).
- 🟡 **Access Atlas app-side invariants — 3 of 5 landed on a branch** (`platform-seed-and-data-rights`, pushed; **PR #1 open** — <https://github.com/Beaudoin0zach/access-atlas/pull/1>):
  - ✅ **#2 tracking/CSP** — own CSP + security headers (one policy, applied as `<meta>` for static pages + HTTP headers for SSR); `script-src 'none'` makes its zero-JS surface self-enforcing.
  - ✅ **#3 decoupled delete/export** — complete, independently-callable workflow (`src/lib/data-rights.ts` + ops CLI, storage-aware, idempotent, unit-tested), keyed by contributor id so the Keycloak `sub` drops in unchanged. Self-service UI door deferred to the authenticated contribute milestone.
  - ✅ **#4 contribution boundary** — `.github/CODEOWNERS` on the write path, service-role client, identity seam, and safety-critical SQL (needs "Require review from Code Owners" toggled on in branch protection).
  - 🟡 **#1 layered sessions** now underway — a **drop-in Keycloak contributor auth (server-side BFF)** landed on the branch. ⏳ **#5 i18n** still pending Keycloak (Phase 0/1). Also on the branch: a WNY seed-data importer (creates self-reported data only).
- ⏳ **a11y-probe is an unborn repo** (0 commits, no remote); pointer sits untracked until it's initialized.
- 🟡 **Merge the pointer PRs** — CIT #1, KindredAccess #2, Benefits Navigator #23, and Access Atlas #1 are **open** (links in §1); page-repair's is unverifiable from this account. Next action is review + merge, not opening.
- ✅ **Push governance repo** — done (`main` live).
- 🟡 **KindredAccess OIDC integration** (2026-07-08) — Django resource server done and verified end-to-end vs dev Keycloak (branch `feat/bas-keycloak-oidc`, KA PR #4). Stores a pairwise `sub` on a new `KeycloakIdentity` model; inert until configured. While verifying, **fixed the dev-realm pairwise mapper** in `identity/dev/realm/bootstrap.sh` for **both** `cit-web` and `kindredaccess-web` — the reference used `oidc-sub-mapper` (non-pairwise, sub = raw user id) instead of `oidc-sha256-pairwise-sub-mapper`. Separately, KA's WebSocket deploy config was corrected (Gunicorn+Daphne, KA PR #3). ⬜ Existing-user migration for KA still pending (below).
- 🟡 **Cross-app correlation** — adopt pairwise `sub` ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) before any app stores a shared identifier. **KA now stores a pairwise sub (verified in dev).** ⬜ enforce for `cit-web` and in prod (needs sector-identifier/salt strategy).
- 🟡 **Existing-user migration** into Keycloak ([ADR-004](docs/adr/004-existing-user-migration.md)) — CIT reference runbook, then KA + Benefits Navigator. (KA code links legacy accounts by verified email at first login.) KA's Keycloak user-migration **export command** (ADR-004) is now **merged to `main`** (KA PR #5, which also landed an automated vision first-pass for photo moderation). Import/hash side still pending.
- ⏳ **Benefits Navigator data posture** — veteran data may carry Privacy Act / VA obligations distinct from HIPAA; determine like CIT's HIPAA question.
- 🟡 **page-repair store submission prepared** — v1.0.0 release manifest, icons, [PRIVACY.md](repos/page-repair/PRIVACY.md), [STORE_LISTING.md](repos/page-repair/STORE_LISTING.md), and `dist/page-repair.zip` are ready; **not submitted** (needs a Chrome Web Store dev account + real-page screenshots). Changes are uncommitted in the working tree.
- ⏳ **page-repair proxy inert** — Cloudflare Worker is live but needs `wrangler secret put ANTHROPIC_API_KEY` (+ a redeploy of the pending health-route change) before paid labeling works.
- ⬜ **Marketing-site GitHub repo name** — governance owns `Beau-Access-Solutions`; the site needs a different repo name (e.g. `bas-website`) when pushed.
- ⬜ Decide the shared-frontend repo name (`design-system`) when Phase 0 needs shared code.

---

## 7. Decision log

- [PLATFORM.md](PLATFORM.md) — architecture anchor
- [INVARIANTS.md](INVARIANTS.md) — the five platform invariants
- [ADR-001](docs/adr/001-platform-architecture-and-identity.md) — shared platform + standalone Keycloak identity
- [ADR-002](docs/adr/002-umbrella-org-and-repo-topology.md) — BAS umbrella, repo topology, no committed cross-repo symlinks
- [ADR-003](docs/adr/003-pairwise-subject-identifiers.md) — pairwise subject identifiers (no cross-app correlation)
- [ADR-004](docs/adr/004-existing-user-migration.md) — migrating existing users into Keycloak
- CIT `docs/adr/004` — CIT-side pointer to the identity decision
- CIT `docs/mobile/PLAN.md` — native build plan; `docs/mobile/auth-token-exchange.md` — token-exchange spec
