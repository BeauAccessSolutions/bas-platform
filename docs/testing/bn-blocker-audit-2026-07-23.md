# Benefits Navigator — first pass against the blocker suite

Date: 2026-07-23 · Matrix: [`multi-role-test-matrix.yaml`](multi-role-test-matrix.yaml) v1
Target: `repos/benefits-navigator` @ `25b1a40`

**Method: static read of the code, not a live run.** Every finding below is anchored to a
file and line. Tests that need a running instance, a device, or a screen reader
(`SESS-01`, `SESS-03`, all of `MOB`, all of `A11Y`, `TEN-02`) were **not executed** and are
listed as not-run rather than passed — the distinction matters, because "not run" is how
matrices quietly turn green.

Scope: the `AUTHZ`, `SESS`, `TEN`, `AUDIT`, and `REV` blockers, which is where a static
read has purchase.

---

## Summary

| Test | Gate | Result |
|---|---|---|
| `AUTHZ-01` BOLA by object ID | blocker | **PASS** |
| `AUTHZ-02` BOLA via filters/mass assignment | blocker | **PASS** (one caveat, F6) |
| `AUTHZ-12` uniform cross-scope denial | required | **PASS** |
| `AUTHZ-11` derived artifacts scoped | blocker | **PASS** — unusually strong |
| `SESS-06` revocation takes effect next request | blocker | **PASS** |
| `AUTHZ-05` case-manager mode excludes non-caseload | blocker | **FAIL — F1** |
| `AUDIT-02` logs append-only | blocker | **FAIL — F2** |
| `REV-01` double-submit creates one record | blocker | **FAIL — F5** |
| `AUDIT-01` views logged with role/mode | blocker | **PARTIAL — F3** |
| `AUDIT-03` elevated events carry actor/reason/scope/time | blocker | **PARTIAL — F4** |
| `TEN-05` errors don't leak | required | **MINOR — F6** |

