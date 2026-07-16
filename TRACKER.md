# Platform Tracker

Living status board for the Beau Access Solutions accessibility-app platform. Update as
things move — this is the single place to see where everything stands.

**Last updated:** 2026-07-14 (reconciled against real repo state via `/platform-status`)
**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ⏳ blocked / waiting on input

---

## 1. Portfolio & platform onboarding

| App | Platform role | Stack | Remote | CLAUDE.md pointer | Onboarding |
|---|---|---|---|---|---|
| **Chronic Illness Tracker** | App #1 (PHI) | Next.js + Postgres | `Beaudoin0zach/Chronic-Illness-Tracker` (origin) · also old remote `kbeaudoin001/Chronic-Illness-Tracker` | ✅ pointer **merged to `main`** (PR #1) | 🟡 leading · AI date-range-timezone fix merged to `main` (2026-07-14) |
| **KindredAccess** | App #2 | Django + Channels | `Beaudoin0zach/kindredaccess` | ✅ pointer **merged to `main`** (PR #2) | 🟡 OIDC RP integrated ahead of seq. (PR #4) |
| **Benefits Navigator** | Candidate (sensitive) | Django + AI | `Beaudoin0zach/benefits_navigator` | ✅ pointer **merged to `main`** (PR #23, admin override past review gate) · as of 2026-07-14: 11 PRs open — #22 governance + #24 membership + design-review #27/#28, rest dependabot (#20 no longer open); PII-in-logs + Celery `acks_late` fixes merged to `main` | ⬜ |
| **Access Atlas** (access-directory) | Member (identity) | Astro | `Beaudoin0zach/access-atlas` | ✅ pointer on `main` · ✅ **invariants PR #1 merged to `main`** | 🟡 onboarded · invariants #2/#3/#4 ✅ · identity #1 🟡 (Keycloak BFF auth landed) · #5 ⏳ · evidence-photos PR #18 merged, PR #17 open |
| **a11y-probe** | Standalone / CI a11y | Reddit Devvit | `Beaudoin0zach/a11y-probe` (private) | ✅ repo initialized · `main` pushed (initial commit 2026-07-14, incl. 44px touch-target fix) · 10 dependabot PRs open | n/a |
| **page-repair** | Standalone; patterns → `ui` | Browser extension | `LangworthyWatch/page-repair` (canonical) · `Beaudoin0zach/page-repair` (origin) | ✅ branch pushed · ⏳ pointer PR status unverifiable from this account | n/a |
| **Marketing site** | Company site (not a platform app) | Astro + Netlify | local only (unpushed) | — | n/a |

**Pointer-PR rollout — DONE for all four verifiable repos; pointers are merged to `main`.**
- CIT — ✅ merged (PR #1)
- KindredAccess — ✅ merged (PR #2)
- Benefits Navigator — ✅ merged (PR #23, admin override past the Code Owner review gate)
- Access Atlas — ✅ pointer already on `main`; invariants PR #1 also merged
- page-repair — pointer PR status **unverifiable** from this GitHub account (`LangworthyWatch/page-repair` is third-party); confirm directly there.

---

## 2. Deployment & hosting

Where each app is meant to run, and whether it's actually there yet. "Artifact" =
what gets shipped; "Trigger" = how a deploy happens.

| App | Artifact | Host / platform | Config source | Trigger | URL / DNS | Status |
|---|---|---|---|---|---|---|
| **Chronic Illness Tracker** | Next.js web + managed Postgres 17 | **DigitalOcean App Platform** (region `nyc`, `basic-xxs`) | [`.do/app.yaml`](repos/chronic-illness-tracker/.do/app.yaml) — repo `Beaudoin0zach/Chronic-Illness-Tracker`, health `/api/health`, pre-deploy `prisma migrate deploy` | `deploy_on_push` on `main` | 🟢 <https://chronic-illness-tracker-7o7fw.ondigitalocean.app> | 🟢 **live** (auto-deploys `main`) · also the API backend the **Baseline** iOS app calls — see §2b |
| **Benefits Navigator** | Django + Celery + Redis | **DigitalOcean App Platform** (region NYC, App ID `2119eba2-07b6-405f-a962-d40dd6956137`) | [`DEPLOYMENT.md`](repos/benefits-navigator/DEPLOYMENT.md), `Dockerfile.prod` | git push | 🟢 <https://benefits-navigator-staging-3o4rq.ondigitalocean.app> | 🟡 **staging live** · ⬜ prod |
| **KindredAccess** | Django web backend + Capacitor mobile shell | **DigitalOcean Droplet** (Ubuntu 22.04, $12–18/mo) | [`DIGITAL_OCEAN_DEPLOYMENT.md`](repos/kindredaccess/DIGITAL_OCEAN_DEPLOYMENT.md) + `deploy/` systemd units (Gunicorn HTTP + **Daphne WebSockets**, nginx `/ws/` routing) — KA PR #3 | **manual (SSH)** — no auto-deploy | 🟢 <https://kindredaccess.org> | 🟢 **live** · the site the KindredAccess iOS wrapper loads (§2b). Manual deploy: `main` edits only reach the site + app after an SSH redeploy |
| **Access Atlas** (access-directory) | Astro SSR (zero-JS surface) + Supabase | **DigitalOcean App Platform** (Dockerfile from GitHub) | [`.do/app.yaml`](repos/access-directory/.do/app.yaml) — repo `Beaudoin0zach/access-atlas`, `deploy_on_push: true` on `main` | `deploy_on_push` on `main` | 🟢 <https://access-atlas-qd464.ondigitalocean.app> | 🟢 **live** (deployed 2026-07-10, auto-deploys `main`) · the site the Access Atlas iOS wrapper loads (§2b) |
| **a11y-probe** | Reddit Devvit app (client + server bundle) | **Reddit Devvit** platform | [`devvit.json`](repos/a11y-probe/devvit.json) | `devvit upload` / `publish` | Reddit-hosted | 🟡 **repo initialized** (`Beaudoin0zach/a11y-probe`, private) · ⬜ not published to Devvit |
| **page-repair** (extension) | Browser extension (MV3) | **Chrome Web Store / AMO** | [`manifest.json`](repos/page-repair/manifest.json) v1.0.0 + icons · [`PRIVACY.md`](repos/page-repair/PRIVACY.md) · [`STORE_LISTING.md`](repos/page-repair/STORE_LISTING.md) · `dist/page-repair.zip` | store submission | store listing | 🟡 **submission-ready** · ⬜ not submitted (needs dev account + screenshots) |
| **page-repair** (credit proxy) | Cloudflare Worker + KV + **Durable Object** (credits) | **Cloudflare Workers** | [`proxy/wrangler.jsonc`](repos/page-repair/proxy/wrangler.jsonc) | `wrangler deploy` (manual) | 🟢 <https://page-repair-proxy.airboat-webcast-5u.workers.dev> | 🟡 **live but inert** — `ANTHROPIC_API_KEY` secret unset. Atomic-credit `CreditsAccount` DO merged to `main` (2026-07-14). ✅ **Concurrency gate cleared** — `wrangler dev` test (50 parallel requests on 1 credit → exactly **1** got past the spend, 49× `402`; balance correct) proves the DO closes the overspend race; `wrangler types` regenerated. Remaining to activate paid labeling: `wrangler secret put ANTHROPIC_API_KEY` + `wrangler deploy` |
| **Marketing site** | Astro static | **Netlify** | [`netlify.toml`](repos/marketing-site/netlify.toml) — build `dist`, SPA redirect, security headers | Netlify git deploy | ⬜ | ⬜ **local only, unpushed** |
| **Keycloak** (identity infra) | Self-hosted Keycloak + own DB | **DigitalOcean** (Droplet) | [docs/deploy/keycloak-digitalocean.md](docs/deploy/keycloak-digitalocean.md) | manual | 🟢 <https://id.kindredaccess.org/realms/bas> | 🟢 **prod live** — `bas` realm reachable; issuer used by the Baseline iOS app (`eas.json`) and OIDC clients |

**What this shows:**

- **DigitalOcean is the platform default** — CIT, Benefits Navigator, KindredAccess, Access Atlas, and Keycloak all run on DO (App Platform for CIT/BN/Access Atlas, Droplets for KA + Keycloak).
- **What's actually live today (verified 2026-07-14 via HTTP probes):** CIT web (`chronic-illness-tracker-7o7fw`), Access Atlas (`access-atlas-qd464`), KindredAccess (`kindredaccess.org`), Benefits Navigator **staging**, Keycloak **prod** (`id.kindredaccess.org`), and the page-repair credit proxy (inert until its API key is set). This is a big correction from prior versions of this doc, which listed most of these as "not deployed."
- **Auto-deploy vs manual:** CIT, Access Atlas, and Benefits Navigator deploy on push to `main`; **KindredAccess and Keycloak are manual** (SSH to the Droplet) — KA edits on `main` don't reach the site (or the iOS wrapper) until someone redeploys.
- **Production DNS is partially wired:** `kindredaccess.org` and `id.kindredaccess.org` are live; CIT/Access Atlas still use DO-generated hostnames (no custom domain yet).
- **Still open:** the marketing site (needs a repo, then a Netlify connect); a11y-probe (Devvit publish); page-repair (store submission + proxy key).
- **Non-server distribution:** a11y-probe → Reddit Devvit, page-repair → browser-extension stores, and the three **iOS apps → TestFlight** (§2b) — none are hosts we operate.

---

## 2b. iOS / TestFlight

All three consumer apps are **on TestFlight today** — this is NOT the unstarted Phase 3/4 work the roadmap once implied. Full architecture + update runbook: [docs/mobile-and-testflight.md](docs/mobile-and-testflight.md).

| App (TestFlight name) | Build type | Source repo (⚠ remote?) | Loads / contains | How an edit reaches testers |
|---|---|---|---|---|
| **Access Atlas** | Capacitor / WKWebView **wrapper** | `access-directory` (`capacitor.config.ts`) | the **live DO site** at runtime | redeploy the web app (auto on `main`) → relaunch app. **No new build** unless the native shell changes |
| **KindredAccess** | Capacitor / WKWebView **wrapper** | **`kindredaccess-ios`** — ✅ pushed `Beaudoin0zach/kindredaccess-ios` (private) | **`kindredaccess.org`** at runtime | **SSH-redeploy** the site (manual) → relaunch app. No new build for content |
| **Baseline** = CIT | **native Expo / React Native** (EAS) | **`bas-apps/apps/cit`** — ✅ pushed `Beaudoin0zach/bas-apps` (private; monorepo also holds shared `ui`/`auth`/`tokens`/`i18n` packages) | native RN screens; calls the CIT API backend | **`eas update`** (OTA, JS-only, no rebuild) or **`eas build` + `eas submit`** (native changes). EAS Update channels configured |

**Key facts:**
- **Two of three are thin webview wrappers** — their "app" is really the hosted website. Edits ship by **web deploy**, not a TestFlight rebuild. Only native-shell changes (icon, splash, `server.url`, plugins, version bump) need a new build.
- **Baseline (CIT) is the exception** — a genuine native app. Its own code edits need `eas update` (OTA) or a full `eas build` + submit. A server-side backend fix (like the AI date-range fix, 2026-07-14) reaches it only through the API, and only for features the native app actually has (it has **no AI-insights screen yet**).
- **Mobile source backup — complete:** `bas-apps` (Baseline + shared packages), `kindredaccess-ios`, `bas-frontend`, and `access-atlas-mobile` are all now pushed to private `Beaudoin0zach/*` repos. See §6.
- **External-review blocker (Access Atlas):** a bare webview wrapper is rejected under App Store Guideline 4.2; internal TestFlight (≤100) is fine. Clearing external review needs the camera evidence-photo feature (`access-directory` runbook).

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
- **Phase 3 — Rebuild CIT in Expo** 🟡 **underway** (native app `bas-apps/apps/cit`, ships as **Baseline**; ⚠ repo has no remote — §6)
  - 🟡 Rebuild 7 screens + 3 auth flows in RN — app builds, OIDC hosted-login against prod Keycloak, sign-in hardening landed (watchdog, idToken re-prompt). Not all CIT web features ported (e.g. **no AI-insights screen yet**)
  - ⬜ Re-run a11y gates to parity (VoiceOver + TalkBack)
  - ⬜ i18n reusing CIT `locales/*.json`
  - ⬜ In-app account deletion (Apple 5.1.1(v))
- **Phase 4 — Ship to testers** 🟡 **on TestFlight now** (§2b) — the reality this roadmap once marked "not started"
  - 🟢 EAS Build → **TestFlight** — Baseline (CIT native) + the Access Atlas / KindredAccess webview wrappers are all on TestFlight; EAS Update (OTA) channels configured. ⬜ Play internal · ⬜ web
  - ⬜ Privacy nutrition labels / data-safety form
  - ⬜ Human-reviewed store copy (incl. Spanish)
  - ⬜ External TestFlight for Access Atlas blocked on Guideline 4.2 (needs camera evidence feature)
- **Phase 5 — Generalize** ⬜
  - 🟡 **KindredAccess OIDC RP done ahead of sequence** (2026-07-08) — Django resource server integrated with `mozilla-django-oidc` (confidential client + PKCE S256), verified end-to-end against the local dev Keycloak incl. a genuinely pairwise `sub`. Layered session (validate vs JWKS → mint Django session), verified-email linking (ADR-004), `azp` sibling-app rejection. Inert until `KEYCLOAK_ISSUER`/`OIDC_RP_CLIENT_ID` set. Branch `feat/bas-keycloak-oidc` (KA PR #4), 346 tests green. Existing-user migration + prod still pending — see §6.
  - ⬜ KindredAccess consumes shared packages (`ui`/`auth`)
  - ⬜ "Add a new app" playbook

---

## 4. Identity service (Keycloak) — [ADR-001](docs/adr/001-platform-architecture-and-identity.md)

Setup & hardening steps live in **[docs/keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md)** (drafted, not yet executed).

- ✅ Decision: standalone, self-hosted Keycloak
- ✅ Stand-up + hardening checklist drafted ([keycloak-setup-and-hardening.md](docs/keycloak-setup-and-hardening.md))
- 🟢 **Instance stood up in PROD** — `https://id.kindredaccess.org/realms/bas` is live (verified 2026-07-14) and is the OIDC issuer the Baseline iOS app (`bas-apps/apps/cit/eas.json`) and web clients point at. (Supersedes the old "prod not stood up / DNS TBD".)
- ⬜ Hardening executed (admin-console lockdown, patching cadence) — confirm against the checklist now that it's live
- 🟡 Login theme re-themed to pass WCAG 2.2 AA — theme authored on `feat/identity-a11y-login-theme` (unmerged); confirm it's the one serving on prod
- 🟡 OIDC clients per app + `aud`/`azp` isolation — `cit-web` + `kindredaccess-web` in the `bas` realm; KA rejects a sibling `azp`. Now exercised against **prod** (`id.kindredaccess.org`) by the live apps
- 🟡 Pairwise subject identifiers per client ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) — **dev:** working for `kindredaccess-web` (`oidc-sha256-pairwise-sub-mapper`, salted; sub ≠ raw user id, verified). Reference bootstrap corrected for both clients (was a no-op `oidc-sub-mapper`). ⬜ prod sector-identifier/salt strategy
- ⬜ 2FA + step-up (ACR/LoA) policy
- ⬜ DR: Keycloak DB backup/restore + token signing-key rotation + availability target
- ⬜ Existing-user migration runbook — CIT first ([ADR-004](docs/adr/004-existing-user-migration.md))

---

## 5. App Store / Play prerequisites (CIT first)

> **Note:** all three apps are already on **TestFlight** (§2b), so the Apple side is further along than this list implied. CIT ships under the name **Baseline**.

- 🟢 Apple Developer Program — **enrolled** (required for the TestFlight builds now live); `ascAppId` wired into `bas-apps/apps/cit` submit profile
- ⬜ Google Play Developer — **$25 one-time** (no Android build yet)
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
  - ✅ **Signup account-enumeration closed** — email-verification signup via Postmark (**CIT PR #2 merged to `main`**). Replaces the `409 email_taken` oracle with a uniform `202`; login now blocked until verified. ⚠ **Deploy gate:** the live app needs `EMAIL_PROVIDER=postmark` + `POSTMARK_API_TOKEN` + `EMAIL_FROM` set or **no one can sign in** (main has `deploy_on_push`). CI didn't gate this specific merge, but **CIT CI is now working and green on `main`** — the repo's Actions had never once run since the `Beaudoin0zach` migration; triggering them surfaced (and PR #7 fixed) a lint failure + a `jest` config that couldn't load on CI's Node 20. `main` now passes Lint/Test/Build.
- ✅ **access-directory (Access Atlas) now has a remote** — `Beaudoin0zach/access-atlas` (public), onboarded on `main` with a governance pointer + inlined invariants (`docs/platform-membership.md`). Scoped as a full identity member: browsing stays account-free; identity gates contribution only; browsing surface stays Astro/zero-JS (no RN rewrite).
- ✅ **Access Atlas app-side invariants — 3 of 5 merged to `main`** (PR #1, `platform-seed-and-data-rights`; also landed the WNY seed pipeline + drop-in Keycloak BFF contributor auth):
  - ✅ **#2 tracking/CSP** — own CSP + security headers (one policy, applied as `<meta>` for static pages + HTTP headers for SSR); `script-src 'none'` makes its zero-JS surface self-enforcing.
  - ✅ **#3 decoupled delete/export** — complete, independently-callable workflow (`src/lib/data-rights.ts` + ops CLI, storage-aware, idempotent, unit-tested), keyed by contributor id so the Keycloak `sub` drops in unchanged. Self-service UI door deferred to the authenticated contribute milestone.
  - ✅ **#4 contribution boundary** — `.github/CODEOWNERS` on the write path, service-role client, identity seam, and safety-critical SQL (needs "Require review from Code Owners" toggled on in branch protection).
  - 🟡 **#1 layered sessions** now underway — a **drop-in Keycloak contributor auth (server-side BFF)** landed on the branch. ⏳ **#5 i18n** still pending Keycloak (Phase 0/1). Also on the branch: a WNY seed-data importer (creates self-reported data only).
- ✅ **Mobile app source backup — COMPLETE (2026-07-14).** All four mobile repos pushed to private `Beaudoin0zach/*` repos: **`bas-apps`** (the **Baseline**/CIT native Expo app + shared `ui`/`auth`/`tokens`/`i18n`/`api` packages), **`kindredaccess-ios`** (KA wrapper, incl. its App Store screenshots), **`bas-frontend`**, and **`access-atlas-mobile`** (its uncommitted EAS/App.js work was committed first as a backup snapshot). The Access Atlas + KindredAccess *web* wrapper configs already live inside their pushed web repos.**Decision (2026-07-14, reviewed + EXECUTED): retired `access-atlas-mobile`** (redundant Expo webview wrapper) — GitHub repo **archived** (read-only, still backed up). Canonical Access Atlas iOS build stays the `access-directory` Capacitor wrapper (Capacitor = platform wrapper toolchain; Expo = the native CIT app). ✅ **Salvaged its one good idea:** the Expo `App.js` kept the Keycloak IdP host in-app; the Capacitor config had **no `allowNavigation`**, so its default would bounce OIDC login to Safari and break the round-trip. Fix (`allowNavigation: ['id.kindredaccess.org']`; everything else opens in Safari) **merged to `access-directory` `main`** (2026-07-14) and the local Expo dir **deleted** (remote archived + backed up). ✅ **New TestFlight build uploaded** (2026-07-14, build 2 via `cap sync ios` → Xcode archive) carrying the fix. ⬜ Final check: once it finishes processing, install build 2 and confirm login opens the Keycloak screen **in-app** (not Safari) and returns logged in.
- ✅ **a11y-probe repo initialized** — `Beaudoin0zach/a11y-probe` (private), `main` pushed (initial commit 2026-07-14). ⬜ still not published to Devvit.
- ✅ **Pointer PRs merged** — CIT #1, KindredAccess #2, Benefits Navigator #23, and Access Atlas #1 are all **merged to `main`**; page-repair's remains unverifiable from this account (third-party `LangworthyWatch` repo).
- ✅ **Push governance repo** — done (`main` live).
- 🟡 **KindredAccess OIDC integration** (2026-07-08) — Django resource server done and verified end-to-end vs dev Keycloak (branch `feat/bas-keycloak-oidc`, KA PR #4). Stores a pairwise `sub` on a new `KeycloakIdentity` model; inert until configured. While verifying, **fixed the dev-realm pairwise mapper** in `identity/dev/realm/bootstrap.sh` for **both** `cit-web` and `kindredaccess-web` — the reference used `oidc-sub-mapper` (non-pairwise, sub = raw user id) instead of `oidc-sha256-pairwise-sub-mapper`. Separately, KA's WebSocket deploy config was corrected (Gunicorn+Daphne, KA PR #3). ⬜ Existing-user migration for KA still pending (below).
- 🟡 **Cross-app correlation** — adopt pairwise `sub` ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) before any app stores a shared identifier. **KA now stores a pairwise sub (verified in dev).** ⬜ enforce for `cit-web` and in prod (needs sector-identifier/salt strategy).
- 🟡 **Existing-user migration** into Keycloak ([ADR-004](docs/adr/004-existing-user-migration.md)) — CIT reference runbook, then KA + Benefits Navigator. (KA code links legacy accounts by verified email at first login.) KA's Keycloak user-migration **export command** (ADR-004) is now **merged to `main`** (KA PR #5, which also landed an automated vision first-pass for photo moderation). **Hardened via adversarially-verified review (KA PR #6, merged 2026-07-09):** removed the superuser `emailVerified:true` carve-out (unverified admin emails were an IdP-password-reset takeover vector for the highest-privilege accounts — unverified admins now take the one-time reset path), plus moderation-pipeline fixes. The **firstName/lastName-optional user profile** KA migration needs is already covered: `main`'s bootstrap (platform PR #4, validated on KC 26) relaxes the declarative profile — Keycloak 24+ otherwise flags KA's single-display_name migrated accounts "not fully set up" and blocks login. Remaining: partialImport dry-run + one migrated-login round-trip on the rebuilt realm, then the prod runbook.
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
