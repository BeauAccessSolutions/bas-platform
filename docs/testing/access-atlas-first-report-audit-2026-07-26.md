# Access Atlas — vertical-slice audit: the first-report / visit-confirmation flow

**Date:** 2026-07-26
**Method:** `/vertical-slice-audit` (Phases 0–8)
**Gate verdict:** **BLOCKED** — see F-1.

---

## Provenance (Phase 0)

| Surface | Identity | Relationship to `origin/main` |
|---|---|---|
| **Production web** | DO App Platform app `a39a2fb9-a85c-4916-ba6a-65743cbcee54`, deployment `3ac8b528-…`, phase `ACTIVE`, promoted 2026-07-24T17:34:53Z, service `web` @ **`9e5b89f`** | **Current** — `9e5b89f` is the tip of `origin/main`. No deployment lag. |
| **Local checkout** | `1b6bcd6` on branch `fix/ios-safe-area` | **DIVERGENT / behind.** Content-identical to production *except* it lacks `60a381d` (the CSRF fix: `astro.config.mjs` + `.env.example`, +60 lines). |
| **Production DB** | Supabase cloud `gclxpbjifxwrhueopdta` | Migrations `0001`–`0011` all applied. **No schema drift.** |
| **iOS** | `ios/` is **not committed** (0 tracked files); no TestFlight build identity exists in-repo | NOT-BUILT as a shipped surface. |

- Default branch: `main` (confirmed via `origin/HEAD`, not assumed).
- Live URL: `https://access-atlas-qd464.ondigitalocean.app`.
- Every slice file audited below is byte-identical between `1b6bcd6` and `9e5b89f`, so slice verdicts apply to production. The two files that differ are the subject of F-1 and were read from `origin/main` directly (`git show origin/main:astro.config.mjs`).

