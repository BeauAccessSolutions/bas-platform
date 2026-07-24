# Chronic Illness Tracker — pass against the blocker suite

Date: 2026-07-23 · Matrix: [`multi-role-test-matrix.yaml`](multi-role-test-matrix.yaml) v1
Target: `repos/chronic-illness-tracker` @ `5a49975` (`main`)

Static read, not a live run. Tests needing a running instance, a device, or a screen reader
were **not executed** and are listed as not-run rather than passed.

CIT is the portfolio's odd one out for this matrix: **single-user personal PHI with no admin
surface**. A repo-wide search for an admin/staff role finds nothing, so the dual-hat half of
`AUTHZ` and the acting-role half of `AUDIT-01` are genuinely N/A here rather than unassessed —
there is no second party who can read a user's data. That removes most of what the matrix was
built to catch, and concentrates the risk in one place: **data loss**.

---

## Summary

| Test | Gate | Result |
|---|---|---|
| `AUTHZ-01`/`02` BOLA | blocker | **PASS** |
| `AUTHZ-12` uniform denial | required | **PASS** |
| `AUTHZ-11` derived artifacts scoped | blocker | **PASS** — unusually strong |
| `SESS-06`/`08` revocation, logout | blocker | **PASS** |
| `NAV-01` unsaved-changes guard | required | **FAIL — C1** |
| `REV-01` double-submit → one record | blocker | **FAIL — C2** |
| `SESS-05` idle/absolute timeout | required | **PARTIAL — C3** |
| `CONC-01` concurrent edit | blocker | **FAIL (low impact) — C4** |
| `AUDIT-*` | blocker | **N/A / weak — C5** |
| `AUTHZ-05`…`09` dual-hat, impersonation, break-glass | blocker | **N/A** — no admin surface |
| `DELEG-*` | blocker | **N/A** — no proxy model |

Passes worth naming. Every by-id route scopes in the query itself —
`prisma.regimenItem.findFirst({ where: { id, userId } })` ([src/app/api/regimen/[id]/route.ts](../../repos/chronic-illness-tracker/src/app/api/regimen/[id]/route.ts)) —
and returns a uniform `not_found`, so `AUTHZ-01` and `AUTHZ-12` pass together. Every
`findUnique` in the API is keyed on `userId` or on an email inside an auth flow; none takes a
client-supplied object id. Sessions are validated against the database on every request with
the token stored hashed and expired rows deleted on read, which makes `SESS-06` and `SESS-08`
pass by construction, and a `logout-others` endpoint exists for `SESS-09`.

`AUTHZ-11` is the standout: the export download requires **both** the caller's own session and
a `?token=` matching a hashed signed token, compared in constant time
([src/app/api/export/[id]/route.ts](../../repos/chronic-illness-tracker/src/app/api/export/[id]/route.ts), ADR-008). The comment is explicit that the token is an
additional secret rather than a replacement for the session. That exceeds the test.

---

## C1 — `NAV-01`: nothing protects a partially-filled entry

A repo-wide search for `beforeunload`, a router blocker, `unsaved`, `autosave`, or `draft`
returns **nothing**. There is no unsaved-changes guard, no autosave, and no draft persistence
anywhere in the app.

In a Next.js App Router application this is the matrix's `NAV-01` failing in its default form:
client-side navigation does not fire `beforeunload`, so a half-completed symptom entry is
discarded silently by an in-app link, a Back gesture, or a tab switch that ends in a reload.

The severity is app-specific and higher than the gate suggests. CIT's users are people managing
chronic illness — fatigue, brain fog, pain — logging symptoms *while symptomatic*. The matrix
puts it plainly under cognitive accessibility: time pressure and memory burden across steps are
especially harmful, and **undo is an accommodation**. An entry that vanishes because someone
tapped the wrong thing mid-flare is precisely the harm the app exists to reduce.

