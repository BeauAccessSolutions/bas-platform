# Phase 0 execution — scope & sequencing

Status: **scoping** · Last updated: 2026-07-07
Anchors: [PLATFORM.md](../PLATFORM.md) · [keycloak-setup-and-hardening.md](keycloak-setup-and-hardening.md) ·
[ADR-001](adr/001-platform-architecture-and-identity.md)

Phase 0 = the foundation that makes everything else possible: **a reachable identity
service + a reachable CIT backend**, plus the scaffolding the shared frontend will need.
Nothing in Phase 1+ can start until the identity service and CIT backend exist and can
exchange tokens.

The honest split: some of this is code/config I can scaffold now; some needs **you**
(hosting accounts, domains, secrets) because it touches money and infrastructure.

---

## Workstreams

### A. Identity — local dev Keycloak  ·  *I can do now*
A runnable Keycloak + Postgres on your machine (Docker) so we can build and test the
OIDC contract + CIT login-path swap **before** paying for any hosting.
- ✅ `identity/dev/docker-compose.yml` + README (this commit).
- ⬜ Create realm `bas` + `cit-web` client (PKCE, pairwise `sub`, audience) per hardening §3.
- ⬜ Once validated, **export the realm to `identity/dev/realm/` and commit it** (realm-as-code).
- Blocker for you: just install Docker if you don't have it; then `docker compose up`.

### B. Identity — production Keycloak  ·  *needs you (infra) + me (config)*
- ✅ **Runbook written:** [deploy/keycloak-digitalocean.md](deploy/keycloak-digitalocean.md) (Droplet + Docker + Caddy, or App Platform).
- ⬜ **Decision:** confirmed DO. Droplet recommended for admin-plane isolation (hardening §2).
- ⬜ Domain: `id.beauaccesssolutions.com` (subdomain of the marketing domain), TLS.
- ⬜ Execute the [hardening checklist](keycloak-setup-and-hardening.md) §1–§9.
- ⬜ Apply the validated realm-as-code from workstream A.

### C. CIT backend deploy  ·  *needs you (infra) + me (spec/runbook)*
- ✅ **Runbook written:** [deploy/cit-backend-digitalocean.md](deploy/cit-backend-digitalocean.md) (App Platform from `.do/app.yaml`).
- CIT is local-only today; the deploy spec already exists (CIT `.do/app.yaml`).
- ⬜ You: create the DO app from the spec, set real secrets (`DATABASE_URL`, CA cert,
      `ANTHROPIC_API_KEY` if enabling AI). I can write a step-by-step deploy runbook +
      verify the spec first.
- ⬜ Confirm `/api/health`, export signed-URL flow, and TLS-to-DB on the deployed host.

### D. Monorepo + Expo skeleton  ·  *I can scaffold — but sequence it after A/B/C*
- Roadmap lists it in Phase 0, but it has **no value until identity + backend are
  reachable**. Recommend deferring the heavy scaffold until the OIDC contract works
  locally (A), to avoid building UI plumbing against a moving target.
- ⬜ When ready: pnpm + Turborepo, `packages/{ui,auth,api-client,config}`, Expo app shell.

### E. CI gates  ·  *I can scaffold with D*
- ⬜ ESLint **import-boundary** rule (analytics → sensitive route = build failure, invariant #2).
- ⬜ **axe** a11y gate in CI. Lives in `packages/config`, consumed by every app.

---

## Owner split (at a glance)

| Can do now (me) | Needs you (accounts/infra/$) | Joint |
|---|---|---|
| Local dev Keycloak compose (A) | Prod Keycloak host + domain (B) | Validate realm config (A→B) |
| Deploy runbook + verify `.do/app.yaml` (C) | DO app + secrets for CIT (C) | Confirm health/TLS on deploy (C) |
| Monorepo/Expo scaffold when sequenced (D) | Apple $99 / Google $25 (later, Phase 4) | — |
| CI gate configs (E) | Docker installed locally (A) | — |

---

## Decisions needed from you

1. **Keycloak hosting** — DO Droplet vs DO App Platform vs elsewhere. Recommend DO (you
   already run CIT there) + DO managed Postgres, so it's one provider and one bill.
2. **IdP domain** — confirm `id.beauaccesssolutions.com` (needs a DNS record on the
   marketing domain).
3. **CIT deploy target** — confirm DO App Platform via the existing `.do/app.yaml`.
4. **When to scaffold the monorepo** — my recommendation is *after* the local OIDC
   contract works (A), not now.

## Recommended first two moves

1. **Me:** land the local dev Keycloak (this commit) → then wire the `cit-web` client and
   prove PKCE login → CIT `createSession()` against a local CIT. *(Note: relocate the
   identity config to a dedicated `bas-identity` repo per [ADR-002](adr/002-umbrella-org-and-repo-topology.md)
   before production — it lives in governance only as a temporary dev starting point.)*
2. **You:** pick the Keycloak host (Decision 1) + add the `id.` DNS record, and create the
   DO app for the CIT backend from `.do/app.yaml`.

**Phase 0 exit criterion:** a hardened Keycloak is reachable at `id.beauaccesssolutions.com`,
the CIT backend is deployed and healthy, and a real (non-local) Keycloak login mints a CIT
session end-to-end.