**Mutation budget declared and honored:** read-only. No migrations applied, no rows written, no deploys, no spec updates, no `npm audit fix`. Production probes were limited to `GET`s and to `POST`s that are rejected at the CSRF layer *before* any handler runs (proven, not assumed — see F-1) plus empty-body POSTs that would fail validation even if they passed. All DB access was `SELECT`-only against catalog and count queries. **Not run:** `npm run test:a11y` locally (port 4321 is held by an unrelated project's server — see F-6); CI results for the shipped commit are used instead.

---

## Findings

### F-1 · P0 · Every form POST in production is rejected — the entire write surface has never worked

**The fix for this shipped as dead code.** `60a381d` ("trust the proxy-forwarded host so production form POSTs work") added `security.allowedDomains` to [`astro.config.mjs`](astro.config.mjs), populated from a **build-time** `SITE_ORIGINS` env var. That variable is set nowhere:

- absent from [`.do/app.yaml`](.do/app.yaml);
- absent from the live spec (`doctl apps spec get` — 8 envs, none named `SITE_ORIGINS`);
- and the [`Dockerfile`](Dockerfile) declares no `ARG SITE_ORIGINS`, so even a `BUILD_TIME`-scoped var in the spec would not reach `RUN npm run build`.

So `allowedDomainsFromEnv()` returns `[]`, Astro refuses the forwarded host, computes its own origin as `https://localhost`, and rejects every browser POST.

**Failure scenario (verified against production, not inferred):** a contributor opens `/contribute/report/<listingId>/accessible_restroom/`, fills in the visit-report form, attaches a photo, presses "Submit my report" → the browser replaces the styled page with a bare `text/plain` body reading `Cross-site POST form submissions are forbidden`. No banner, no field-level error, no way back, no record written. The typed report and the attached photo are gone.

Verified 7/7 POST endpoints, each with a correct same-origin `Origin` header:

```
POST /api/settings        -> 403 Cross-site POST form submissions are forbidden
POST /api/listings        -> 403  (submit a listing)
POST /api/confirmations   -> 403  (first report AND per-claim confirm)
POST /api/photo-reports   -> 403  (report a photo)
POST /api/auth/logout     -> 403  (sign out)
POST /api/account/export  -> 403  (§6 data export)
POST /api/account/delete  -> 403  (§6 data deletion)
```

**Corroborated by production data.** The database has `confirmations = 0`, `contributors = 0`, `contributor_sessions = 0`, and all 73 attribute claims sit at `self_reported`. Across 163 listings, **not one community validation has ever been recorded.** The §4 consensus engine — the stated moat — has never run on real input.

Blast radius beyond the slice: the accessibility-settings form (§2/§5), listing submission, and both §6 data-rights doors are equally dead. The iOS Capacitor wrapper loads this same origin (`capacitor.config.ts` `server.url`), so it inherits the identical failure.

**Fix (both halves are required):**

1. In the `builder` stage of `Dockerfile`, before `RUN npm run build`:
   ```dockerfile
   ARG SITE_ORIGINS=""
   ENV SITE_ORIGINS=$SITE_ORIGINS
   ```
2. In `.do/app.yaml` under the `web` service, and applied to the live spec:
   ```yaml
   - key: SITE_ORIGINS
     scope: BUILD_TIME
     value: "access-atlas-qd464.ondigitalocean.app"
   ```

Do **not** disable `checkOrigin` — with a zero-JS surface no client-token CSRF scheme is possible, so the origin check is the only layer there is (the config comment already says this; it is correct).

**Verify after deploy** by re-running the 7-endpoint probe above: `/api/settings` should return `303`, and the others should return `303` with an honest gate status (`need_signin`), not `403`.

---

### F-2 · P1 · The PRE_DEPLOY migration gate exists in the repo and not in production

`.do/app.yaml` defines a `jobs:` block with a `PRE_DEPLOY` `migrate` job (added `74813d3`, 2026-07-23) whose stated purpose is to fail-close a deploy when the DB can't be migrated — written specifically because shipping code ahead of the schema 500'd the list pages on 2026-07-23 (missing `listings.coords_source` / migration `0011`).

**The live spec contains no `jobs:` section at all.** The committed spec was never applied. The active deployment lists exactly one component (`web`) and zero jobs.

**Failure scenario:** the next PR that adds migration `0012` merges to `main`; `deploy_on_push` builds and promotes the new `web` container; the migration never runs; the first request touching the new column 500s. This is the exact 2026-07-23 outage, and the control written to prevent it is not in force. Today's saving grace is luck: `0001`–`0011` all happen to be applied.

**Fix:** apply the committed spec — `doctl apps update a39a2fb9-a85c-4916-ba6a-65743cbcee54 --spec .do/app.yaml` — **after** setting the `SUPABASE_DB_URL` secret the job requires, or the very next deploy fails by design. Note the in-file warning: the live spec is authoritative for `KEYCLOAK_ISSUER`; re-applying a stale copy would revert the issuer and break login. Reconcile `.do/app.yaml` against `doctl apps spec get` before applying, and fold F-1's `SITE_ORIGINS` into the same update.

---

### F-3 · P1 · No test at any level exercises a write path

211 tests pass on the shipped commit (122 unit + 89 a11y). **Zero of them issue a POST.** `grep` across `tests/` for `method: 'POST'`, `.post(`, `request.post` returns nothing; the a11y suite navigates 17 GET routes and asserts axe + script-count.

This is the structural reason F-1 shipped green twice: the a11y suite runs `npm run preview` on `localhost:4321` with `SITE_ORIGINS` unset, where the origin check passes trivially because the host genuinely *is* localhost. The production-only failure mode is invisible to CI by construction.

**Failure scenario:** any future change to `/api/confirmations` — the endpoint that decides whether a safety claim gains a confirmation or gets frozen by dissent (§4) — can break silently in production and pass CI.

**Fix:** add a Playwright test that submits the visit-report form end-to-end against the preview server (asserting a `303` and the resulting banner), plus one that asserts a POST carrying a *foreign* `Origin` is rejected. The first would have caught F-1 had CI ever run with a non-localhost host; the second pins the CSRF contract itself. Longer term, a smoke check against the deployed origin post-deploy is what actually catches proxy-shaped bugs.

---

### F-4 · P2 · The public `evidence` storage bucket allows anyone to list every object

Supabase security advisor (`public_bucket_allows_listing`, EXTERNAL): the `evidence` bucket carries a single broad policy `public read: evidence objects` with `qual: (bucket_id = 'evidence')` granted to `public` for `SELECT` on `storage.objects`. Public buckets do not need a listing policy for object-URL reads to work.

**Failure scenario:** once real evidence photos exist, anyone can enumerate the entire bucket — every object path is `<claimId>/<uuid>.jpg`, so this yields a complete inventory of which claims have evidence, how much, and enables bulk download of every disabled contributor's submitted photo in one sweep. That is a data-minimization regression against §6 even though each individual object URL is intentionally public and each photo is EXIF-stripped.

Currently unexploitable only because there are zero photos (a consequence of F-1). It becomes live the moment F-1 is fixed.

**Fix:** drop the broad `SELECT` policy on `storage.objects` for the `evidence` bucket. Public object reads via `/storage/v1/object/public/evidence/<path>` continue to work without it.

---

### F-5 · P2 · `sharp` / libvips CVEs sit directly on the user-upload path — ordering matters

`npm audit --omit=dev`: 8 advisories (5 high, 2 moderate, 1 low). Most are **not applicable here** and I want to be precise rather than alarming:

- The eight `astro` XSS advisories rely on `define:vars`, element spread props, unescaped slot names, or `transition:*` directives. **None of these are used** (`grep` across `src/` returns nothing for all four). Independently, `script-src 'none'` on every route except four — and `'self'` without `'unsafe-inline'` on those four — blocks injected-script execution regardless.
- `svgo` and `tar` are build-time transitive deps, not on any request path.

The one that matters: **`sharp` 0.33.5 / 0.34.5 inherits libvips CVE-2026-33327/33328/35590/35591**, and `sharp` processes **attacker-supplied image bytes** in `/api/confirmations` (`src/pages/api/confirmations.ts:174-186`) — up to 10 MB, decoded before any content validation. A malicious image is the intended input to this code path.

**Failure scenario:** a signed-in contributor uploads a crafted image as "evidence"; libvips decodes it inside the single 0.5 GB web container; memory corruption or exhaustion takes down the whole app (there is one instance, `instance_count: 1`).

Also unexploitable today only because uploads are 403'd. **Fix `sharp` before or in the same change as F-1** — do not open the write path onto a vulnerable decoder. `npm audit fix --force` moves to `sharp@0.35.3` (breaking); pin and re-run the thumbnail tests.

The `astro` "Host header SSRF in prerendered error page fetch" advisory deserves a second look specifically because this app sits behind a header-rewriting proxy; it was not exercised in this audit.

---

### F-6 · P3 · The local a11y gate silently tests whatever is on port 4321

`playwright.config.ts` sets `reuseExistingServer: !process.env.CI` against a hardcoded `http://localhost:4321`. During this audit that port was held by an unrelated project (`disability-wiki` astro preview). Running `npm run test:a11y` would have run Access Atlas's 89 accessibility assertions against a different application, and the results would have looked like real output.

CI is unaffected (`CI=true` forces a fresh server). This is a local-developer trap only — but a11y is the project's existential non-negotiable, so a gate that can quietly grade the wrong site is worth closing.

**Fix:** pick a distinctive port, or add a pre-flight assertion that the reused server serves Access Atlas (e.g. fetch `/` and match the `<title>`).

---

### Observations (not findings — no failure scenario)

- **`security_definer_view` advisor ERRORs on `attribute_claim_status` and `evidence_photos` are correct-by-design here.** Both are owned by `postgres` with `security_invoker` unset, which is exactly what lets `anon` read the filtered aggregate while the base `confirmations` table stays `qual: false`. I checked the write-through risk: `information_schema.views` reports `is_updatable = NO` and `is_insertable_into = NO` for both, so neither can be used to bypass RLS on the base tables. Worth a suppression note in the repo so the next reader doesn't "fix" the privacy boundary away.
- **Broad `anon` table grants are inert.** `anon` holds `INSERT/UPDATE/DELETE/TRUNCATE` on all 9 public tables (Supabase defaults), but RLS is enabled on all 9 and **there is not a single non-SELECT policy** — so PostgREST writes are denied. `TRUNCATE` is not reachable over PostgREST. Confirmed intent-matching read policies: `listings`/`attribute_claims`/`attribute_definitions`/`provider_profiles` are `true`; `confirmations`/`contributors`/`contributor_sessions`/`moderation_audit`/`photo_reports` are `false`.
- **The `evidence_photos` privacy boundary holds as documented:** columns are exactly `listing_id, claim_id, photo_url, photo_thumb_url, photo_alt, agrees, observed_on(date)`. No notes, no identity tags, no contributor id, and the date is coarse.
- **`geolocation=(self)` is over-granted** on `/contribute/confirm/` and `/contribute/report/` (verified live). `securityHeaders()` reuses `routeAllowsScript()` for the geolocation decision, so the camera-enhanced routes inherit a permission ADR-0001 scoped to `/places` and `/providers` only. Harmless in practice (no `connect-src`, and the browser still prompts), but it is a silent widening of a documented boundary — split the two predicates.
- **The `ts(6133) 'suffix' is declared but never read` hint is a false positive.** `astro check` flags `[attributeKey].astro:26`, but the variable *is* read on line 27, and production confirms the behavior it controls: `/contribute/report/<id>/entrance_step_free/?status=thanks` → `303` → `…/contribute/confirm/e81b8208-…/?status=thanks`, status carried. Don't "fix" this by deleting the variable.
- `/contribute/report/<listingId>/<unknown_key>/` returns **200** with a "Nothing to report against" page rather than 404. Honest and accessible; arguably should be a 404 for correctness.

---

## Slice chain — first report / visit confirmation

Surfaces: **production web @ `9e5b89f`** · iOS wrapper NOT-BUILT · slice files identical between local `1b6bcd6` and prod.

```
##  Slice: First report → community confirmation (§4/§13)          P0   BLOCKED

 1  Entry point      src/components/ReportVisitCta.astro:22        UNVERIFIED (render)
                     renders on every listing; claimless branch verified live in HTML
 2  Navigation       report hub /contribute/report/<id>/           PASS   200 live
                     back-link + per-attribute links present in prod HTML
 3  Initial state    src/components/VisitReportForm.astro:43       UNVERIFIED (render)
 4  Input            VisitReportForm.astro:49-166                  UNVERIFIED (device/AT)
                     labels, fieldset/legend, radio+file+text: static read is clean
 5  Validation       src/pages/api/confirmations.ts:99-122         PASS (code)
                     need_answer / photo_required / photo_too_big / alt_required;
                     dissent never requires a photo (§4 favor-dissent) — correct
 6  Draft            src/lib/form-echo.ts via setFormEcho:73       PASS (code)
                     cookie echo restores every field but the file input (documented)
 7  Request          VisitReportForm.astro:43 -> /api/confirmations  FAIL — F-1
                     multipart POST is 403'd at the CSRF layer in production
 8  Authz            src/lib/contributor.ts:135 resolveContributor  PASS (code)
                     verified session → need_signin → provisional → refuse;
                     prod: Keycloak configured, ALLOW_PROVISIONAL=false → sign-in required
                     /api/auth/login 302s to id.beauaccesssolutions.com with PKCE S256 ✓
 9  Persistence      confirmations.ts:141-160, 200-210             UNVERIFIED (no prod row
                     has ever been written; F-1 blocks the only door)
10  Idempotency      confirmations.ts:147 (23505 → re-read winner)  UNVERIFIED (needs DB)
                     confirmations.ts:214 (23505 → 'already')       UNVERIFIED (needs DB)
11  Success feedback confirmations.ts:223 → ?status=thanks banner   UNVERIFIED (render)
12  Failure path     confirmations.ts:38 redirectTo + form echo     FAIL — F-1
                     the CSRF 403 is a bare text/plain page: no banner, no echo,
                     no retry path. The designed failure UX never executes.
13  Read-back        src/components/AttributeList.astro            UNVERIFIED (0 rows exist)
14  Mutation         N-A (confirmations are append-only by design)
15  Deletion         src/lib/data-rights.ts + moderation.ts        PASS (unit) 17/17
16  Export           /api/account/export                           FAIL — F-1 (403)
17  Account deletion /api/account/delete                           FAIL — F-1 (403)
18  Leakage          evidence_photos view columns verified;        PASS (DB-verified)
                     EXIF stripped via sharp re-encode (:165-186)  UNVERIFIED (no upload)
19  Parity           iOS wrapper points at the same origin         NOT-BUILT (ios/ untracked)
20  Tests            zero POST coverage                            FAIL — F-3
```

**Claim-already-exists routing (verified live):** `/contribute/report/<listingId>/entrance_step_free/` → `303` → `/contribute/confirm/e81b8208-…/`, carrying `?status=` when present. Exactly one door per claim, as designed. Unclaimed attribute → `200` first-report form. Trailing-slash variants of both confirm and report routes resolve (`200`/`200`).

---

## Feature matrix

| Feature | Bucket | Production result |
|---|---|---|
| Browse places (list, sort, ZIP filter) | Implemented | **PASS** — 200, 75 places |
| Browse providers | Implemented | **PASS** — 200, 88 providers |
| Listing detail + attribute claims | Implemented | **PASS** — 200, 73 claims render |
| On-device "sort by distance" | Implemented | UNVERIFIED (render) — CSP/Permissions-Policy scoped correctly per route ✓ |
| Honest labeling vocabulary (§4) | Implemented | **PASS** — 122/122 unit incl. labeling + consensus; all 73 claims `self_reported` |
| Accessibility settings (cookie, zero-JS) | Implemented | **FAIL** — F-1 (POST 403) |
| Suggest a listing | Implemented | **FAIL** — F-1 (POST 403) |
| Per-claim confirm flow | Implemented | **FAIL** — F-1 (POST 403) |
| **First-report flow (this slice)** | Implemented | **FAIL** — F-1 (POST 403) |
| Evidence photo capture + rendering | Implemented | UNVERIFIED — 0 photos exist; blocked by F-1; decoder CVEs F-5 |
| Report-a-photo queue | Implemented | **FAIL** — F-1 (POST 403) |
| Contributor auth (Keycloak BFF) | Implemented | **PARTIAL** — `/api/auth/login` 302s correctly with PKCE; callback/logout UNVERIFIED (logout POST 403'd) |
| Data export (§6) | Implemented | **FAIL** — F-1 (POST 403) |
| Data deletion (§6) | Implemented | **FAIL** — F-1 (POST 403) |
| Ops moderation CLIs (redact / takedown) | Implemented | **PASS** (unit 17/17); prod DB path UNVERIFIED — 0 rows to act on |
| PRE_DEPLOY migration gate | Undocumented gap | **FAIL** — F-2 (in repo, not in live spec) |
| iOS TestFlight build | NOT-BUILT | `ios/` untracked; no build identity; inherits F-1 when built |
| Street-level geocoding / address search | NOT-BUILT | open decision (§13) |
| `<details>` filter panels | NOT-BUILT | feature-gated (§13 Tier 3) |

---

## Verification ledger

**Executed:**
- Provenance: `git fetch --all`; both-direction log comparison vs `origin/main`; `doctl apps get` → active deployment `3ac8b528`, `web` @ `9e5b89f`, phase `ACTIVE`; `doctl apps spec get` (live spec, 0 jobs).
- **122/122** unit tests (vitest, 17 files) at local `1b6bcd6`.
- **122/122** unit + **89/89** Playwright/axe at shipped `9e5b89f` — from GitHub Actions run `30113394528`, conclusion `success`.
- `astro check`: **0 errors, 0 warnings, 1 hint** (94 files) — hint investigated and disproved (see Observations).
- `npm audit --omit=dev`: 8 advisories (5 high / 2 moderate / 1 low); each triaged for applicability against `src/`.
- **Production HTTP, 20 probes:** 7/7 POST endpoints → `403`; 7/7 sampled GET routes → `200`; CSP + Permissions-Policy compared across 6 routes and matched the documented per-route contract; `/api/auth/login` → `302` to Keycloak with `code_challenge_method=S256`; report-hub and first-report-form routes; claimed-attribute `303` redirect with and without `?status=`.
- **Production Postgres, 8 read-only queries:** migration list (`0001`–`0011` applied); row counts across 9 tables; `attribute_claim_status` state distribution; RLS enabled-flags on all 9 base tables; full `pg_policies` dump for `public` and `storage`; `information_schema.views` updatability; view column list; view ownership and `reloptions`.
- Supabase security advisors: 2 × `security_definer_view` (ERROR, triaged as by-design), 1 × `public_bucket_allows_listing` (WARN → F-4).

**Not covered:**
- **Any successful write.** Nothing was inserted, so links 9, 10, 11, 13 and the EXIF-stripping half of 18 are `UNVERIFIED` rather than `PASS`. F-1 makes this unverifiable in production and the mutation budget forbids writing rows to prove it. These need a local `supabase db reset` + a real submitted report — the highest-value follow-up after F-1 lands.
- **Local `npm run test:a11y`** — skipped, port 4321 held by another project (F-6). CI results for the shipped commit substituted.
- **All render-dependent links** (1, 3, 4, 11) — static reading cannot establish what renders. Needs a browser and a screen-reader pass.
- **Manual assistive-tech testing** (NVDA/VoiceOver) — required by §5 before shipping any user-facing feature; not performed here and not substitutable by the 89 axe assertions.
- **iOS** — no committed project, no build. Not audited beyond confirming it targets the same origin.
- The `astro` Host-header-SSRF advisory against this specific proxy topology.

---

## Gate verdict: **BLOCKED**

Browsing — the whole read surface, 163 listings, honest labeling, per-route CSP — is in good shape and the slice's *design* holds up under reading: the §4 rules (dissent needs no photo, first report counts as one confirmation, one door per claim, claim created only after validation, race settled by a unique constraint) are all implemented as documented.

But the product's stated moat is community validation, and **no community validation has ever been recorded in production.** Every write door returns `403` and has since launch. Fix F-1 and F-5 together — do not open the upload path onto a vulnerable image decoder — then F-2, then F-3 so this class of failure cannot ship green again.

This audit is a traceable gate over the boundaries listed, not a proof of correctness. It does not claim the slice is bug-free; several links remain `UNVERIFIED` by design and are itemized above.