This is also the cheapest of the findings to fix: autosave to local storage keyed by
form + date, restore on mount. It does not need a server round trip to be worth having.

## C2 — `REV-01`: no idempotency on entry creation

No idempotency mechanism exists in the repo. Entry routes call `prisma.symptomEntry.create(...)`
directly ([src/app/api/entries/symptoms/route.ts:76](../../repos/chronic-illness-tracker/src/app/api/entries/symptoms/route.ts)), and the entry models carry no natural
key — the only `@@unique` constraints in the schema are on dose events
(`[regimenItemId, scheduledDate, scheduledTime]`), tag names, and tag joins.

So a double-tapped save, or a retry after a flaky mobile connection, creates a duplicate
symptom, sleep, food, or energy entry.

Worth separating from the generic version of this finding: for most apps a duplicate row is
noise. CIT's entire purpose is **correlation analysis over the logged data** — a duplicated
symptom entry doesn't just clutter a list, it silently weights that day's data and skews the
output the user is making decisions from. The dose-event model shows the pattern that works;
extending a natural key (or an idempotency token) to entries would follow it.

## C3 — `SESS-05`: 24-hour absolute, no idle timeout

[src/lib/auth/session.ts:8](../../repos/chronic-illness-tracker/src/lib/auth/session.ts) sets `SESSION_TTL_MS = 24 hours`, applied at creation with no
sliding refresh — so it is a true absolute bound, not a rolling one. There is no inactivity
timeout.

Against the verified NIST SP 800-63B-4 figures, 24 hours sits **exactly at the AAL2 overall
ceiling** ("SHOULD be no more than 24 hours at AAL2"), which is a defensible place to land. The
gap is the inactivity side: AAL2 says that SHOULD be no more than 1 hour, and there is none.

As with KindredAccess, this is a decision rather than an automatic defect, and the ordering
matters: an idle timeout added *before* C1 is fixed converts an inactivity policy into a
data-loss policy, because there is nothing to restore a discarded entry from.

## C4 — `CONC-01`: no optimistic locking (low impact here)

No version-checked writes. The `version` field on `RegimenItem`
([prisma/schema.prisma:182](../../repos/chronic-illness-tracker/prisma/schema.prisma)) is content history — the deliberate "never edit historical
doses silently" rule — not concurrency control.

Impact is genuinely low: single-user data, so the contention case is one person on two devices
(phone in the morning, laptop in the evening) rather than two workers on one record. Real, but
rare, and last-write-wins on a preference or a note is survivable in a way it isn't for
caseload data. Recorded for completeness rather than as something to fix now.

## C5 — `AUDIT-*`: no audit model, and mostly that's fine

There is no audit or access-log model in `prisma/schema.prisma`. Unlike KindredAccess, where
the same absence is a blocker, here it is largely **not applicable**: with no admin surface and
no third-party data, the only reader of a user's data is that user, so "who viewed this record"
has one possible answer.

What is missing and would matter is narrower: **authentication-event history**. Login,
password change, export, and session termination are the events an account-compromise
investigation needs, and the events a user might reasonably want to see themselves ("was that
export me?"). That is a much smaller build than an audit subsystem, and it is the part of
`AUDIT-01` that survives CIT's architecture.

---

## Not run

`SESS-01`/`02`/`03` (draft survival — untestable statically and directly downstream of C1),
`SESS-04`, `TEN-02` (cache cross-serve), `TEN-07` (small-cell suppression — CIT has no
aggregate release path, so likely N/A, but unverified), all of `MOB` (CIT has native clients
and Bearer-auth-through-proxy, so this deserves a pass), all of `A11Y`, and `ERR-01`/`02`.

Suggested order: **C1 first** — it is the only finding that loses user data, it is the cheapest
to fix, and it gates C3. Then C2, which shares a shape with the dose-event model already in the
schema. C5's narrow version (auth-event log) after that. C4 is a note, not a task.
