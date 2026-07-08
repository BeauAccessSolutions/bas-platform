# Local dev Keycloak

A throwaway Keycloak + Postgres for building and testing the OIDC contract and CIT's
login-path swap **before** any hosting exists. Not production.

> Per [ADR-002](../../docs/adr/002-umbrella-org-and-repo-topology.md), the identity
> service gets its **own repo** (`bas-identity`) before production. This lives in the
> governance repo only as a temporary local starting point — relocate it when standing
> up prod.

## Run it

```sh
docker compose -f identity/dev/docker-compose.yml up
```

- Admin console: <http://localhost:8080> — `admin` / `admin` (throwaway).
- Stop + wipe: `docker compose -f identity/dev/docker-compose.yml down -v`.

## Configure the CIT client (dev)

Fastest path: run the reference bootstrap (`realm/bootstrap.sh`) against the running
container, then tweak in the admin console. It creates the `bas` realm + `cit-web`
client with PKCE, pairwise `sub`, and audience scoping. It's a *reference* — validate
mapper names against the pinned KC version, then export (below) as the source of truth.

Or do it by hand — follow [hardening §3](../../docs/keycloak-setup-and-hardening.md), the dev values:

1. **Realm:** create `bas`.
2. **Client `cit-web`** (public, for the Next.js/Expo client):
   - Standard flow (Authorization Code) **on**; Implicit + Direct Access Grants **off**.
   - **PKCE required** (`S256`).
   - Redirect URIs (exact): `http://localhost:3000/api/auth/session*` (web) and the
     Expo AppAuth custom-scheme URI (native).
   - **Subject type = `pairwise`** with a sector identifier (ADR-003) so CIT gets its
     own uncorrelatable `sub`.
   - Audience: ensure `aud`/`azp` = `cit-web` so CIT's verifier can reject foreign tokens.
3. **A test user** with a password (and, to exercise step-up later, an OTP).

## Make it reproducible (realm-as-code)

Once the realm + client work, export and commit so it's not click-ops:

```sh
# from inside the running keycloak container
/opt/keycloak/bin/kc.sh export --dir /opt/keycloak/data/import --realm bas
```

Commit the result to `identity/dev/realm/` — `--import-realm` (already wired in the
compose) will recreate it on the next `up`. This exported realm is the seed for the
production config in [hardening §3](../../docs/keycloak-setup-and-hardening.md).

## Next

Point a local CIT dev build at this Keycloak and implement CIT
`docs/mobile/auth-token-exchange.md` §3 — the `/api/auth/session` endpoint that verifies
the OIDC token and calls `createSession()`.
