# Access Atlas — pass against the blocker suite

Date: 2026-07-23 · Matrix: [`multi-role-test-matrix.yaml`](multi-role-test-matrix.yaml) v1
Target: `repos/access-directory` @ `5cb43f1` (`main`)

Static read, not a live run. Tests needing a running instance, a device, or a screen reader
were **not executed** and are listed as not-run rather than passed.

This is the cleanest result of the four apps audited, and the interesting part of the write-up
is the passes rather than the findings. Access Atlas independently arrived at several of the
properties the matrix tests for, and in two places implements them **more strongly** than the
fix I just wrote for KindredAccess.

---

## Summary

| Test | Gate | Result |
|---|---|---|
| `AUDIT-02` logs append-only | blocker | **PASS — at the database level** |
| `AUDIT-03` elevated actions logged | blocker | **PASS** |
| `TEN-06` storage paths / redaction | blocker | **PASS** |
| `REV-01` double-submit → one record | blocker | **PASS** — by natural key |
| `SESS-06`/`08` revocation | blocker | **PASS** |
| `SESS-05` idle/absolute timeout | required | **PARTIAL — A1** |
| `AUTHZ-05`…`09` dual-hat, impersonation | blocker | **N/A** — moderation is service-role, not a web role |
| `DELEG-*` | blocker | **N/A** — no proxy model |
| `NAV-01`…`03` | required | **mostly N/A** — browsing surface ships zero JS |

---

## What passes, and why it's worth recording

**`AUDIT-02` is enforced by the database, not by the application.** `moderation_audit`
([supabase/migrations/0008_moderation_audit.sql](../../repos/access-directory/supabase/migrations/0008_moderation_audit.sql)) grants the service role `INSERT` and
`SELECT` and deliberately **not** `UPDATE` or `DELETE`, with RLS denying public reads. That is
a stronger guarantee than the append-only model I added to KindredAccess this week, which
enforces the same property at the ORM layer and says so in its docstring. If that KA work is
ever hardened to the database level, this migration is the reference.

**The audit rows are designed to outlive what they describe.** Two decisions, both reasoned in
the migration header rather than discovered by reading the schema:

- Content ids are plain uuids, **not foreign keys**, because a confirmation-level takedown
  deletes the confirmation and an FK cascade would erase the evidence that the takedown
  happened. That is the failure mode `AUDIT-02` exists to prevent, anticipated and closed.
- No `contributor_id` is stored at all. The trail is about the content moderated, never about
  whom, so it can survive a contributor's deletion request without holding personal data
  hostage — a genuinely hard tension between audit and erasure, resolved deliberately.

**`TEN-06` — redaction order is right.** `redactEvidencePhoto`
([src/lib/moderation.ts](../../repos/access-directory/src/lib/moderation.ts)) removes **both** storage objects (full and thumbnail)
*first*, then nulls the URL, then appends the audit row only on a redaction that actually
completed. The common version of this bug is nulling the database reference while the object
stays fetchable by URL, leaving the takedown cosmetic. Not here.

**`REV-01` passes by natural key with the race path handled explicitly.** `unique
(listing_id, attribute_def_id)` on claims and `unique (claim_id, contributor_id)` on
confirmations mean a double-submit cannot create a second row; and
[src/pages/api/confirmations.ts:135](../../repos/access-directory/src/pages/api/confirmations.ts) catches the `23505` unique violation so the loser of a
first-report race re-reads the winner's claim rather than erroring. Storage uploads pass
`upsert: false`. Natural keys are a legitimate alternative to idempotency tokens, and this is
the careful version of it.

**The two `security_definer_view` advisories are documented decisions, not oversights.** The
platform tracker flags Supabase lints on `attribute_claim_status` and `evidence_photos`. Reading
[0007_evidence_photos.sql](../../repos/access-directory/supabase/migrations/0007_evidence_photos.sql), the `SECURITY DEFINER` is deliberate and its reasoning is
recorded inline: the photo objects are already public-read by URL and EXIF-stripped, so the view
exposes nothing the bucket does not. That is a risk acceptance with a rationale attached, which
is what the matrix asks for. Worth suppressing the lint with a comment so it stops reading as an
open item.

