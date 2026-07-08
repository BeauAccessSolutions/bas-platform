# ADR-003: Pairwise subject identifiers (per-app pseudonymous user IDs)

**Status:** Accepted
**Date:** 2026-07-07
**Deciders:** Beau Access Solutions LLC
**Related:** [ADR-001](001-platform-architecture-and-identity.md), [INVARIANTS.md](../../INVARIANTS.md) #3

## Context

Shared identity means one human authenticates once and uses many apps, and the IdP
holds the mapping from that human to every app they use. Invariant #3 keys each app's
data by the OIDC `sub`. If `sub` is the **same value** across apps (OIDC `public`
subject type — Keycloak's default), then:

- The IdP database becomes a map linking one person to the chronic-illness app **and**
  the dating app (KindredAccess) **and** the veteran-benefits app — a uniquely
  sensitive correlation for *this* portfolio.
- Any token or datastore leak lets two apps (or an attacker joining them) confirm the
  same human is in both — even though invariant #3 keeps the *data* siloed.

For a portfolio spanning health, dating, and benefits, "the same person is in these
apps" is itself health- and status-revealing metadata. Siloing data is not enough if
the identifier that keys it is shared.

## Decision

Issue **pairwise pseudonymous subject identifiers**: each OIDC client receives a
*different*, stable `sub` for the same user (`subject_type=pairwise`, OIDC Core §8;
Keycloak supports this per-client via a sector identifier). KindredAccess and CIT each
see an opaque, app-specific user id; neither the token nor a cross-app join reveals
they are the same person.

The IdP still holds the master mapping — it must, to authenticate — but that
correlation now lives in exactly **one** hardened place instead of being
reconstructable from any two apps' tokens or datastores. Cross-app features that
legitimately need "same user" (none today) must go through explicit, consented,
IdP-mediated linkage — never by comparing `sub`s.

## Consequences

**Positive**
- No two apps can correlate a shared user from tokens or data alone; correlation is
  confined to the IdP.
- The technical design now matches the privacy-first ethos and each app's
  non-negotiables, rather than quietly undercutting them.

**Negative / costs accepted**
- `sub` is app-specific: every app keys its user records on **its own** pairwise `sub`.
  This is exactly why the call is made now — retrofitting after apps have stored a
  shared `sub` is a data migration.
- Any future cross-app feature needs deliberate linkage plumbing; it cannot free-ride
  on a shared id. (That is the point.)

**Follow-ups**
- Set `subject_type=pairwise` (+ sector identifier as needed) when defining OIDC
  clients in Phase 1.
- The existing-user migration ([ADR-004](004-existing-user-migration.md)) must record
  the pairwise `sub` per user at cutover.
