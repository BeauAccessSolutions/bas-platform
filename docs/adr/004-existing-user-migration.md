# ADR-004: Migrating existing per-app users into Keycloak

**Status:** Accepted (approach) — execution is per-app, Phase 2 onward
**Date:** 2026-07-07
**Deciders:** Beau Access Solutions LLC
**Related:** [ADR-001](001-platform-architecture-and-identity.md), [ADR-003](003-pairwise-subject-identifiers.md)

## Context

CIT, KindredAccess, and Benefits Navigator each already have real users with
credentials in their own backends. Adopting shared Keycloak identity means those humans
must exist in Keycloak **without** a mass password reset and without losing accounts.
Nothing in the platform docs covered this — it is a real workstream, not a footnote.
Two sub-problems: (a) getting credentials into Keycloak, and (b) linking each legacy
per-app account to the Keycloak identity and, per [ADR-003](003-pairwise-subject-identifiers.md),
to the app-specific pairwise `sub` it will receive from then on.

## Decision

1. **Password migration is on-login (lazy), not a mass reset.** Import each app's users
   into Keycloak and migrate credentials on first successful login (Keycloak's
   migrate-on-login, or a custom hash provider where the legacy algorithm is
   representable). The user's next login re-hashes into Keycloak's format; dormant
   accounts are cleaned up later. No forced reset, no plaintext handling. Where a legacy
   hash cannot be represented at all, those users — and only those — get a one-time
   verified reset.
2. **Account linking uses verified email as the join key**, per app, at cutover. Each
   app maps its legacy `user_id` → Keycloak user (looked up / created by **verified**
   email) → the app-specific pairwise `sub` (ADR-003) it will store henceforth.
3. **Cross-app linking is not automatic.** The same email in two apps does **not**
   auto-merge into one visibly-linked account; each app links independently. Deliberate,
   consented account-linking is a separate future feature and must respect ADR-003.
4. **CIT (app #1) is the reference migration.** Its runbook becomes the template for
   KindredAccess and Benefits Navigator.

## Consequences

**Positive**
- Existing users keep their accounts and passwords; no security-hostile mass reset.
- Migration is app-scoped, feature-flaggable, and reversible per app.

**Negative / costs accepted**
- Each app needs a one-time migration script and a **verified-email precondition** —
  apps with unverified emails must run verification first.
- Legacy password-hash representability must be checked per app; exceptions fall back to
  reset.
- Cutover is a coordinated step (the `requireAuth()` auth swap is flag-gated behind the
  completed migration).

**Follow-ups**
- Per-app migration runbook, CIT first; track in [TRACKER.md](../../TRACKER.md).
- Confirm each app's stored hash algorithm is Keycloak-representable; list exceptions.
- Ensure emails are verified before they are used as the linking key.