**Disposition (2026-07-23).** F2 and F4 are **fixed** on branch `fix/audit-integrity`
(`dc596ef`, not yet pushed), with `tests/test_audit_integrity.py` covering both — both tests
fail against the previous code. F1, F3, and F5 are filed as
[#59](https://github.com/BeauAccessSolutions/benefits_navigator/issues/59),
[#61](https://github.com/BeauAccessSolutions/benefits_navigator/issues/61), and
[#60](https://github.com/BeauAccessSolutions/benefits_navigator/issues/60). F6 is not filed.

Four passes are worth naming, because the matrix is only useful if it can say what is
already right. `get_scoped_case_or_404` ([vso/permissions.py:423](../../repos/benefits-navigator/vso/permissions.py)) is the single sanctioned
case-by-pk lookup and is used at every one of the ~12 case-detail call sites; it raises
`Http404`, not `PermissionDenied`, so a probe for a colleague's case ID is
indistinguishable from a nonexistent one — that is `AUTHZ-01` and `AUTHZ-12` passing
together, which is rarer than it sounds. Organization selection re-validates the slug
against live memberships on every request ([vso/views.py:76](../../repos/benefits-navigator/vso/views.py)), so there is no org-switching
IDOR and no cached-permission staleness — `SESS-06` passes by construction. And bulk export
is admin-only, rate-limited to 5/h, ops-alerted, and strips veteran emails from the output
([vso/views.py:445](../../repos/benefits-navigator/vso/views.py)) — `AUTHZ-11` doesn't just pass, it exceeds the test.

---

## F1 — `AUTHZ-05` blocker: least-privilege caseload scoping is off by default

[`accounts/models.py:467`](../../repos/benefits-navigator/accounts/models.py)

```python
restrict_caseworker_visibility = models.BooleanField(
    "Restrict caseworker visibility",
    default=False,
    ...
)
```

`scope_cases_for_member` returns the queryset **unmodified** when the flag is off
([vso/permissions.py:416](../../repos/benefits-navigator/vso/permissions.py)). So out of the box, every caseworker in an
organization sees every case in that organization — in the list, in search, in reports, and
by direct pk.

This is not a missing mechanism. The mechanism is well-built and correctly threaded through
every read path I could find, including the easy-to-miss one where `case_list` rebuilds the
queryset from scratch for archived cases and re-applies scoping ([vso/views.py:363](../../repos/benefits-navigator/vso/views.py)) — someone
was paying attention there. The mechanism is simply **dark by default**, which under
minimum-necessary (45 CFR 164.502(b), 164.514(d)) is the posture the rule is aimed at.

The fix is one line; the migration for existing organizations is the product call, since
flipping it changes what current users can see. Note that even when enabled, scoping admits
`assigned_to__isnull=True` — unassigned cases stay visible to everyone, which is defensible
for intake triage but should be a written decision rather than an artifact.

## F2 — `AUDIT-02` blocker: a superuser can delete audit history

[`core/admin.py`, `AuditLogAdmin`](../../repos/benefits-navigator/core/admin.py)

```python
def has_add_permission(self, request):
    return False

def has_change_permission(self, request, obj=None):
    return False

def has_delete_permission(self, request, obj=None):
    return request.user.is_superuser
```

Add and change are correctly blocked. Delete is not. The matrix's fail condition for
`AUDIT-02` is precisely "an application admin can edit **or delete** audit history" — and
this is the deletion half, reachable through the Django admin UI with no second control.
There is also no storage-layer append-only enforcement and no hashing, so the application
check is the only thing standing between an admin and the record of their own access.

Two-line fix (`return False`), plus the storage-layer question as a separate, larger piece
of work.

## F3 — `AUDIT-01` partial: no acting role on any audit entry

`AuditLog` ([core/models.py:351](../../repos/benefits-navigator/core/models.py)) records user, action, IP, user agent, path, method,
resource type/id, success, and a `details` JSON blob. It has no `role` or `mode` field, and
no call site puts one in `details` — `case_detail` records `{"veteran_id": ..., "organization_id": ...}`
([vso/views.py:682](../../repos/benefits-navigator/vso/views.py)) and stops there.

The headline half of `AUDIT-01` passes: `vso_case_view` exists and fires on read, so BN logs
**views, not just edits**, which is the part most systems get wrong. What is missing is the
dual-hat half. Given a user who holds both `admin` and `caseworker` memberships, no entry
can answer which hat they were wearing — the exact question a minimum-necessary review
asks, and the reason the matrix requires the mode in the entry rather than inferable from
context.

Adding `organization` and `role` as real columns (not `details` keys) also makes the
`AUDIT-04` anomaly queries — access outside a worker's caseload, after-hours spikes —
writable as indexed queries instead of JSON scans.

## F4 — `AUDIT-01`/`AUDIT-03` partial: three call sites record the load balancer's IP

`AuditLog.log()` resolves the client IP through `_get_client_ip`, which correctly prefers
`HTTP_X_FORWARDED_FOR` ([core/models.py:524](../../repos/benefits-navigator/core/models.py)). But three call sites bypass the classmethod and
build the row directly:

- [`vso/views.py:514`](../../repos/benefits-navigator/vso/views.py) — bulk case CSV export
- [`vso/views.py:1673`](../../repos/benefits-navigator/vso/views.py) — report CSV export
- [`vso/views.py:1750`](../../repos/benefits-navigator/vso/views.py) — report PDF export

All three pass `ip_address=request.META.get("REMOTE_ADDR")`. Behind DigitalOcean App
Platform's load balancer that is the proxy, not the client — so the IP column is a constant
for exactly the three events where an incident responder most needs it. These are the bulk
data pulls.

Fix is to route them through `AuditLog.log()`. The divergence probably exists because the
export sites want to set `details` before saving; `log()` already accepts `details`.

## F5 — `REV-01` blocker: no idempotency mechanism anywhere

A repo-wide search for idempotency handling returns two comments in `agents/tasks.py` noting
that certain tasks are *not* idempotent, and nothing else. There is no key generation, no
key storage, no dedup on any state-changing POST.

Affected, at minimum: `case_create` ([vso/views.py:895](../../repos/benefits-navigator/vso/views.py)), `invite_veteran` (1120),
`add_case_note` (835), `start_appeal_from_case` (1445). A double-tapped submit or a retry
after a mobile network blip creates a duplicate case, a duplicate invitation to a veteran,
or a duplicate note. Duplicate invitations are the worst of these: they are outbound email
to a third party.

This is the largest piece of work in the list — a client-generated UUID per logical action,
a server-side key store with a pruning window, and replay returning the original response.
It is also the finding most likely to be already happening in production without anyone
attributing the duplicates to a cause.

## F6 — `TEN-05` minor: unvalidated `order_by` from the query string

[`vso/views.py:389`](../../repos/benefits-navigator/vso/views.py)

```python
order_by = request.GET.get("order_by", "-created_at")
cases = cases.order_by(order_by)
```

User input reaches `.order_by()` with no allowlist. Two consequences, neither severe given
that F1's row-level scoping bounds the result set: an invalid field raises `FieldError` →
500 (which in a debug-enabled environment enumerates valid field names), and relation
traversal (`veteran__…`) turns sort order into a weak inference channel over fields the user
cannot read directly, including the encrypted ones. Fix is an allowlist of sortable columns.

---

## Not run

Listed so the gaps stay visible: `SESS-01` (draft survival — the single highest-value test
in the matrix and untestable statically), `SESS-02`, `SESS-03`, `SESS-04`, `TEN-02` (cache
cross-serve), `TEN-07` (complementary suppression — BN's `reports` view aggregates by
status/priority/caseworker and is where this would bite), all of `MOB` (BN has a `mobile/`
directory worth scoping), all of `A11Y`, `AUDIT-04`/`05` (alerting and review cadence are
process questions), and all of `DELEG` — BN's veteran-invitation flow is the authorized-rep
surface and deserves its own pass once P3 and P5 are settled.

```bash
./scripts/testmatrix.py issues --repo BeauAccessSolutions/benefits_navigator --gate blocker --execute
```

Suggested order: F2 and F4 are near-trivial and both touch audit integrity. F1 is one line
plus a product decision. F6 is small. F5 is real work and should be its own PR.
