# Benefits Navigator — Path A + Path B experience audit (2026-08-02)

**Method:** vertical-slice audit (provenance → intent inventory → implementation inventory →
whole-surface pass → slice walks → executable verification). This is a traceable gate, not a
proof of zero bugs.

## Provenance

| Surface | Identity |
|---|---|
| Audited source | `origin/main` @ **57f4c6f**, read-only worktree `.worktrees/audit-main` |
| Deployed app | DO App Platform `benefits-navigator-staging` (2119eba2…), deployment ACTIVE, cause "commit 57f4c6f pushed to main" — **identical to audited source** |
| Live domain | `ALLOWED_HOSTS` includes `vabenefitsnavigator.org` — the "staging" app **is** the production surface; no separate prod app exists in the DO account |
| Local checkout | `fix/sentry-frame-locals-gate` @ 8baeb71 — **11 merged commits behind main** (its one commit, the Sentry frame-locals gate, has no PR yet). Not audited; all verdicts below apply to 57f4c6f. |
| Deployed env (from live spec, names + non-secret values) | `DEBUG=False`, `STAGING=True`, `PILOT_MODE=True`, `PILOT_BILLING_DISABLED=True`, `USE_S3=False`, `VSO_MFA_ENFORCEMENT_START=2026-07-23`; **no** `ANTHROPIC_API_KEY`, **no** `EMAIL_*`, **no** `SENTRY_DSN`, **no** `SITE_URL`, **no** `FEATURE_*` (an unused `OPENAI_API_KEY` is set — nothing reads it) |

**Mutation budget:** read-only, plus (declared exceptions) the existing pytest suite against its
throwaway DB and one temporary verification test file (run, then deleted; worktree left clean).

---

## Gate verdict: **BLOCKED**

Two independent reasons:

