# Mobile apps & TestFlight — how the iOS builds work

The single reference for how the Beau Access Solutions iOS apps are built and how
an edit reaches testers. Written 2026-07-14 after a status pass found the tracker
badly out of date on this (it treated TestFlight as unstarted; all three apps are
live on it). See [TRACKER.md §2b](../TRACKER.md).

## The TestFlight apps (all 5 live as of 2026-07-18)

| TestFlight name | App | Build type | Source repo | Latest build |
|---|---|---|---|---|
| **Access Atlas** | Access Atlas | Capacitor / WKWebView **wrapper** | `access-directory` (`capacitor.config.ts`) | 🟢 **1.0.0 (3)** — issuer-migration rebuild, uploaded 2026-07-18. NB: ASC already held a build 2 no doc knew about |
| **KindredAccess** | KindredAccess | Capacitor / WKWebView **wrapper** | `kindredaccess-ios` ⚠️ *no remote* | 🟢 **1.0 (2)** — issuer-migration rebuild, uploaded 2026-07-18 |
| **Baseline** | Chronic Illness Tracker (CIT) | **native Expo / React Native** (EAS) | `bas-apps/apps/cit` (remote `Beaudoin0zach/bas-apps`) | 🟢 **1.0.0 (7)** — issuer-migration rebuild, EAS build + auto-submit 2026-07-18 |
| Benefits Navigator | Benefits Navigator | Capacitor 8 / WKWebView **wrapper** | `benefits-navigator` `mobile/` (merged to `main`, PR #30) | 🟢 **1.0 (1)** — FIRST build, uploaded 2026-07-18 (`com.beauaccess.benefitsnavigator`; wraps **staging**, deliberately) |
| Disability Wiki | Disability Wiki | Capacitor 6 **bundled-static** (offline-first, NOT a URL wrapper) | `disability-wiki` `app/` (merged to `main`, PR #43) | 🟢 **1.0 (1)** — FIRST build, uploaded 2026-07-18 (`org.disabilitywiki.app`, ~102 MB bundle) |

> **Archive/upload runbook (proven 2026-07-18, all four Capacitor apps):** archive with
> `CODE_SIGNING_ALLOWED=NO`, then `xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist
> -allowProvisioningUpdates` — distribution signing happens at export (no registered devices needed;
> the team has none). Each repo carries its `ExportOptions.plist`. Needs a signed-in Xcode Apple ID.
> Machine quirks: `LANG=en_US.UTF-8` (CocoaPods) + `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
> Build numbers: trust App Store Connect, not the local project — expect "Redundant Binary Upload" and bump.
> France availability: skipped on all five (would require the ANSSI encryption declaration; no French audience).

> **CIT ships as "Baseline" on TestFlight.** If you're looking for CIT in App Store
> Connect / TestFlight, it's under that name.

## Two very different architectures

### 1. Webview wrappers (Access Atlas, KindredAccess)

A thin native binary whose only job is to load a **hosted website** in a
WKWebView at runtime (`capacitor.config.ts` → `server.url`). The "app" is really
the live site.

- **Access Atlas** loads `https://access-atlas-qd464.ondigitalocean.app`
- **KindredAccess** loads `https://kindredaccess.org`
- **Benefits Navigator** (scaffolded) loads `https://benefits-navigator-staging-3o4rq.ondigitalocean.app`
  — **staging, deliberately**: verified 2026-07-18 that no BN prod app or custom
  domain exists, and while BN is Candidate under ADR-005 internal testers should
  hit staging. Its `allowNavigation` already targets `id.beauaccesssolutions.com`
  (staging's live issuer), so it starts on the config the other three are
  rebuilding toward.

**Consequence:** a code/content edit ships by **redeploying the web app**, NOT by
rebuilding for TestFlight. A tester sees it on next launch (force-quit to clear
the WKWebView cache). You only need a **new TestFlight build** when the *native
shell* changes: app icon, splash, `server.url`, native plugins, or a version bump
for a fresh review round.

### 2. Native Expo app (Baseline / CIT)

`bas-apps/apps/cit` is a real React Native app (Expo, EAS-built, bundle
`com.beauaccesssolutions.cit`). It renders native screens and calls the CIT API
backend (`EXPO_PUBLIC_CIT_API_URL` → `https://chronic-illness-tracker-7o7fw.ondigitalocean.app/api`),
authenticating via prod Keycloak (`https://id.kindredaccess.org/realms/bas`).

**Consequence:** its own code edits do **not** auto-appear. Two paths:

| Change | How it ships | New TestFlight build? |
|---|---|---|
| JS/TS only (screens, logic), native runtime unchanged | `eas update --channel production` (OTA) | **No** — testers get it on next launch |
| Native (new modules, permissions, `runtimeVersion` bump, icons) | `eas build` + `eas submit` | **Yes** |

A **server-side backend fix** reaches Baseline only through the API it calls, and
only for features the native app actually has. (Example: the 2026-07-14 AI
date-range fix is in the CIT *backend*; Baseline has **no AI-insights screen yet**,
so it's a no-op there until that screen is ported.)

## "I made an edit — how do I get it in front of testers?"

1. **Which app?**
   - Access Atlas / KindredAccess → it's a wrapper. **Deploy the web app** (below). Done. No build.
   - Baseline (CIT) → native. JS-only change → `eas update`. Native change → `eas build` + `eas submit`.
2. **Web deploy triggers:**
   - **Access Atlas** — `deploy_on_push: true` on `main` (auto). Merge → live in minutes → relaunch app.
   - **CIT backend** — `deploy_on_push: true` on `main` (auto).
   - **KindredAccess** — **manual SSH** to the DO Droplet. `main` edits do **not** reach `kindredaccess.org` (or the app) until someone redeploys.
   - **Keycloak** (`id.kindredaccess.org`) — manual.
3. **Cache:** if a wrapper shows stale content, force-quit and reopen (WKWebView cache).

## Known gotchas

- **External TestFlight review, Access Atlas:** a bare webview wrapper is rejected
  under App Store **Guideline 4.2**. Internal TestFlight (≤100 testers) is fine.
  Clearing external review needs the camera evidence-photo feature
  (`access-directory` iOS runbook).
- **Mobile source backup — complete (2026-07-14):** all four mobile repos are
  pushed to private `Beaudoin0zach/*` repos — `bas-apps` (Baseline/CIT app +
  shared `ui`/`auth`/`tokens`/`i18n`/`api` packages), `kindredaccess-ios`,
  `bas-frontend`, and `access-atlas-mobile` (its pending EAS/App.js work was
  committed as a backup snapshot first). Tracked in [TRACKER.md §6](../TRACKER.md).
- **`access-atlas-mobile` is a superseded earlier Expo attempt** (now backed up,
  with its EAS/App.js buildout committed). The real Access Atlas TestFlight build
  is the Capacitor wrapper in `access-directory`, not this — decide whether to
  fold in its work or retire the repo.
- **Disability Wiki — iOS platform added (2026-07-18), NOT on TestFlight yet.**
  Branch `feat/capacitor-ios` (supersedes the `spike/capacitor-native` scaffold,
  cherry-picked onto current `main`): `app/ios/` committed, unsigned simulator
  build passes. **Deliberately NOT a URL wrapper** — it bundles `site/dist`
  (~102 MB) into the binary for a genuinely offline wiki (crisis pages must load
  offline) and a stronger Guideline 4.2 story. Consequence: content updates need
  a new build, the opposite tradeoff from the other wrappers. Known gap: the
  bundled `/contribute` form posts to a relative `/api/contributions` that has no
  backend inside the bundle (see `app/README.md` open question #5).
- **This machine's build quirks (2026-07-18):** CocoaPods dies without
  `LANG=en_US.UTF-8`; `xcodebuild` needs
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (xcode-select points
  at the bare CLT). Capacitor 8 projects (BN) use SPM — no CocoaPods at all.

## Live endpoints (verified 2026-07-14, HTTP 200)

| What | URL | Deploy |
|---|---|---|
| CIT backend (Baseline's API) | `https://chronic-illness-tracker-7o7fw.ondigitalocean.app` | auto (`main`) |
| Access Atlas web (wrapper target) | `https://access-atlas-qd464.ondigitalocean.app` | auto (`main`) |
| KindredAccess web (wrapper target) | `https://kindredaccess.org` | manual (SSH) |
| Keycloak prod (issuer) | `https://id.kindredaccess.org/realms/bas` | manual |
| Benefits Navigator staging | `https://benefits-navigator-staging-3o4rq.ondigitalocean.app` | on push |
