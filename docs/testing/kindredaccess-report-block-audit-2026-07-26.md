# KindredAccess — vertical-slice audit: report / block (safety)

> ## ⚠️ REVISION 2026-07-26 — K-2 RETRACTED, K-1 overstated, provenance was not "clean"
>
> A parallel Codex audit of the deployed build surfaced three errors in this document. All three
> were re-verified against source before writing this block.
>
> **K-2 is wrong and [kindredaccess#26](https://github.com/BeauAccessSolutions/kindredaccess/issues/26)
> is closed as invalid.** `RateLimitMiddleware` (`core/middleware.py:113`, installed at
> `settings_production.py:129`) already rate-limits `/report/`, `/block/` and `/unblock/` per user,
> and gives `/report/` a **dedicated 5-writes-per-minute bucket** whose comment names the exact
> urgent-lane threat model this audit claimed was unaddressed. It also counts writes only, so
> reloading the form doesn't throttle a legitimate reporter. **Root cause of the error:** grepped
> `core/views.py` for `ratelimit|throttle`, found nothing, concluded absence. Rate limiting is
> middleware here. One layer searched, absence reported.
>
> **K-1 survives but its failure scenario was overstated.** `DATA_UPLOAD_MAX_MEMORY_SIZE = 5242880`
> (`settings.py:249`) caps the request body at 5 MB, so the "10 MB description" is unreachable. The
> real gap is 2,000 chars advertised vs ~5 MB enforced. Corrected on
> [#25](https://github.com/BeauAccessSolutions/kindredaccess/issues/25).
>
> **Provenance was reported "✅ clean" and wasn't.** This audit checked that the checkout *contains*
> production and never checked what production *lacks*. Production `b5b6036` is behind `main` by
> four merged fixes — chat send-acknowledgement, iOS safe area, iOS title, and the staff-media audit
> log. The last is a safety control: privileged staff media access is unaudited **in production**
> even though the fix is merged. Deployment lag is a finding; this document treated it as a checkmark.
>
> Both method lessons are now written into the `vertical-slice-audit` skill (Phase 0 both-directions
> check; a discipline rule that cross-cutting controls live in middleware/decorators/settings/proxy
> and a single-layer grep cannot establish absence).
>
> **Codex's own KA P0s are not scored here** — production-wide HTTP 429, the missing Nginx
> `internal-media` location, and the unresolved NCMEC path. All three were independently confirmed
> from source and belong to their own slices; see the platform tracker.

**Slice:** user reporting and blocking · **Priority:** P0 surface · **Date:** 2026-07-26
**Method:** `vertical-slice-audit` — Phases 0–5 · **Verdict class:** `VERIFIED-CODE` (static)
**Mutation budget:** read-only. No writes, no migrations, no package installs.

**Provenance**
- audited at `origin/main`; production commit `b5b6036` (per `CLAUDE.md:16`) is an **ancestor** of
  `main`, so these findings apply to deployed code.
- production commit is a *documented* claim; verifying it against the droplet was out of scope.
- deploy: droplet, systemd `gunicorn`/`daphne` + nginx, `mysite.settings_production`.

---

## Chain

| # | Link | Verdict | Evidence |
|---|---|---|---|
| 1 | Entry point | PASS (code) / UNVERIFIED (render) | `core/urls.py:72-75` — block, unblock, blocked-users, report |
| 2 | Navigation | PASS (code) / UNVERIFIED (render) | server-side confirm interstitial `_render_confirm` with `cancel_url`; post-action redirect validated by `url_has_allowed_host_and_scheme` (`views.py:1636-1642`) |
| 3 | Initial state | PASS (code) | `ReportForm` renders reason select + description textarea (`forms.py:670-697`) |
| 4 | Input | **FAIL** | `maxlength='2000'` is a widget attribute only — see **K-1** |
| 5 | Validation | **PARTIAL** | `reason` constrained by `REASON_CHOICES`; `description` required but **unbounded server-side** — **K-1** |
| 6 | Draft | N-A | no draft for a safety form; appropriate |
| 7 | Request | PASS (code) | POST-only guards on block/unblock (`views.py:1591`, `1652`); Django CSRF middleware |
| 8 | Authz | PASS | `@login_required`; self-block and self-report both rejected (`views.py:1596`, `1694`). Any authenticated user may report any user — correct for this feature |
| 9 | Persistence | PASS | `Report.is_urgent` derived on save with `update_fields` handling (`models.py:1037-1050`); `Block` `unique_together` |
| 10 | Idempotency | PASS | block uses `get_or_create`; report dedups exact resubmits within 60s, **deliberately non-atomic and documented as failing safe** (`views.py:1710-1723`) |
| 11 | Success feedback | PASS (code) / UNVERIFIED (render) | `messages.success` / `report_success.html` |
| 12 | Failure path | PASS (code) | form errors re-rendered; `messages.error` |
| 13 | Read-back / enforcement | **PASS (strong)** | see below |
| 14 | Mutation | N-A this slice | resolve / `admin_notes` are admin-surface |
| 15 | Deletion | PASS | unblock deletes the `Block`; reports are deliberately not user-deletable (evidence) |
| 16 | Export | N-A | no user-facing export in this slice |
| 17 | Account deletion | **PASS (notably careful)** | `views.py:3051-3052` clears blocks both directions; `Report.reporter` is `SET_NULL` so an open case survives the reporter deleting their account |
| 18 | Leakage | **FAIL** | Sentry frame locals — filed separately, see below |
| 19 | Parity | N-A | web-only surface |
| 20 | Tests | PASS (exist; **not executed this pass**) | 35 tests in `core/tests/test_safety.py` + coverage in 4 other suites |

### Link 13 — block enforcement is real, and that is the headline

A block that stores a row but doesn't filter is the failure mode this slice exists to rule out. It
does not occur here. `Block` is consulted at ~20 call sites, in **both directions** (blocked-by as
well as blocked):

- browse / discover exclusion — `views.py:950-958`, `views.py:2185-2188`
- matching engine — `matching/services.py:563-575`; compatibility — `compatibility.py:171-183`
- chat entry — `views.py:852`, `902`, `1096`, `1318`, `3173`
- WebSocket consumer — `consumers.py:538`
- **media** — `media_proxy.py:156-161`, so a blocked user cannot reach photos by direct URL
- safety gates — `models.py:2431-2434`

Blocking also ends active matches and force-disconnects live sockets (`views.py:1615-1622`).

---

## Findings

### K-1 · P2 · `Report.description` has no server-side length limit
**Filed:** [kindredaccess#25](https://github.com/BeauAccessSolutions/kindredaccess/issues/25)
`core/forms.py:687` · `core/models.py:1017`

`maxlength='2000'` is set on the `Textarea` **widget**. The model field is a bare `TextField` with no
`max_length`, and the `ModelForm` inherits none, so nothing enforces the limit server-side.

**Failure scenario:** a direct POST (curl, or any non-browser client) with a 10 MB `description`
is accepted and stored, then rendered into the admin moderation queue page.

**Fix:** `max_length` on the model field (plus migration), or a `clean_description` on `ReportForm`.
The widget attribute stays as the client-side hint it already is.

### K-2 · P2 · No rate limiting on report or block — and the urgent lane is the flood target
**Filed:** [kindredaccess#26](https://github.com/BeauAccessSolutions/kindredaccess/issues/26)
`core/views.py:1587`, `1689`

Both views carry only `@login_required`. `core/login_throttle.py` exists but is applied to
authentication, not here. The 60-second dedup (`REPORT_DEDUP_WINDOW_SECONDS = 60`) matches on
`reason` **and** exact `description`, so changing a single character bypasses it — by design, since
differing text is treated as new signal.

**Failure scenario:** one account files hundreds of reports with slightly varied descriptions against
a target. Each creates a queue row and, where `ADMINS` is configured, an alert email.

**Why this is sharper than a generic flood:** `URGENT_REASONS = {'minor', 'csam', 'threat'}` sorts a
report to the **front** of the moderation queue and prefixes its email subject `[URGENT]`. An
attacker selecting `threat` floods the prioritized lane specifically. The model's own comment
anticipates the failure — *"everything marked urgent competes with everything else marked urgent, so
a broad set is the same as no prioritisation"* — and defends the **set** while leaving the **volume**
open.

**Fix:** per-user rate limit on report creation (a low ceiling per target per day is enough), and
consider a separate, tighter ceiling on urgent-reason reports. Rate limiting must **never** reject a
first report against a given target — the existing "always show success" reasoning applies with more
force here.

### Note (not a finding) · third-party exception text stored in the outbox
`core/notifications.py:205,268` — `_record_notification_failure(..., str(exc))` persists raw SMTP
exception text into `SafetyNotificationOutbox`. Same class as the Sentry issue, far lower severity:
own database, admin-scoped, and useful for dead-lettering. Worth capping or typing eventually.

### Filed separately · P1 · Sentry frame locals
`mysite/settings_production.py:388-405` — `include_local_variables` unset while
`LoggingIntegration(event_level='ERROR')` promotes every `logger.error`/`exception` to an event. In
this slice, `views.py:1583` (`_force_disconnect_chats`) and `notifications.py:268` both log at ERROR
with sensitive values in frame. Full write-up:
[KA `docs/audits/LOG_PII_SENTRY_AUDIT_2026-07-26.md`](../../../kindredaccess_files/docs/audits/LOG_PII_SENTRY_AUDIT_2026-07-26.md).

---

## What this pass did well, recorded deliberately

Audits that only enumerate defects mis-train the next reader. This slice's design choices are
better than the portfolio norm and should be copied:

- `Report.reporter` as `SET_NULL`, so a victim who reports and then deletes their account does not
  erase the open case.
- The dedup check documented as **non-atomic on purpose**, because a duplicate report is a safer
  failure than a suppressed one.
- A deduplicated resubmit still renders the success page — someone reporting a person they feel
  unsafe about is never told their report "failed."
- The admin alert email deliberately **excludes** the description because it may quote private
  messages or health details; admins read it in the panel instead.
- `photo_moderation.py:274` logs `type(exc).__name__` rather than `str(exc)`.

---

## Not covered

- Test suite (545 tests) — `pytest` not installed in `venv/`; running it requires a package install.
  CI runs it on push to `main`/`develop`. **No executed-test signal in this pass.**
- Dependency advisories — `pip-audit` not present; installing is a write.
- Every render-dependent link (1, 2, 3, 11) — needs a browser.
- Admin moderation surface (link 14), NCMEC escalation runbook, `SafetyGate` interaction.
- Live verification that production runs `b5b6036`.

## Verdict

**SHIP-WITH-KNOWN-GAPS.** No P0 or P1 in the slice itself; the P1 leakage finding is a
production-config defect filed against the app, not this feature. K-1 and K-2 are P2 abuse-resistance
gaps in an otherwise well-constructed safety path, and they compound — fix K-2 first, since the
urgent lane is the part an attacker would aim at.

This audit inspected and named every boundary in the chain. It does not establish that the slice is
bug-free, and no passing checklist could.