1. **The live site's core value prop is down, silently.** The deployed spec has no
   `ANTHROPIC_API_KEY` (every AI call fails; the assistant silently serves canned demo output via
   `_has_live_key()`), no `EMAIL_*` (console backend — and `ACCOUNT_EMAIL_VERIFICATION="mandatory"`
   outside DEBUG means **new signups can never verify and never log in**), and no `SENTRY_DSN`
   (plus `core/alerting.py` reads settings names that don't exist) — so there is **no alert channel
   at all** to report any of this.
2. **Both paths have confirmed happy-path 500s.** The veteran dashboard's primary CTA
   (`/progress/`) 500s for every new user; six VSO endpoints 500 on their happy paths; and the
   veteran-invitation flow silently loses the case it promises to create. All reproduced by
   executed tests (see ledger).

---

## Findings (severity-ranked)

Verdicts: **CONFIRMED** = reproduced by execution or by the live deploy spec.
**VERIFIED-CODE** = statically confirmed by direct read at the cited line; render/runtime not exercised.

### P0 — live outage / data loss

**P0-1 · CONFIRMED · Deployed app has no `ANTHROPIC_API_KEY`.**
`agents/ai_gateway.py:341` reads `settings.ANTHROPIC_API_KEY` (default `""`,
`benefits_navigator/settings.py:585`). The live spec sets only an unused `OPENAI_API_KEY` (zero
readers in the codebase). Scenario: veteran uploads a decision letter → OCR succeeds → AI analysis
task fails 401 → document shows "Processing failed". Every agent tool errors. The streaming
assistant (`agents/views.py:881 _has_live_key`) silently falls back to **canned demo output** with
no user-visible indicator — live users get fake analysis text. Fix: set the key in the DO spec;
make `_has_live_key()` fallback visibly labeled; alert on gateway auth errors.

**P0-2 · CONFIRMED · No email delivery in production → signups cannot complete.**
`EMAIL_BACKEND` defaults to the console backend (`settings.py:561`); the live spec sets no
`EMAIL_*` var (positive-control-checked grep over the full saved spec). With
`ACCOUNT_EMAIL_VERIFICATION="mandatory"` outside DEBUG (`settings.py:503`), a new user's
verification mail goes to container stdout — they can never verify or log in. Also undeliverable:
password resets, VSO staff/veteran invitations, deadline/exam reminders, retention warnings.
Fix: configure SMTP/provider env vars; add a deploy-time check that fails when
`EMAIL_BACKEND` is console and `DEBUG=False`.

**P0-3 · CONFIRMED · Uploaded documents live on ephemeral disk.**
`USE_S3=False` in the live spec; media writes to the container filesystem on DO App Platform.
Every redeploy (11 in the last cycle) discards veterans' uploaded documents while their DB rows
survive — downloads then 404/500. Fix: finish the DO Spaces/S3 migration (`settings.py:608-630`
already supports it) before any further redeploys; audit existing rows for orphaned files.

**P0-4 · CONFIRMED · Zero alert channels; monitoring is decorative.**
No `SENTRY_DSN` in the live spec → `sentry_sdk.init` never runs (`settings.py:722-723`).
`core/alerting.py:116,151` reads `ALERT_EMAIL_RECIPIENTS` / `SLACK_ALERT_WEBHOOK` /
`ALERT_CHANNELS` via `getattr` — none exist in `settings.py`, and no `env()` binding exists, so
the runbook in `docs/INCIDENT_RESPONSE.md:346-360` tells operators to set env vars Django never
reads. Every monitoring check fires into the void. Fix: set `SENTRY_DSN`; add real settings
bindings for the alert channels; add a test that the channel names in INCIDENT_RESPONSE.md exist
in settings.

**P0-5 · REMEDIATED 2026-08-02 ([benefits_navigator PR #102](https://github.com/BeauAccessSolutions/benefits_navigator/pull/102)) — was CONFIRMED (executed: `NoReverseMatch`) · `/progress/` 500s — and takes the whole AI
surface with it.** *Both URL names corrected; first-ever render tests added
(`tests/test_claim_progress.py`), which also surfaced and fixed two further latent crashes in the
same view (`type(request.user).objects` on a `SimpleLazyObject`; a nonexistent `|multiply`
template filter). Nav links to `/agents/` (P1-1) remain open.* `core/views.py:290` uses url name `claims:upload` (real name:
`claims:document_upload`); `core/views.py:312` uses `agents:rating_analyzer` (real name:
`claims:rating_analyzer`). The first fires for every user with 0 documents — i.e. every new user
clicking the dashboard's most prominent banner (`templates/core/dashboard.html:72`). Because the
only links to `/agents/*` anywhere in the UI are on this page
(`templates/core/claim_progress.html:141,186,191,196,201`), the Decision Analyzer, Evidence Gap
Analyzer, Statement Generator, Condition Discovery, and Assistant are unreachable for new users.
Zero test coverage references `claim_progress`. Fix: correct both names; add a render test; add
nav links to `/agents/` (see P1-1).

**P0-6 · REMEDIATED 2026-08-02 ([benefits_navigator PR #102](https://github.com/BeauAccessSolutions/benefits_navigator/pull/102)) — was CONFIRMED (8/8 executed tests) · Six VSO happy-path 500s + silent case loss.**
*All six fixed: evidence packet reads real model fields; both HTMX partials created (and
`case_detail.html` now includes them); Start Appeal uses `case.case_conditions`;
`VeteranCase.get_absolute_url()` added; `?order_by=` allowlisted; pending-case payload persisted
on `OrganizationInvitation.case_payload` (encrypted, cleared on consumption) instead of the
staffer's session. The masking test now seeds the invitation, and positive-path suites cover every
endpoint (`TestVSOEndpointHappyPaths`, `TestCaseListOrdering`, `TestInvitationCasePayloadFlow`).
Original finding kept below for the record:*
- `vso/views.py:2268` — `SharedDocument.REVIEW_STATUS_CHOICES` doesn't exist (model:
  `SHARE_STATUS_CHOICES`, `vso/models.py:301`): **every** GET of the evidence packet builder 500s,
  even with an empty case. Also `:2231-2236` reference `sd.document.title` / `.uploaded_at` /
  `sd.vso_notes` / `sd.review_status` — none exist on those models.
- `vso/views.py:1087,1106` — HTMX partials render `vso/partials/case_notes.html` /
  `case_documents.html`, which don't exist → `TemplateDoesNotExist`.
- `vso/views.py:1484-1485` — "Start Appeal" calls `case.conditions.all()` on an
  `EncryptedJSONField` list → `AttributeError` on every attempt from a denied case.
- `vso/views.py:1175` — duplicate-invite warning calls `VeteranCase.get_absolute_url()`, which
  doesn't exist → inviting a veteran with an open case 500s.
- `vso/views.py:389-390` — unvalidated `?order_by=` → `FieldError` 500 (and an ordering oracle,
  e.g. `?order_by=veteran__password`).
- `vso/views.py:1186` vs `:1382` — invite case details are stored in the **inviting staffer's**
  session and read from the **accepting veteran's** session: the promised case + milestone note
  are never created in production (test seeds mask this: `vso/tests.py:749-757`). The invite page
  explicitly promises "Upon accepting, a case is created" (`templates/vso/invite_veteran.html:93`).
  Fix: persist pending-case payload on `OrganizationInvitation` (a JSON field), not in a session.
- Root cause for the 500 cluster: `vso/tests.py:1181-1192` only asserts *negative* (404/302)
  paths for these endpoints — no positive-path request exists in CI. Add happy-path tests.

**P0-7 · VERIFIED-CODE · Bulk-close corrupts reporting.** `vso/views.py:591,642` bulk actions use
`.update()`, so bulk-closed cases never get `closed_at`/`closed_by` or the milestone note.
`reports` (`vso/views.py:1544`) and the dashboard's monthly metrics filter on
`closed_at__isnull=False` — bulk-closed cases vanish from win-rate and closure stats. Fix: loop
with `save()` or set the fields inside `.update()`.

### P1 — broken promises, unreachable features, monetization gaps

**P1-1 · CONFIRMED (grep + template read) · Navigation hides most of the product.** No nav,
dashboard, footer, or home link to: `/agents/` (all AI tools + assistant + history),
`/accounts/upgrade/`, `/claims/rating-analyzer/`, `/claims/decode/` (nav-absent; home card only),
`/exam-prep/rating-calculator/` (home hero only), secondary-conditions hub, evidence checklists.
The nav's "Claims Assistant" (`templates/partials/nav_links.html:13`) sends anonymous visitors to
a `@login_required` view — the primary nav item lands first-time visitors on a login form.
Fix: one pass over `nav_links.html` + dashboard quick actions; gate items on auth state.

**P1-2 · CONFIRMED (dead-code grep) · Free-tier AI quota is never enforced.**
`accounts/decorators.py` (all six decorators) has zero importers. `can_use_ai_analysis` /
`record_ai_analysis` (`accounts/models.py:921,954`) are called only by that dead module. Free
users get unlimited decision analyses / evidence gaps / statements (20/hr ratelimit only), the
upgrade page's "5 AI analyses/month" counter never moves, and any new premium view will ship
ungated because the "obvious" decorators do nothing. Related: the Rating Analyzer reuses the
denial-decoder form so it *charges the wrong quota* and never records its own
(`claims/views.py:721`, `claims/forms.py:293`).

**P1-3 · VERIFIED-CODE · Billing flow is hard to enter, easy to mis-trigger, silent on failure.**
Upgrade page reachable only from a quota-limit warning (`templates/claims/document_list.html:40`);
subscribers can't reach the Stripe portal without re-visiting that page. `create_checkout_session`
(`accounts/views.py:641`) accepts GET — a prefetching crawler can create Stripe
customers/sessions. Success page (`accounts/views.py:704`) declares "subscription active" without
checking state. Failed payments: `# TODO: Send email notification` (`accounts/views.py:915`).
No Stripe webhook handler tests exist.

**P1-4 · VERIFIED-CODE (render UNVERIFIED) · CSP `style-src 'self'` breaks progress bars
app-wide.** `settings.py:469` + django-csp 3.8 blocks every inline `style="width: X%"`:
dashboard (`core/dashboard.html:267,337`), claim progress, evidence-gap result, all checklist
pages, appeal detail/list — bars render at 0%. Also unhides a hidden form
(`account/email_change.html:101`). Meanwhile `CSP_SCRIPT_SRC` still allows `'unsafe-inline'` and
`https://unpkg.com` (no SRI) while the comment at `settings.py:492` claims the opposite.
Fix: move widths to a `<style nonce>` or utility classes; pin+self-host HTMX; fix the comment.

**P1-5 · VERIFIED-CODE · VSOs cannot open the documents veterans share with them.**
`shared_document_review` shows metadata only; `document_download`/`document_view_inline`
(`claims/views.py:406,485`) filter `user=request.user`, hard-blocking VSO staff. The template
acknowledges it (`templates/vso/shared_document_review.html:217`). The core B2B loop —
"veteran shares document → VSO reviews" — works only for metadata. Fix: signed-URL grant scoped
to an active `SharedDocument` + audit log.

**P1-6 · VERIFIED-CODE · The "shared analyses" leg of Path B doesn't exist outside Django admin.**
`SharedAnalysis` has models/signals/admin but no veteran-side create route and no VSO-side render
(`vso/views.py:726` passes it; `grep shared_analys templates/` = 0). The case-detail empty state
advertises the nonexistent workflow. Decide: build both ends, or remove the promise.

**P1-7 · VERIFIED-CODE · Case data that reports depend on is admin-only.** Case detail has no
control to set assignee, priority, `appeal_deadline`, `next_action_date`, exam dates, ratings, or
conditions — yet dashboards/reports key on them. Deadline fields exist but no VSO UI writes them
and nothing sends case deadline reminders. Win-rate months are also miscomputed
(`vso/views.py:1562-1566`: `days=30*i` bucketing skips/repeats calendar months).

**P1-8 · VERIFIED-CODE · Veteran invitations consume org seats.** `OrganizationInvitation.accept`
counts veterans against `Organization.seats` (default 5) — a 5-seat org with 3 staff can onboard
2 veterans, then every acceptance fails ("seat limit") and bounces the veteran home. Decide:
veterans shouldn't consume staff seats (likely), or seats must scale.

**P1-9 · VERIFIED-CODE · Org-selection dead ends.** Multi-org staff are pinned to
`session["selected_org_slug"]`; the promised switcher ("You can switch organizations at any time
from the dashboard", `templates/vso/select_organization.html:55`) doesn't exist anywhere. The
case-list archived toggle always links `?archived=1` (`templates/vso/case_list.html:98`) — no way
back except Clear. `vso:reports` and `vso:org_admin` are linked from no VSO template — direct URL
only.

**P1-10 · VERIFIED-CODE · Staff invites claim an email was sent; none is.**
`vso/views.py:2182` (`# TODO: Send email notification`) yet the success message says "Invitation
sent to {email}". The only accept URL must be copied from the DB. Also, veteran invite links are
built from `SITE_URL` defaulting to `http://localhost:8000` (`vso/views.py:1219`,
`settings.py:863`) — and the live spec sets no `SITE_URL`, so even with email fixed the links
would point at localhost. (`accounts` invites use `request.build_absolute_uri` and are fine — the
two flows disagree.)

**P1-11 · CONFIRMED (live spec) + VERIFIED-CODE · Feature-flag system is mostly dead.**
`org_billing`, `org_admin_dashboard`, `audit_export`, `caseworker_assignment`, `sso_saml`, `mfa`
gate nothing; no `/vso/` view checks any flag, so with all `FEATURE_*` unset in production the
whole VSO surface (incl. org admin) is live while `/accounts/organizations/*` (org creation) 302s
home — orgs can only be created via Django admin. The registered `features` context processor is
referenced by zero templates. Decide each flag: enforce it or delete it.

**P1-12 · VERIFIED-CODE · `DEBUG` defaults to `True`** (`settings.py:13`). One dropped env var
flips off secure cookies, rate limiting, CORS restrictions, and mandatory email verification —
and the `ALLOWED_HOSTS` guard is itself DEBUG-gated (`settings.py:87`). Default it to `False`.

**P1-13 · VERIFIED-CODE · Data retention never runs outside pilot mode.**
`enforce_data_retention` (`core/tasks.py:18`) is absent from `CELERY_BEAT_SCHEDULE`
(`settings.py:342-391`); only the pilot task is scheduled. Currently masked by `PILOT_MODE=True`;
the day pilot mode turns off, the 30-day purge promise silently stops being true.

### P2 — polish, correctness nits, hygiene

- **Raw exception text shown to veterans:** `agents/views.py:243,415,568` and
  `Document.error_message` rendered verbatim (`templates/claims/document_detail.html:187`) —
  gateway/stack strings surface to users (and into a PII-adjacent UI).
- **Documents marked failed before retries run:** `claims/tasks.py:187-208` `mark_failed` then
  `self.retry(...)` — user sees terminal failure, polling stops (`HX-Refresh` at
  `claims/views.py:161`), a later success is never surfaced. Same in both other pipelines.
- **`.delay()` unguarded at upload:** broker down → quota already burned + 500
  (`claims/views.py:96`); no poll timeout for tasks stuck in `processing`.
- **`hx-trigger=""`** on denial-decoder and rating-analyzer result pages (missing `{% else %}load`)
  → completed status block never populates on first paint (render UNVERIFIED).
- **MFA middleware messages show literal HTML:** `vso/middleware.py:135,146` use
  `extra_tags="safe"` but `base.html:138` auto-escapes — users see raw `<a>` markup.
- **Milestones can't be deleted** (view+template exist, no link: `core/views.py:515`);
  secondary-conditions live-search endpoint orphaned and its form has no submit button
  (`templates/examprep/secondary_conditions_hub.html:60-67`).
- **Premium copy overstates gating:** checklists and PDF export advertised as premium are free
  (`accounts/views.py:632-636` vs `examprep/views.py:155,1104`); PDF export errors return raw
  plaintext 500s (`examprep/views.py:1173-1176`).
- **Condition Discovery is a static rules engine presented as an AI agent**
  (`agents/views.py:736-838`).
- **Case-list "conditions" count disagrees with CSV export** (legacy JSON field vs
  `case_conditions`); dashboard status panel prints the whole dict per row (confirmed by test).
- **Deactivate-member double-POST drives `seats_used` negative-ward** (`vso/views.py:2093-2102`
  fetches without `is_active=True`).
- **Logging to ephemeral `logs/django.log`** in every process (`settings.py:664-717`);
  admin lacks OTP by default (`ADMIN_OTP_REQUIRED=False`, acknowledged in TODO).
- **Test hygiene:** `tests/e2e/*` files don't carry the `e2e` marker, so `-m "not e2e"`
  deselects nothing; VSO has the lowest test-per-view ratio (59 tests / 38 views); no Stripe
  webhook tests; no `core/alerting.py` channel tests (why P0-4 survived).
- **Dead code inventory:** `accounts/decorators.py` (all), `vso/permissions.py` mixins/helpers,
  `GapCheckerService.update_condition_gaps` (zero callers; its document-type vocabulary doesn't
  match `Document.DOCUMENT_TYPE_CHOICES` anyway), `user_usage`/`tier_limits` context processors
  (cost a query per request, used by zero templates).

---

## NOT-BUILT (documented intent with no implementation — gaps, not bugs)

| Promise | Source | Note |
|---|---|---|
| Org-level billing (seats × Stripe) | ROADMAP Phase 3, `FEATURE_ORG_BILLING` | Only seat counters exist |
| Audit log export | ROADMAP Phase 4, `FEATURE_AUDIT_EXPORT` | Flag + nothing |
| Evidence packet builder (real) | vso routes | Stub: "Quick Actions" is a back link; `assigned_conditions` hardcoded `[]` — and the page 500s (P0-6) |
| Nexus letter generator | TODO.md:326 | No route/view |
| Welcome/engagement email sequences | ROADMAP, PATH_A.md:68 | No tasks |
| PWA (manifest, service worker, push) | TODO.md:335-338 | Capacitor iOS shell only |
| Premium model tier | README.md:248 | `PREMIUM_GPT4_ACCESS=False`, no consumer |
| Per-user token-spend cap | TODO.md:132 | Tokens recorded, never checked |
| Forum / success stories / VSO directory / buddy statements | TODO.md:329-332 | Fixture strings only |
| SAML SSO | `FEATURE_SSO_SAML` | OIDC/Keycloak exists on a separate switch |
| Security runbook, API contract docs, Celery task catalog | TODO.md:308-310 | Docs absent |
| Redis caching for glossary/guides | TODO.md:283 | Not implemented |

Stale TODO entries found (already built): streaming chat assistant, Stripe subscription flow,
admin stats dashboard, `/health/?full=1` gating.

---

## Feature matrix (condensed)

| Feature | Bucket | State at 57f4c6f |
|---|---|---|
| Signup/login (email, allauth) | Implemented | Works in code; **live signups blocked by P0-2** |
| Onboarding | Not built | No wizard; AI-consent surprise at first upload |
| Dashboard / Journey | Implemented | OK; primary CTA 500s (P0-5) |
| Document upload → OCR → AI | Implemented | Pipeline sound in code; live AI down (P0-1); media ephemeral (P0-3) |
| Denial decoder / Rating analyzer | Implemented | Rating analyzer unreachable by nav; wrong quota (P1-2) |
| AI agent tools ×4 + assistant | Implemented | Unreachable (P0-5/P1-1); unmetered (P1-2); assistant demo-fallback silent |
| Appeals (tree, tracking, docs, notes) | Implemented | Healthiest Path A area |
| Exam prep, glossary, calculators (rating/SMC/TDIU), secondary conditions | Implemented | Solid; nav gaps; CSP bars |
| Saved/shared calculations, PDF export | Implemented | PDF export unauthenticated (advertised as premium) |
| Freemium enforcement | Partial | Docs/decoder enforced; AI quota dead (P1-2) |
| Stripe individual billing | Implemented | Reachability + GET checkout + silent failures (P1-3); pilot-disabled live |
| Privacy hub, export, deletion | Implemented | Export honest+capped; deletion 30-day grace; retention gap P1-13 |
| VSO dashboard/case list/create/notes | Implemented | Works; bulk-close corrupts metrics (P0-7) |
| VSO case detail | Partial | Read-mostly; key fields admin-only (P1-7) |
| Shared documents review | Partial | Metadata only — no file access (P1-5) |
| Shared analyses | Not usable | Admin-only both ends (P1-6) |
| Veteran invitations | Broken | Case never created (P0-6); localhost links (P1-10); seats (P1-8) |
| Staff invitations / org admin | Partial | No email (P1-10); org creation admin-only (P1-11) |
| Reports / win rate | Implemented | Month-bucket bug; depends on admin-only data |
| Evidence packet builder | Stub | 500s on GET (P0-6) |
| MFA for VSO staff | Implemented | Enforcement live (start 2026-07-23); message-HTML nit |
| Mobile | Partial | Capacitor iOS shell; no PWA; Stripe likely exits shell (device-UNVERIFIED) |
| API (JWT) | Minimal | Auth-only; no data endpoints |

---

## Slice chains (key walks, condensed)

```
Slice: Veteran doc upload → analysis → read-back        P0 path
  1  Entry      templates/core/dashboard.html quick action     VERIFIED-CODE
  5  Validation claims/forms.py:118-126 (type/size/pages/quota) PASS
  7  Request    claims/views.py:96 .delay() unguarded           FAIL (P2)
  9  Persist    Document + EncryptedJSONField ai_summary        PASS (code)
  11 Feedback   5s HTMX poll + HX-Refresh                       PASS (code) / render UNVERIFIED
  12 Failure    mark_failed-before-retry; raw error text        FAIL (P2 ×2)
  13 Read-back  document_detail                                 PASS
  16 Export     accounts data export incl. docs                 PASS (capped, honest)
  18 Leakage    error_message may carry provider strings        FAIL (P2)
  —  Live       ANTHROPIC key absent → whole slice down         FAIL (P0-1)

Slice: New veteran → dashboard → claim progress → AI tools
  1  Entry      dashboard.html:72 "View Progress"               CONFIRMED FAIL (P0-5)
  2  Nav        agents/* linked only from the failing page      CONFIRMED FAIL (P1-1)

Slice: VSO invites veteran → case created
  1  Entry      vso/invite_veteran                              PASS
  7  Request    email undeliverable (P0-2) + localhost URL      FAIL
  9  Persist    invitation row                                  PASS
  10 Idempotency duplicate-invite guard 500s                    CONFIRMED FAIL
  13 Read-back  acceptance: case never created                  CONFIRMED FAIL (P0-6)
  14 Mutation   seat consumed by veteran                        FAIL (P1-8)

Slice: VSO case work (detail → notes → shared docs → appeal)
  13 Read-back  case detail renders                             PASS
  4  Input      key case fields have no UI                      FAIL (P1-7)
  13 Shared docs metadata only, no file view                    FAIL (P1-5)
  14 Start appeal 500s                                          CONFIRMED FAIL
  15 Partials   both HTMX endpoints crash                       CONFIRMED FAIL
```

---

## Verification ledger

- Full suite at 57f4c6f (worktree, `--ignore=tests/e2e`): **1414 passed, 0 failed** (54s) (Python 3.12.13,
  Django 6.0.6 in `.auditvenv` — note: requirements pin 5.1.x; env is newer than prod).
- Earlier full run including unmarked e2e: 1414 passed / 112 e2e setup-errors (sandbox: no
  browser/DB fixture; matches known limitation).
- 8/8 targeted verification tests (written, executed, deleted) reproduced the six VSO 500s, the
  invitation case-loss, and the dashboard dict-render.
- `NoReverseMatch` proven for `claims:upload` and `agents:rating_analyzer` via `reverse()`.
- Ruff: clean (exit 0).
- Live deploy spec pulled via doctl: deployment ACTIVE at 57f4c6f; env-var absence claims made
  with case-insensitive grep over the full saved spec with a positive control (`OPENAI` found).

**Not covered:** dependency vulnerability audit (pip-audit unavailable in sandbox — timed out
resolving); any browser-rendered verification (CSP effects, HTMX triggers, focus management,
aria-live) — listed items marked render-UNVERIFIED; production database contents (guidance/
glossary/forms fixtures loaded? orphaned media?); Stripe live config; Keycloak OIDC round-trip;
iOS shell behavior on device; `git log` secrets-history scrub status.

---

## Recommended order of work

1. **Same-day (config only, no deploy):** set `ANTHROPIC_API_KEY`, `SENTRY_DSN`, `EMAIL_*`,
   `SITE_URL` in the DO spec. This alone restores AI, signups, invitations, and observability.
2. **This week (small PRs):** fix the two `/progress/` url names (+test); fix the six VSO 500s
   (+happy-path tests); move invite case-payload onto the invitation row; `USE_S3=True` migration;
   bulk-close `closed_at`; default `DEBUG=False`.
3. **Next:** nav pass (agents, upgrade/portal, rating analyzer, calculators); enforce or delete
   the AI quota + decorators; CSP style fix; VSO shared-document file access; org switcher.
4. **Product decisions:** shared-analyses leg (build or cut), evidence packet builder (build or
   hide), veteran seats, feature-flag cleanup, org self-serve creation, NOT-BUILT list triage.