---

## A1 — `SESS-05`: 30-day sessions, no idle timeout

[src/lib/auth/session.ts:17](../../repos/access-directory/src/lib/auth/session.ts)

```ts
export const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
```

No inactivity timeout. Sessions carry a `revoked_at` column checked on every validation, so
revocation works immediately (`SESS-06`/`SESS-08` pass) — the finding is only about duration.

Thirty days sits **exactly at the AAL1 ceiling** ("SHOULD be no more than 30 days at AAL1"),
where AAL1 does not require an inactivity timeout at all. For a public directory whose
contributor account exists to attach confirmations to listings, AAL1 is a defensible reading and
this is compliant.

The thing that complicates it is the **access-identity tag**: a contributor can mark themselves
as disabled, and that self-identification is the app's whole representation axis. Disability
disclosure is sensitive personal data even when the surrounding content is public. Whether that
pulls the contributor session to AAL2 is a judgment call, and it is the same judgment as
KindredAccess's F3 — which is the cross-app point below.

## A2 — outside the matrix: no rate limiting on public write endpoints

Flagging because it surfaced, and labelling it clearly: **this is not a matrix finding.** A
search for rate limiting or throttling across `src/lib/security.ts` and `src/pages/api/` returns
nothing. The public contribution endpoints (`confirmations.ts`, `listings.ts`,
`photo-reports.ts`) accept writes with no per-IP or per-contributor limit that I could find.

The matrix does not test for this — `REV-01` covers accidental duplicates, not deliberate abuse
— and abuse resistance may well be handled at the edge or judged unnecessary at current volume.
Recorded so it is a decision rather than an omission. KindredAccess's `MessageRateLimiter` is
the in-portfolio precedent if it is wanted.

---

## The cross-app finding: P1 cannot be one number

Four apps have now been audited against parameter **P1** (session timeouts), and each has a
different defensible answer:

| App | Current | Shape |
|---|---|---|
| Benefits Navigator | — | caseload worker tool, third-party PHI → AAL2, the proposed 15m/12h fits |
| KindredAccess | 2 weeks | consumer social; a 15-minute timeout would be hostile, and users with cognitive or motor disabilities pay the re-auth cost |
| Chronic Illness Tracker | 24h absolute | personal PHI, single user, no third-party data |
| Access Atlas | 30 days | public directory contributor account |

The matrix currently proposes P1 as a single portfolio value. That is wrong, and this pass is
what shows it: **P1 has to be per-app, chosen from the app's assurance level, with the
portfolio-level rule being the *method* rather than the number.** The rule that does generalize
is the dependency the matrix already states — a short timeout is only humane once drafts survive
it, so the timeout question is downstream of the data-loss question in every app.

I have not edited the matrix for this; it is a change to a parameter that is still `proposed`
and belongs in the same decision pass that adopts P1.

---

## Not run

All of `A11Y` (this repo has the portfolio's strongest a11y suite — 77 passing tests plus a
contrast gate — so it is the least likely to hold surprises, but it was not exercised here), all
of `MOB` (the Capacitor wrapper and the native camera flow are new and deserve their own pass —
`MOB-02` hardware-backed key storage in particular), `TEN-02` (cache cross-serve), `TEN-07`
(small-cell suppression — the directory publishes aggregate counts by attribute, so this is the
one genuinely unexamined risk here), and `ERR-01`.

`TEN-07` is the one I would look at next: a listing page showing "confirmed by 2 disabled
visitors" in a small geography is exactly the shape the small-cell rule exists for, and P2's
threshold of 11 was chosen for release datasets rather than for a directory that displays counts
by design. That is a parameter question as much as a code question.
