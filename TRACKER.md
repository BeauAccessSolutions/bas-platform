# Platform Tracker

Living status board for the Beau Access Solutions accessibility-app platform. Update as
things move — this is the single place to see where everything stands.

**Last updated:** 2026-07-18 (§4.1 gate audit — C1/C3/C4 citations corrected against the real tests; page-repair gains the C3 no-double-read gate; CIT native found announcing status to neither screen reader, fix + first-ever tests/CI for `bas-apps` open as PR #1)
**Legend:** ✅ done · 🟡 in progress · ⬜ not started · ⏳ blocked / waiting on input

---

## 1. Portfolio & platform onboarding

| App | Platform role | Stack | Remote | CLAUDE.md pointer | Onboarding |
|---|---|---|---|---|---|
| **Chronic Illness Tracker** | App #1 (PHI) | Next.js + Postgres | `Beaudoin0zach/Chronic-Illness-Tracker` (origin) · also old remote `kbeaudoin001/Chronic-Illness-Tracker` | ✅ pointer **merged to `main`** (PR #1) | 🟡 leading · AI date-range-timezone fix merged to `main` (2026-07-14) |
| **KindredAccess** | App #2 | Django + Channels | `Beaudoin0zach/kindredaccess` | ✅ pointer **merged to `main`** (PR #2) | 🟡 OIDC RP integrated ahead of seq. (PR #4) |
| **Benefits Navigator** | Candidate (sensitive) → Member pending [ADR-005](docs/adr/005-benefits-navigator-data-posture.md) | Django + AI | `Beaudoin0zach/benefits_navigator` | ✅ pointer **merged to `main`** (PR #23, admin override past review gate) · as of 2026-07-14: 11 PRs open — #22 governance + #24 membership + design-review #27/#28, rest dependabot (#20 no longer open); PII-in-logs + Celery `acks_late` fixes merged to `main` | ⬜ |
| **Access Atlas** (access-directory) | Member (identity) | Astro | `Beaudoin0zach/access-atlas` | ✅ pointer on `main` · ✅ **invariants PR #1 merged to `main`** | 🟡 onboarded · invariants #2/#3/#4 ✅ · identity #1 🟡 (Keycloak BFF auth landed) · #5 ⏳ · evidence-photos PR #18 merged, PR #17 open |
| **Disability Wiki** | Member (identity) — Access-Atlas-shaped sibling | Astro Starlight (post-Wiki.js) + Cloudflare Pages | `Beaudoin0zach/disability-wiki` (public) | ✅ `docs/platform-membership.md` (governance pointer + invariants fallback; URL repointed to `bas-platform` 2026-07-16) | 🟡 onboarded (self-declared 2026-07-14, now reflected here) · Keycloak BFF auth + Supabase moderation store code-complete on branch (Phases 1–3), fail-closed · ⏳ live wiring needs a Supabase project + registered Keycloak client + data-controller sign-off. **Read path is DB-free static** — Supabase is write-only staging, never a read dependency (crisis pages must load offline) |
| **a11y-probe** | Standalone / CI a11y | Reddit Devvit | `Beaudoin0zach/a11y-probe` (private) | ✅ repo initialized · `main` pushed (initial commit 2026-07-14, incl. 44px touch-target fix); design-review AA fixes on `main` (2026-07-16) · **0 open PRs** (the 10 dependabot PRs are closed/merged) | n/a |
| **page-repair** | Standalone; patterns → `ui` | Browser extension | `LangworthyWatch/page-repair` (canonical) · `Beaudoin0zach/page-repair` (origin) | ✅ branch pushed · ⏳ pointer PR status unverifiable from this account | n/a |
| **Marketing site** | Company site (not a platform app) | Astro + Netlify | `Beaudoin0zach/bas-website` (private) | — | 🟢 **LIVE** <https://beauaccesssolutions.com> · remade around the app portfolio (consulting kept) · **links the live apps + contrast/token CI gate** (2026-07-18) |

**Pointer-PR rollout — DONE for all four verifiable repos; pointers are merged to `main`.**
- CIT — ✅ merged (PR #1)
- KindredAccess — ✅ merged (PR #2)
- Benefits Navigator — ✅ merged (PR #23, admin override past the Code Owner review gate)
- Access Atlas — ✅ pointer already on `main`; invariants PR #1 also merged
- page-repair — pointer PR status **unverifiable** from this GitHub account (`LangworthyWatch/page-repair` is third-party); confirm directly there.

---

## 1b. Repo & disk map

The full inventory of every BAS repo → GitHub remote + local checkout path(s), plus the
duplicate-clone and folder-name-vs-repo-name hazards that caused the earlier wrong-repo
Netlify incident, lives in the **private** `bas-internal` repo
(`infra/repo-and-disk-map.md`) — it enumerates private repo names, disk paths, and
unrelated personal projects, so it stays out of this public hub.

One hazard worth stating here: **Disability Wiki has no clone under `repos/`**, so
`/platform-status` can't git/HTTP-probe it like the other apps — add one (or a symlink) to
bring it under the status tooling.

A second, subtler hazard: **`platform-status.sh` reports `open PRs: 0` when `gh` is signed
in as the wrong account** — it does not distinguish "no PRs" from "cannot see this repo."
Observed 2026-07-18: `gh` had flipped to `LangworthyWatch`, and the script reported CIT as
having 0 open PRs while [#41](https://github.com/Beaudoin0zach/Chronic-Illness-Tracker/pull/41)
was open (a direct `gh pr list` errored with "Could not resolve to a Repository"). The
account flips back on its own, so this is not a one-off. Run `gh auth switch --user
Beaudoin0zach` before trusting a PR count, and treat a `0` as unverified until then —
**the script currently fails open on this, which is the exact failure mode the board exists
to prevent.**

---

## 2. Deployment & hosting

Where each app is meant to run, and whether it's actually there yet. "Artifact" =
what gets shipped; "Trigger" = how a deploy happens.

| App | Artifact | Host / platform | Config source | Trigger | URL / DNS | Status |
|---|---|---|---|---|---|---|
| **Chronic Illness Tracker** | Next.js web + managed Postgres 17 | **DigitalOcean App Platform** (region `nyc`, `basic-xxs`) | [`.do/app.yaml`](repos/chronic-illness-tracker/.do/app.yaml) — repo `Beaudoin0zach/Chronic-Illness-Tracker`, health `/api/health`, pre-deploy `prisma migrate deploy` | `deploy_on_push` on `main` | 🟢 <https://chronic-illness-tracker-7o7fw.ondigitalocean.app> | 🟢 **live** (auto-deploys `main`) · also the API backend the **Baseline** iOS app calls — see §2b |
| **Benefits Navigator** | Django + Celery + Redis | **DigitalOcean App Platform** (region NYC, App ID `2119eba2-07b6-405f-a962-d40dd6956137`) | [`DEPLOYMENT.md`](repos/benefits-navigator/DEPLOYMENT.md), `Dockerfile.prod` · **`PRE_DEPLOY` job seeds reference content** (see §2c) | git push | 🟢 <https://vabenefitsnavigator.org> (PRIMARY; `www` alias **301s to apex** — see [canonical-host-redirects](docs/deploy/canonical-host-redirects.md)) · <https://benefits-navigator-staging-3o4rq.ondigitalocean.app> (DO default) | 🟡 **staging live** · ⬜ prod · ⚠️ despite the app name, this app **serves the real domain** — verify OIDC on `vabenefitsnavigator.org`, never the `ondigitalocean.app` URL (the Keycloak client registers only the prod callback, so login *cannot* complete there) |
| **KindredAccess** | Django web backend + Capacitor mobile shell | **DigitalOcean Droplet** (Ubuntu 22.04, $12–18/mo) | [`DIGITAL_OCEAN_DEPLOYMENT.md`](repos/kindredaccess/DIGITAL_OCEAN_DEPLOYMENT.md) + `deploy/` systemd units (Gunicorn HTTP + **Daphne WebSockets**, nginx `/ws/` routing) — KA PR #3 | **manual (SSH)** — no auto-deploy | 🟢 <https://kindredaccess.org> | 🟢 **live** · the site the KindredAccess iOS wrapper loads (§2b). Manual deploy: `main` edits only reach the site + app after an SSH redeploy. `www` **301s to apex** (nginx, 2026-07-18 — see [canonical-host-redirects](docs/deploy/canonical-host-redirects.md)) |
| **Access Atlas** (access-directory) | Astro SSR (zero-JS surface) + Supabase | **DigitalOcean App Platform** (Dockerfile from GitHub) | [`.do/app.yaml`](repos/access-directory/.do/app.yaml) — repo `Beaudoin0zach/access-atlas`, `deploy_on_push: true` on `main` | `deploy_on_push` on `main` | 🟢 <https://access-atlas-qd464.ondigitalocean.app> | 🟢 **live** (deployed 2026-07-10, auto-deploys `main`) · the site the Access Atlas iOS wrapper loads (§2b) |
| **Disability Wiki** | Static Astro Starlight bundle (~540 pages); contribution write path = **Cloudflare Pages Function** + Supabase moderation queue | **Cloudflare Pages** | `site/` in `Beaudoin0zach/disability-wiki` (`astro.config.mjs`, `wrangler.jsonc`) | `deploy_on_push` on `main` → Pages build | 🟢 <https://disabilitywiki.org> | 🟢 **live** (HTTP 200, 2026-07-16). Static read path has **no DB dependency**; the contribution backend (Keycloak BFF + Supabase) is code-complete but **inert** until a Supabase project + a registered Keycloak client + data-controller sign-off land |
| **a11y-probe** | Reddit Devvit app (client + server bundle) | **Reddit Devvit** platform | [`devvit.json`](repos/a11y-probe/devvit.json) | `devvit upload` / `publish` | Reddit-hosted | 🟡 **repo initialized** (`Beaudoin0zach/a11y-probe`, private) · ⬜ not published to Devvit |
| **page-repair** (extension) | Browser extension (MV3) | **Chrome Web Store / AMO** | [`manifest.json`](repos/page-repair/manifest.json) v1.0.0 + icons · [`PRIVACY.md`](repos/page-repair/PRIVACY.md) · [`STORE_LISTING.md`](repos/page-repair/STORE_LISTING.md) · `dist/page-repair.zip` | store submission | store listing | 🟡 **submission-ready** · ⬜ not submitted (needs dev account + screenshots) |
| **page-repair** (credit proxy) | Cloudflare Worker + KV + **Durable Object** (credits) | **Cloudflare Workers** | [`proxy/wrangler.jsonc`](repos/page-repair/proxy/wrangler.jsonc) | `wrangler deploy` (manual) | 🟢 <https://page-repair-proxy.airboat-webcast-5u.workers.dev> | 🟡 **live but inert** — `ANTHROPIC_API_KEY` secret unset. Atomic-credit `CreditsAccount` DO merged to `main` (2026-07-14). ✅ **Concurrency gate cleared** — `wrangler dev` test (50 parallel requests on 1 credit → exactly **1** got past the spend, 49× `402`; balance correct) proves the DO closes the overspend race; `wrangler types` regenerated. Remaining to activate paid labeling: `wrangler secret put ANTHROPIC_API_KEY` + `wrangler deploy` |
| **Marketing site** | Astro static | **Netlify** | [`netlify.toml`](repos/marketing-site/netlify.toml) — build `npm run build` → `dist`, security headers (SPA catch-all removed; real 404 page added) | **continuous** (push to `bas-website` → auto-build) | 🟢 <https://beauaccesssolutions.com> | 🟢 **LIVE** (deployed 2026-07-16, remade around the app portfolio) · repo `Beaudoin0zach/bas-website` (private). Netlify site `620702da` under **beaudoin0zach@gmail.com** ("Baby Booty" team), ✅ **continuous deploy wired to `bas-website`/`main` and verified** (a push auto-built + published). ⚠ NOT `Beau-Access-Solutions` — see §6 |
| **Keycloak** (identity infra) | Self-hosted Keycloak + own DB | **DigitalOcean** (Droplet) | [docs/deploy/keycloak-digitalocean.md](docs/deploy/keycloak-digitalocean.md) | manual (SSH; Docker Compose in `/opt/keycloak`, droplet `bas-keycloak` 138.197.125.90) | 🟢 <https://id.beauaccesssolutions.com/realms/bas> (canonical) · 🟡 <https://id.kindredaccess.org/realms/bas> (dual-served, to retire) | 🟢 **prod live** — `bas` realm reachable on both hosts (verified 2026-07-18). **Canonical issuer migrated to `id.beauaccesssolutions.com` (2026-07-16/17)**; the old host stays dual-served until the three native builds carrying it are rebuilt (CIT Baseline `eas.json`, Access Atlas + KindredAccess Capacitor), then retires via a 301. ⚠️ **Droplet, not App Platform** — no `doctl apps` surface and no bindable DB refs; its `/opt/keycloak/.env` (dedicated `keycloak` DB user, private-VPC host) must be hand-updated on credential rotation |

**What this shows:**

- **DigitalOcean is the platform default** — CIT, Benefits Navigator, KindredAccess, Access Atlas, and Keycloak all run on DO (App Platform for CIT/BN/Access Atlas, Droplets for KA + Keycloak).
- **What's actually live today (verified 2026-07-16 via HTTP probes; identity re-verified 2026-07-18):** CIT web (`chronic-illness-tracker-7o7fw`), Access Atlas (`access-atlas-qd464`), **Disability Wiki (`disabilitywiki.org`)**, KindredAccess (`kindredaccess.org`), Benefits Navigator (`vabenefitsnavigator.org` — served by the DO app confusingly *named* `benefits-navigator-staging`; there is no separate prod app), marketing site (`beauaccesssolutions.com`), Keycloak **prod** (`id.beauaccesssolutions.com` canonical; `id.kindredaccess.org` still dual-served), and the page-repair credit proxy (inert until its API key is set). This is a big correction from prior versions of this doc, which listed most of these as "not deployed."
- **Auto-deploy vs manual:** CIT, Access Atlas, and Benefits Navigator deploy on push to `main`; **KindredAccess and Keycloak are manual** (SSH to the Droplet) — KA edits on `main` don't reach the site (or the iOS wrapper) until someone redeploys.
- **Production DNS is partially wired:** `kindredaccess.org`, `vabenefitsnavigator.org`, `disabilitywiki.org`, and `id.beauaccesssolutions.com` are live (the last is a grey-cloud/DNS-only Cloudflare A record — Caddy provisions its own cert, so proxying would break ACME); legacy `id.kindredaccess.org` still resolves during the native-build transition. CIT/Access Atlas still use DO-generated hostnames (no custom domain yet). **Both custom-domain apps now serve one canonical host** — `www` 301s to the apex on BN (App Platform ingress rule) and KA (nginx server block) as of 2026-07-18; before that both served `www` directly, splitting host-scoped sessions.
- **Still open:** the marketing site (needs a repo, then a Netlify connect); a11y-probe (Devvit publish); page-repair (store submission + proxy key).
- **Non-server distribution:** a11y-probe → Reddit Devvit, page-repair → browser-extension stores, and the three **iOS apps → TestFlight** (§2b) — none are hosts we operate.

---

## 2b. iOS / TestFlight

**All FIVE apps are on TestFlight as of 2026-07-18** — the 2026-07-18 upload round shipped issuer-migration rebuilds of the original three (all now authenticate natively against `id.beauaccesssolutions.com`, unblocking the old-host 301 retirement in §2) plus **first builds of Benefits Navigator and Disability Wiki**. Full architecture + the proven device-free archive→upload runbook: [docs/mobile-and-testflight.md](docs/mobile-and-testflight.md).

**Same-day follow-ups (2026-07-18 PM):**
- **DW 1.0 (2)** — fixed "every link goes home": Capacitor's default router is SPA-only; `WikiRouter` (DW PR #46, merged) resolves directory indexes and 404s honestly. Shared lesson captured.
- **TestFlight distribution now API-automated** — `scripts/asc-api.py` (ASC key `3SAY53224G`, App Manager). Root cause of "builds ready but never on the phone": **new app records had no beta groups**; created Internal groups (all-builds) + enrolled the aol tester for BN/DW via API, and swept export-compliance flags on every build (`usesNonExemptEncryption=false` via PATCH — no more per-build clicking). AA build 3 had been silently withheld on that flag.
- **BN 1.0 (2)** wraps `vabenefitsnavigator.org` (PR #33 merged); build (1) wrapped the DO URL where login can't complete — expired/do-not-distribute.
- **Icon family v4 approved** — masters in [design/app-icons/](design/app-icons/); not yet wired into asset catalogs (needs a build round).

| App (TestFlight name) | Build type | Source repo (⚠ remote?) | Loads / contains | How an edit reaches testers |
|---|---|---|---|---|
| **Access Atlas** — 1.0.0 (3) | Capacitor / WKWebView **wrapper** | `access-directory` (`capacitor.config.ts`) | the **live DO site** at runtime | redeploy the web app (auto on `main`) → relaunch app. **No new build** unless the native shell changes |
| **KindredAccess** — 1.0 (2) | Capacitor / WKWebView **wrapper** | **`kindredaccess-ios`** — ✅ pushed `Beaudoin0zach/kindredaccess-ios` (private) | **`kindredaccess.org`** at runtime | **SSH-redeploy** the site (manual) → relaunch app. No new build for content |
| **Baseline** = CIT — 1.0.0 (7) | **native Expo / React Native** (EAS) | **`bas-apps/apps/cit`** — ✅ pushed `Beaudoin0zach/bas-apps` (private; monorepo also holds shared `ui`/`auth`/`tokens`/`i18n` packages) | native RN screens; calls the CIT API backend | **`eas update`** (OTA, JS-only, no rebuild) or **`eas build` + `eas submit`** (native changes). EAS Update channels configured |
| **Benefits Navigator** — 1.0 (2) | Capacitor 8 / WKWebView **wrapper** | `benefits-navigator` `mobile/` (BN PR #30) | **`vabenefitsnavigator.org`** at runtime | redeploy the web app → relaunch app. ⚠️ build 1.0 (1) wrapped the `ondigitalocean.app` URL where the Keycloak callback isn't registered (login dead-ends) — superseded same-day by 1.0 (2); don't distribute (1) |
| **Disability Wiki** — 1.0 (1) | Capacitor 6 **bundled-static** (offline-first — NOT a URL wrapper) | `disability-wiki` `app/` (DW PR #43) | bundles `site/dist` (~102 MB) into the binary | **new build required** for content — the opposite tradeoff from the wrappers, deliberate (crisis pages must load offline). Known gap: in-app `/contribute` form has no backend in the bundle |

**Key facts:**
- **Two of three are thin webview wrappers** — their "app" is really the hosted website. Edits ship by **web deploy**, not a TestFlight rebuild. Only native-shell changes (icon, splash, `server.url`, plugins, version bump) need a new build.
- **Baseline (CIT) is the exception** — a genuine native app. Its own code edits need `eas update` (OTA) or a full `eas build` + submit. A server-side backend fix (like the AI date-range fix, 2026-07-14) reaches it only through the API, and only for features the native app actually has (it has **no AI-insights screen yet**).
- **Mobile source backup — complete:** `bas-apps` (Baseline + shared packages), `kindredaccess-ios`, `bas-frontend`, and `access-atlas-mobile` are all now pushed to private `Beaudoin0zach/*` repos. See §6.
- **External-review blocker (Access Atlas):** a bare webview wrapper is rejected under App Store Guideline 4.2; internal TestFlight (≤100) is fine. Clearing external review needs the camera evidence-photo feature (`access-directory` runbook).

---

## 2c. Seeded reference content (BN)

**Every content-backed page in Benefits Navigator was empty in production until 2026-07-18** — ~197
authored fixture records had never been loaded. Two independent causes: nothing invoked a loader at
deploy time (the `PRE_DEPLOY` job ran only `migrate`), and `glossary_terms_expanded.json` was
**orphaned** — no code path referenced it, so even a successful import would have loaded 50 of 90
glossary terms.

| Surface | Before | Now |
|---|---|---|
| `/exam-prep/glossary/` | 0 | 🟢 **89 terms** (90 records, one cross-file duplicate merged on the `term` upsert key) |
| `/exam-prep/` | 0 | 🟢 **7 guides** |
| `/docs/forms/` · `/docs/legal/` · `/docs/exam-guides/` | 0 | ⬜ **61 records prepared, not yet applied** |
| supportive messages | 0 | ⬜ 36 records, same pending spec change |

**How it ships:** the DO `PRE_DEPLOY` job. Fixtures are *not* all Django fixtures — `examprep`'s are
plain field dicts that `loaddata` would reject, so they go through `manage.py import_content
--fixtures` (idempotent `update_or_create`, no `--clear`). The `documentation`/`core` ones are real
Django fixtures and use `loaddata`.

⚠️ **The job's failure semantics were a landmine.** The command ended in `; exit 0`, so a failed
migration reported success and the deploy proceeded against an un-migrated database. The pending
spec change fixes this: `migrate … || exit 1` (blocks the deploy) while content seeding warns
without blocking. Shell logic verified across all four failure paths before shipping.

⚠️ **`loaddata` overwrites by pk on every deploy** — correct for reference content, but admin edits
to those records would be reverted. If that's unwanted, they belong in a one-time data migration.

⚠️ **`document_categories.json` is the canonical category taxonomy.** `va_forms.json` used to
redefine pks 1–3 with different names, so load order silently picked a winner; the duplicates were
removed (BN PR #38). Established by evidence: `va_forms_additional.json` references pks 4/5/6 which
exist only in the dedicated file.

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
- **Phase 3 — Rebuild CIT in Expo** 🟡 **underway** (native app `bas-apps/apps/cit`, ships as **Baseline**; remote **is** `Beaudoin0zach/bas-apps` — the "no remote" note here was stale, contradicting §6 and disproved by a push on 2026-07-18)
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
- 🟢 **Instance stood up in PROD** — `https://id.beauaccesssolutions.com/realms/bas` is the live OIDC issuer (**migrated 2026-07-17** off `id.kindredaccess.org`, so the shared IdP no longer sits under one member app's domain). All five apps verified against it. The old host stays dual-served until the three native builds ship; then it 301s and its DNS record is dropped.
- ⬜ Hardening executed (admin-console lockdown, patching cadence) — confirm against the checklist now that it's live
- 🟡 Login theme re-themed to pass WCAG 2.2 AA — theme on `feat/identity-a11y-login-theme` (unmerged). ✅ **`/bas-design-review` done (2026-07-14):** passes the static/visual bar — contrast recomputed for all pairs in **both** light+dark (lowest 4.62:1 border / 6.2:1 dark button, all clear), focus/reflow/target-size/reduced-motion handled. Applied 2 fixes (checkbox 20→24px SC 2.5.8; input `font-size: max(1rem,16px)` iOS-zoom guarantee). ⬜ **One open verification:** it's CSS-only, so the login-**error** path (announce `role=alert` + move focus + preserve username) is inherited from `keycloak.v2` and must be exercised on the live page — may need a minimal template touch. ⬜ confirm this theme is the one serving on prod (`id.beauaccesssolutions.com`)
- 🟢 OIDC clients per app + `aud`/`azp` isolation — all five registered in the `bas` realm and exercised against **prod** (`id.beauaccesssolutions.com`): `cit-web`, `kindredaccess-web`, `benefits-navigator-web`, `disability-wiki-web`, and **`access-atlas`** (bare — the client IDs are *not* uniformly suffixed, so verify rather than infer). KA rejects a sibling `azp`.
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

- ✅ **Accessibility invariants moved from prose to CI gates (2026-07-18).** A verification sweep over the lessons files found four §4-spine entries that were *implemented correctly but untested* — the fix had landed and the reasoning sat in a code comment, which documents intent but does not defend it. Now enforced, all mutation-tested (the contract was broken and the right test confirmed to fail):
  - **page-repair** ([#1](https://github.com/Beaudoin0zach/page-repair/pull/1), merged) — live-region spine (both regions pre-created *before* the first message; failures assertive; partial progress polite) + `test/contrast.mjs` recomputing every text/UI pair from the token hexes **in both themes**, fail-closed on a `:root` token no verified pair claims. **This repo had no CI at all** — added `.github/workflows/ci.yml`.
  - **disability-wiki** ([#44](https://github.com/Beaudoin0zach/disability-wiki/pull/44), merged) — `tools/check-sw.mjs` **executes** the generated `sw.js` and asserts canonical-only precache + the redirect rewrap. The build already *ran* the generator and asserted nothing; running a generator is not a test. Blocking CI step.
  - **Benefits Navigator** ([#31](https://github.com/Beaudoin0zach/benefits_navigator/pull/31), merged via admin override) — the assistant's inline template script became `static/js/assistant.js` so it could be tested; `tests/js/assistant.a11y.test.mjs` pumps 200 deltas and asserts via MutationObserver that the polite region never changes, plus focus lands on the answer (done) / recovery control (error). Wired in as `npm run test:js`. ⚠️ **Note:** BN CI runs `pytest --ignore=tests/e2e`, so an a11y test placed in `tests/e2e` would gate nothing — that is why this went in as a Node suite. Extraction also removes one inline `<script>` (CSP `'unsafe-inline'` progress). **Unreviewed by a human** (admin bypass); the extraction's faithfulness rests on one reading.
  - **Scoping rule adopted:** a repo-local test does **not** graduate a cross-project lesson — it closes that repo's hole while every other surface keeps the trap. Entries are marked "(page-repair only)" / "(BN only)"; `packages/ui`, the Keycloak theme, and KindredAccess's chat surface remain unenforced prose.

- 🔴 **CIT native announced status to neither screen reader (2026-07-18)** — `bas-apps/apps/cit` had 14 status messages as `{error && <Text accessibilityRole="alert">}`. That role marks a trait but does **not** announce dynamic changes; announcing needs `accessibilityLiveRegion`, which is Android-only and used nowhere in the repo. So every one was silent to **VoiceOver and TalkBack both**, in the app shipping as Baseline on TestFlight. Two of the 14 were a second defect — a *success* message routed to the assertive channel (§4 C1). **Fix open as [bas-apps#1](https://github.com/Beaudoin0zach/bas-apps/pull/1)**: adds the `packages/ui` live-region utility that design-principles §4 always claimed `packages/ui` provided and which **did not exist** — the root cause of every app hand-rolling status. Ships `bas-apps`' first tests and first CI (both gates green). ⚠️ **Not device-verified** — RN semantics and code confirmed, no VoiceOver/TalkBack run on hardware; that check should precede merge.

- ⚠️ **`bas-apps` is invisible to platform tooling** — it has no symlink in `repos/`, so `platform-status.sh` does not report it and the §4.1 audit initially missed it. Everything else the platform ships is registered there. Adding it would close the gap.

- ✅ **§4.1 gate audit (2026-07-18)** — C3 (no double-read) gained a real gate: page-repair `test/unit.mjs` "no double-read (§4 C3)", merged as [page-repair#2](https://github.com/Beaudoin0zach/page-repair/pull/2), CI green. Auditing the other rows found the table wrong in both directions: C1 was credited to page-repair alone (BN enforces it more completely; KindredAccess only the markup half), C3 was marked "unenforced everywhere" when KindredAccess had shipped a gate with the original fix, and CIT web was written off as "not checked out" when it is registered in `repos/` and carries the portfolio's **strongest** C4 gate. Partial gates are now marked as such — a named gate had been reading as full coverage when it usually covers one half.

- 🟡 **CIT numeric-PHI leak found in passing (2026-07-18)** — CIT's PHI drift test parses `schema.prisma` but collected only `String` columns, so `bpSystolic` / `bpDiastolic` / `heartRate` / `temperature` were unclassified in `PHI_FIELDS`. **Fix open as [Chronic-Illness-Tracker#41](https://github.com/Beaudoin0zach/Chronic-Illness-Tracker/pull/41)** (branch `claude/nervous-elion-60f351`, awaiting review — privacy-touching, second review requested). Parser now covers all scalar types **plus enum columns**; widening it alone surfaced **390 unclassified columns**. ⚠️ **Mechanism correction:** the exposure path is `sanitize()`'s structured-payload branch (a strict allow-list), **not** stringified errors — `scrubString` already default-redacts every `key: value` outside a small diagnostic allow-list, so the earlier "passed unredacted into stringified Prisma errors" claim here was wrong. Open judgment call for the reviewer: `status` is classified *safe*, so a payload logging `DoseEvent.status` beside a `userId` would still show `taken`/`skipped`. General lesson recorded: *a derived test still has the shape of its parser — check what your parser cannot see.*

- 🟡 **`/bas-design-review` sweep (2026-07-14).** Reviewed to the WCAG 2.2 AA bar. ✅ **Done:** Benefits Navigator, CIT, **Keycloak login theme** (passed static layer; 2 CSS fixes applied — 24px checkbox + guaranteed 16px input; open: verify the inherited `keycloak.v2` error path announces/moves focus), **KindredAccess** (non-chat surfaces — found + fixed a **dark-theme contrast blocker** on the signup password meter/requirements, plus autocomplete/dark-theme/live-region should-fixes; ✅ **merged to `main`** — ships on next manual deploy), **Access Atlas** (passed; fixed the **form-input-loss on validation** via a zero-JS cookie echo + field-level errors + up-front size limit; ✅ **merged to `main`** → auto-deployed to prod), **page-repair** (blocking finding = no assertive `role="alert"` region for genuine failures; turned out the fix already existed on the stranded 07-13 `a11y/overlay-ux-doc-and-review-fixes` branch — **merged to `Beaudoin0zach/main`** along with options dark-theme + shadow-root isolation, plus closed the last two items: 24px reveal checkbox + blame-free timeout copy; 22 tests pass), **a11y-probe** (2 hard AA failures — `user-scalable=no` disabled zoom + a 3.56:1 dark Start button — plus input-border contrast + a per-keystroke live region; all fixed, ✅ **merged to `main`**, pushed), **marketing site** (light-only static; one AA miss — footer `text-gray-500` ~3.6:1 → `gray-400` ~7:1 — plus a reduced-motion guard, contact-form autofill tokens, and deleting a dead Tailwind v4 config; fixed on branch `a11y/review-fixes`, ⬜ **not merged** — repo is local-only + has active WIP, so folded in by owner). **✅ SWEEP COMPLETE — all 8 surfaces reviewed to the AA bar.** Minor deferred: KA password-match input *border* color (`signup.html:406`) is theme-fixed hex (reinforced by text, so not color-alone). Product decisions left to owner (marketing site): Contact not in desktop header, "Get Started" has two destinations.
  - ⚠️ **page-repair repo consolidation:** `Beaudoin0zach/page-repair` is now the current/primary repo — **9 commits ahead** of the "canonical" `LangworthyWatch/page-repair` (last pushed 2026-07-07, a strict ancestor). Per the decision to have it live under Beaudoin0zach, treat Beaudoin0zach as canonical; LangworthyWatch is stale — sync or retire it.
- 🟡 **CIT launch-readiness sweep (2026-07-08)** — landed on branch `chore/launch-prep` (pushed to `Beaudoin0zach/Chronic-Illness-Tracker`, 2 commits; **PR not opened** — <https://github.com/Beaudoin0zach/Chronic-Illness-Tracker/compare/main...chore/launch-prep>). ⚠ Branched off `fix/security-audit-batch-4`, so it currently stacks on the unmerged security work.
  - ✅ **Full-app i18n** — closes non-negotiable #10 (was a hard launch gate). next-intl is now actually wired (plugin + provider + dynamic `lang`); all ~35 pages/components render from `locales/en.json` (~250 new keys). `RELEASED_LOCALES=['en']` structurally blocks the unreviewed `es.json` from ever being served (#11). Reuses `locales/*.json` cleanly for the eventual Expo rebuild (Phase 3).
  - ✅ **CI backstop** — `.github/workflows/ci.yml` runs lint + 188 tests + build on every push/PR to `main` (there was none). Doubles as the a11y/import-boundary gate seam for Phase 0.
  - ✅ **Change-password + "log out other devices"** — new endpoints wired into Settings; first real trigger for session revocation. (Password login is retired later once Keycloak is live — Phase 2.)
  - ✅ **macOS PHI pre-commit hook** — was a silent no-op (`grep -P` on BSD grep); reimplemented in python3.
  - ✅ **Security-audit batches 1–4 are now merged to `main`** (`fix/security-audit-batch-1..4`), so that gate is cleared. `chore/launch-prep` itself may still be unmerged. Still to do before a live deploy: **rotate the Anthropic API key** (real key in local `.env`), and no scheduled AI-retention job yet.
  - ✅ **Signup account-enumeration closed** — email-verification signup via Postmark (**CIT PR #2 merged to `main`**). Replaces the `409 email_taken` oracle with a uniform `202`; login now blocked until verified. ⚠ **Deploy gate:** the live app needs `EMAIL_PROVIDER=postmark` + `POSTMARK_API_TOKEN` + `EMAIL_FROM` set or **no one can sign in** (main has `deploy_on_push`). CI didn't gate this specific merge, but **CIT CI is now working and green on `main`** — the repo's Actions had never once run since the `Beaudoin0zach` migration; triggering them surfaced (and PR #7 fixed) a lint failure + a `jest` config that couldn't load on CI's Node 20. `main` now passes Lint/Test/Build.
- ✅ **Disability Wiki added to the tracker (2026-07-16)** — reconciled a **one-sided membership**: `Beaudoin0zach/disability-wiki` had declared itself a BAS member in its own `docs/platform-membership.md` (2026-07-14) but was absent from this tracker, README, and PLATFORM. Now listed in §1 + §2. It has **migrated off Wiki.js to static Astro Starlight** (~540 pages on Cloudflare Pages, live at <https://disabilitywiki.org>); the legacy Wiki.js `docker-compose.yml` on the default branch is retired scaffolding, not the live stack. Built **Access-Atlas-shaped**: account-free static browsing + Keycloak BFF contributor auth + Supabase moderation queue (Phases 1–3 code-complete + tested on a feature branch, fail-closed, inert until a Supabase project + registered Keycloak client + data-controller sign-off). **Key divergence from Atlas:** its read path is **DB-free static** (Supabase is write-only staging), so the two stay *sibling apps sharing a template*, not one merged app. Also fixed a stale governance URL in its membership doc (`Beau-Access-Solutions` → `bas-platform`).
- ✅ **access-directory (Access Atlas) now has a remote** — `Beaudoin0zach/access-atlas` (public), onboarded on `main` with a governance pointer + inlined invariants (`docs/platform-membership.md`). Scoped as a full identity member: browsing stays account-free; identity gates contribution only; browsing surface stays Astro/zero-JS (no RN rewrite).
- ✅ **Access Atlas app-side invariants — 3 of 5 merged to `main`** (PR #1, `platform-seed-and-data-rights`; also landed the WNY seed pipeline + drop-in Keycloak BFF contributor auth):
  - ✅ **#2 tracking/CSP** — own CSP + security headers (one policy, applied as `<meta>` for static pages + HTTP headers for SSR); `script-src 'none'` makes its zero-JS surface self-enforcing.
  - ✅ **#3 decoupled delete/export** — complete, independently-callable workflow (`src/lib/data-rights.ts` + ops CLI, storage-aware, idempotent, unit-tested), keyed by contributor id so the Keycloak `sub` drops in unchanged. Self-service UI door deferred to the authenticated contribute milestone.
  - ✅ **#4 contribution boundary** — `.github/CODEOWNERS` on the write path, service-role client, identity seam, and safety-critical SQL (needs "Require review from Code Owners" toggled on in branch protection).
  - 🟡 **#1 layered sessions** now underway — a **drop-in Keycloak contributor auth (server-side BFF)** landed on the branch. ⏳ **#5 i18n** still pending Keycloak (Phase 0/1). Also on the branch: a WNY seed-data importer (creates self-reported data only).
- ✅ **Mobile app source backup — COMPLETE (2026-07-14).** All four mobile repos pushed to private `Beaudoin0zach/*` repos: **`bas-apps`** (the **Baseline**/CIT native Expo app + shared `ui`/`auth`/`tokens`/`i18n`/`api` packages), **`kindredaccess-ios`** (KA wrapper, incl. its App Store screenshots), **`bas-frontend`**, and **`access-atlas-mobile`** (its uncommitted EAS/App.js work was committed first as a backup snapshot). The Access Atlas + KindredAccess *web* wrapper configs already live inside their pushed web repos.**Decision (2026-07-14, reviewed + EXECUTED): retired `access-atlas-mobile`** (redundant Expo webview wrapper) — GitHub repo **archived** (read-only, still backed up). Canonical Access Atlas iOS build stays the `access-directory` Capacitor wrapper (Capacitor = platform wrapper toolchain; Expo = the native CIT app). ✅ **Salvaged its one good idea:** the Expo `App.js` kept the Keycloak IdP host in-app; the Capacitor config had **no `allowNavigation`**, so its default would bounce OIDC login to Safari and break the round-trip. Fix (`allowNavigation: ['id.kindredaccess.org']`; everything else opens in Safari) **merged to `access-directory` `main`** (2026-07-14) — ⚠️ *superseded 2026-07-17: that host is now `id.beauaccesssolutions.com` (branch `feat/idp-beauaccesssolutions-allownav`, pending a rebuild); don't copy the old value* and the local Expo dir **deleted** (remote archived + backed up). ✅ **New TestFlight build uploaded** (2026-07-14, build 2 via `cap sync ios` → Xcode archive) carrying the fix. ⬜ Final check: once it finishes processing, install build 2 and confirm login opens the Keycloak screen **in-app** (not Safari) and returns logged in.
- ✅ **a11y-probe repo initialized** — `Beaudoin0zach/a11y-probe` (private), `main` pushed (initial commit 2026-07-14). ⬜ still not published to Devvit.
- ✅ **Pointer PRs merged** — CIT #1, KindredAccess #2, Benefits Navigator #23, and Access Atlas #1 are all **merged to `main`**; page-repair's remains unverifiable from this account (third-party `LangworthyWatch` repo).
- ✅ **Push governance repo** — done (`main` live).
- 🟡 **KindredAccess OIDC integration** (2026-07-08) — Django resource server done and verified end-to-end vs dev Keycloak (branch `feat/bas-keycloak-oidc`, KA PR #4). Stores a pairwise `sub` on a new `KeycloakIdentity` model; inert until configured. While verifying, **fixed the dev-realm pairwise mapper** in `identity/dev/realm/bootstrap.sh` for **both** `cit-web` and `kindredaccess-web` — the reference used `oidc-sub-mapper` (non-pairwise, sub = raw user id) instead of `oidc-sha256-pairwise-sub-mapper`. Separately, KA's WebSocket deploy config was corrected (Gunicorn+Daphne, KA PR #3). ⬜ Existing-user migration for KA still pending (below).
- 🟡 **Cross-app correlation** — adopt pairwise `sub` ([ADR-003](docs/adr/003-pairwise-subject-identifiers.md)) before any app stores a shared identifier. **KA now stores a pairwise sub (verified in dev).** ⬜ enforce for `cit-web` and in prod (needs sector-identifier/salt strategy).
- 🟡 **Existing-user migration** into Keycloak ([ADR-004](docs/adr/004-existing-user-migration.md)) — CIT reference runbook, then KA + Benefits Navigator. (KA code links legacy accounts by verified email at first login.) KA's Keycloak user-migration **export command** (ADR-004) is now **merged to `main`** (KA PR #5, which also landed an automated vision first-pass for photo moderation). **Hardened via adversarially-verified review (KA PR #6, merged 2026-07-09):** removed the superuser `emailVerified:true` carve-out (unverified admin emails were an IdP-password-reset takeover vector for the highest-privilege accounts — unverified admins now take the one-time reset path), plus moderation-pipeline fixes. The **firstName/lastName-optional user profile** KA migration needs is already covered: `main`'s bootstrap (platform PR #4, validated on KC 26) relaxes the declarative profile — Keycloak 24+ otherwise flags KA's single-display_name migrated accounts "not fully set up" and blocks login. Remaining: partialImport dry-run + one migrated-login round-trip on the rebuilt realm, then the prod runbook.
- 🟡 **Benefits Navigator data posture** — framed in [ADR-005](docs/adr/005-benefits-navigator-data-posture.md); BN is engineered conservatively to full-Member spec, but stays **Candidate** pending a **BAS LLC legal determination** (38 U.S.C. §5701 / 38 CFR §§1.500–1.527 / Privacy Act flow-down vs HIPAA). This is the one item gating Candidate → Member — a decision, not code.
- ✅ **BN staging secrets + DB hardening — DONE (2026-07-18).** On DO app `benefits-navigator-staging` (serves **vabenefitsnavigator.org**): (1) `SECRET_KEY` / `FIELD_ENCRYPTION_KEY` / `OIDC_RP_CLIENT_SECRET` converted to **`type: SECRET`** — no longer readable via `doctl apps spec get`; the `benefits-navigator-web` **client secret was also rotated in Keycloak** first (the old value had been plaintext-readable in the spec), the new one persisted to `/opt/keycloak/secrets.env` — closing the long-standing "generated but never persisted" gap — and verified at the **token endpoint** (rotated secret + bogus code → `invalid_grant`; wrong secret → `unauthorized_client`); (2) all **component-level duplicate env vars removed**, leaving one app-level definition each (component copies silently override app-level ones — the trap documented in the `do-app-platform-debug` skill); (3) `DATABASE_URL` / `REDIS_URL` are now **bindable references** (`${benefits-nav-db.DATABASE_URL}`, `${valkey.DATABASE_URL}`) with both managed clusters attached as spec `databases:` components, so DO injects current credentials at deploy time and a password rotation can't strand the app; (4) the PG binding moved **off `doadmin` to a dedicated `benefits_navigator` cluster user** that now owns the DB and all 84 tables (`doadmin` retains access via role membership for manual ops). **This is the pattern to copy to Access Atlas and CIT** — both still hold plaintext env vars. ⬜ Judgment call still open: whether to **rotate** `SECRET_KEY`/`FIELD_ENCRYPTION_KEY` (they sat plaintext-readable in the spec for a long time; rotation drops sessions / breaks encrypted fields).
- ✅ **BN staging Redis outage — RESOLVED (2026-07-18).** Login had been 500ing while `/` returned 200: the **web** component carried a `REDIS_URL` override pointing at an **Upstash** instance whose 500k free-tier quota was exhausted (`max requests limit exceeded` on every session write), while worker/migrate used the healthy DO Valkey — so web and worker were also on **different Celery brokers**. Removing the override (part of the hardening above) put every component on `db-valkey-nyc3-98037`. Verified end-to-end on the prod domain. The orphaned **Upstash account has been deleted** (2026-07-18); confirmed zero references remained in any DO app spec, the `bas-keycloak` droplet, or any repo, and all three DO apps probe healthy after deletion.
- 🟡 **page-repair store submission prepared** — v1.0.0 release manifest, icons, [PRIVACY.md](repos/page-repair/PRIVACY.md), [STORE_LISTING.md](repos/page-repair/STORE_LISTING.md), and `dist/page-repair.zip` are ready; **not submitted** (needs a Chrome Web Store dev account + real-page screenshots). Changes are uncommitted in the working tree.
- ⏳ **page-repair proxy inert** — Cloudflare Worker is live but needs `wrangler secret put ANTHROPIC_API_KEY` (+ a redeploy of the pending health-route change) before paid labeling works.
- 🟢 **Marketing site — LIVE at <https://beauaccesssolutions.com>** (2026-07-16). Repo **`Beaudoin0zach/bas-website`** (private); the site was **remade around the app portfolio** (new `/apps` page featuring Baseline/KindredAccess/BN/Access Atlas/Page Repair/a11y-probe, home repositioned to lead with products, Contact added to nav) while **keeping the consulting content**. Deployed via `netlify deploy --prod` from the site dir (Netlify site `620702da`, `beaudoin0zach@gmail.com` account). Cleaned up: removed the SPA `/* → /index.html` catch-all + added a branded 404 page (mistyped URLs now 404 instead of silently showing home). ✅ **Continuous deploy now wired** — Netlify site linked to `Beaudoin0zach/bas-website` `main` (`npm run build` → `dist`); verified a push auto-builds + publishes. ⚠️ **Incident + naming hazard (2026-07-16):** the repo was first mis-linked in the Netlify UI to **`Beaudoin0zach/Beau-Access-Solutions`** (this platform hub — near-identical name), so a TRACKER push to *this* repo triggered a wrong-repo build that broke the live site (home → 404); restored by a manual redeploy and the link corrected to `bas-website`. ✅ **Resolved by renaming this platform repo `Beau-Access-Solutions` → `Beaudoin0zach/bas-platform` (2026-07-16)** so it can't be confused with the `bas-website` site repo again (GitHub auto-redirects the old name; local remote repointed). The marketing Netlify site watches `bas-website` only, so pushing here is safe.
  - ✅ **App links + a11y + CI pass (2026-07-18, 3 commits, live).** (1) **Disability Wiki was missing from the site entirely** despite being live — added, and VA Benefits Navigator repointed from `/contact` to <https://vabenefitsnavigator.org>; both probed 200 before linking. Atlas + CIT still show DO hostnames (no custom domain yet), which is now the only unpolished link on `/apps`. (2) Site settled on **company "we"** — it had been mixed (`/apps` all "we", `/services`+`/about` all "I", home both on one page); first person preserved where it's the only truthful option (the `/about` bio, and the contact form's "I'm interested in…" label, where the "I" is the *visitor*). (3) **a11y:** four design tokens (`bg-forest-50`, `text-forest-800/900`, `border-forest-200`) were used but never defined, so Tailwind emitted **zero CSS** and the `/apps` status chips rendered unstyled — silently, since dark-on-light still looks plausible; plus 4 computed contrast failures (terracotta chip 3.00:1, required asterisk 3.76:1, input borders 1.47:1, and blog body text on a *tinted* background 3.93:1 — that last one only appears once the background's alpha is blended, which a white-only sweep cannot see); `aria-current` and the visual nav highlight used different predicates, so on `/apps/access-atlas` sighted users saw "Apps" lit and screen-reader users were told nothing was current. (4) **This repo had no CI and no tests** — added `test/contrast.mjs` (18 pairs recomputed from token hexes with alpha blending, **plus an undefined-token scanner**) wired into `npm run build`, so Netlify — whose build command *is* `npm run build` — cannot publish a regression; verified fail-closed by injecting both regression types. (5) Fonts **self-hosted** (Google now ships these as latin *variable* files: 2 files/82 KB, not 5 statics) — page now makes **zero third-party requests**, verified via `performance.getEntriesByType('resource')`. ⬜ Still open: contact-form validation/success states (submits land on Netlify's generic page), real dark mode (only `color-scheme: light` is declared — an honest stopgap, not a theme), and a founder note on the home page.
- ⬜ Decide the shared-frontend repo name (`design-system`) when Phase 0 needs shared code.

---

## 7. Decision log

- [PLATFORM.md](PLATFORM.md) — architecture anchor
- [INVARIANTS.md](INVARIANTS.md) — the five platform invariants
- [ADR-001](docs/adr/001-platform-architecture-and-identity.md) — shared platform + standalone Keycloak identity
- [ADR-002](docs/adr/002-umbrella-org-and-repo-topology.md) — BAS umbrella, repo topology, no committed cross-repo symlinks
- [ADR-003](docs/adr/003-pairwise-subject-identifiers.md) — pairwise subject identifiers (no cross-app correlation)
- [ADR-004](docs/adr/004-existing-user-migration.md) — migrating existing users into Keycloak
- [ADR-005](docs/adr/005-benefits-navigator-data-posture.md) — Benefits Navigator data posture (Privacy Act / VA vs HIPAA)
- CIT `docs/adr/004` — CIT-side pointer to the identity decision
- CIT `docs/mobile/PLAN.md` — native build plan; `docs/mobile/auth-token-exchange.md` — token-exchange spec
- **Private:** `Beaudoin0zach/bas-internal` — business-sensitive + consolidated-security docs (pricing/cost model, review remediations) kept out of this public repo
