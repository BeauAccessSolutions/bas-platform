# Keycloak prod stand-up — execution checklist

Status: **ready to execute — waiting on infra inputs** · Last updated: 2026-07-08

The mechanics live in two places; this file is the **ordered, check-offable
sequence** that ties them together and names the human inputs so someone can actually
run it:

- [keycloak-digitalocean.md](keycloak-digitalocean.md) — the DO-specific mechanics.
- [../keycloak-setup-and-hardening.md](../keycloak-setup-and-hardening.md) — the security bar (§ refs below).
- [../../identity/prod/README.md](../../identity/prod/README.md) — realm-as-code (secrets + bootstrap).

## Readiness snapshot

| Piece | State |
|---|---|
| DO deploy runbook (Droplet + Caddy + managed PG) | ✅ written |
| Realm-as-code — parameterized bootstrap + `gen-secrets.sh` | ✅ on `feat/prod-realm-as-code` |
| Hardening checklist | ✅ drafted (§1–§9), ⬜ not executed |
| Local dev validation of the bootstrap (KC 26) | ✅ **run 2026-07-08** — caught + fixed a silent `cit-web` pairwise-sub bug (see step 0) |
| DO account / `doctl` auth | ⬜ **human** |
| Domain + `id.` DNS control | ⬜ **human** |
| Someone to run it + hold the admin credential | ⬜ **human** |

## Inputs you must supply before starting

- [ ] **Domain** — runbook assumes `id.beauaccesssolutions.com`. Confirm or change everywhere.
- [ ] **DO access** — `doctl` authenticated to the right team; SSH key id; billing OK for ~$21/mo (Droplet `s-1vcpu-2gb` ~$12 + managed PG `db-s-1vcpu-1gb` ~$7 + a bit).
- [ ] **Your admin IP** — for the SSH-only firewall rule (step 3).
- [ ] **Admin identity** — who owns the break-glass Keycloak admin account (2FA-gated after first boot).

## Execution order

**0. Validate the realm-as-code locally first** (de-risks prod; also closes the open
Phase-2 item "test against local dev Keycloak"):
```sh
docker compose -f identity/dev/docker-compose.yml up -d
docker compose -f identity/dev/docker-compose.yml exec keycloak \
  bash /opt/keycloak/data/import/bootstrap.sh   # dev placeholders (no CIT_SECTOR_URI)
```
Confirm the `bas` realm, `cit-web` + `kindredaccess-web` clients, pairwise `sub`, and
audience mappers come out right on KC 26.

> **Done 2026-07-08 — and it caught a real bug.** `cit-web`'s pairwise-sub mapper was
> failing silently (masked by `|| echo "may already exist"`): its web + native redirect
> URIs span multiple hosts, so Keycloak rejects the pairwise mapper unless a **Sector
> Identifier URI** is configured — leaving `cit-web` with a **non-pairwise, correlatable
> `sub`** (ADR-003 breach). Fixed in `bootstrap.sh`: `CIT_SECTOR_URI` support + an
> end-of-run **guard** that aborts (prod) or warns (dev) if any client lacks its pairwise
> mapper. Net new prod step: **host the sector-identifier document** (step 3). In dev the
> guard now warns and continues; a full pairwise `cit-web` in dev needs `CIT_SECTOR_URI`
> pointed at a reachable doc.

**1. Provision** ([runbook steps 1–3](keycloak-digitalocean.md)):
- [ ] Managed Postgres dedicated to Keycloak (not CIT's DB); note host/port `25060`/db/user/pw/CA.
- [ ] Droplet (`docker-20-04`, `s-1vcpu-2gb`, nyc1); add it to the DB's trusted sources.
- [ ] Point `id.` `A` record at the Droplet IP.
- [ ] Cloud Firewall: inbound 443 from anywhere, 22 from your IP only (**not** 8080).

**2. Boot Keycloak behind Caddy** ([runbook steps 4–5](keycloak-digitalocean.md)):
- [ ] Host `.env` (chmod 600) with PG creds + first-boot admin; `compose.yml` + `Caddyfile`.
- [ ] `docker compose up -d`; verify `/health/ready` and the master `.well-known` endpoint over HTTPS.

**3. Realm-as-code** ([prod README](../../identity/prod/README.md)):
- [ ] `identity/prod/gen-secrets.sh` → `secrets.env` (**once** — salts are permanent, ADR-003). Copy to host, chmod 600.
- [ ] **Host cit-web's sector-identifier document** at `https://id.<domain>/oidc/cit-web-sector.json`
  (JSON array of cit-web's web + native redirect URIs); export `CIT_SECTOR_URI` to it.
  **Required** — cit-web's multi-host redirects make Keycloak reject its pairwise-sub mapper
  without it, silently yielding a correlatable `sub` (ADR-003 breach). Verified against KC 26, 2026-07-08.
- [ ] `set -a; . secrets.env; set +a` + prod redirect URIs + `CIT_SECTOR_URI`, then run `identity/dev/realm/bootstrap.sh` against prod. Its end-of-run guard aborts if either client lacks its pairwise mapper.

**4. Harden the realm** ([hardening §2–§8](../keycloak-setup-and-hardening.md)):
- [ ] Replace/lock the bootstrap admin; restrict the admin path (SSH tunnel / allowlist).
- [ ] Brute-force detection; token TTLs + RS256 + signing-key rotation.
- [ ] 2FA + step-up (ACR/LoA) policy.
- [ ] WCAG 2.2 AA login theme (§6).
- [ ] Backups: PG backup/restore + signing-key rotation runbook (§8).

**5. Migrate existing users** (ADR-004) — **before** flipping each app's OIDC env:
- [ ] Per app: export → `kcadm partialImport` → smoke-test one migrated login → enable OIDC.

**6. Wire the apps**:
- [ ] **CIT** — `KEYCLOAK_ISSUER=https://id.<domain>/realms/bas`, `KEYCLOAK_CLIENT_ID=cit-web`.
- [ ] **KindredAccess** — same issuer, `OIDC_RP_CLIENT_ID=kindredaccess-web`, `OIDC_RP_CLIENT_SECRET=$KA_CLIENT_SECRET`.

## Exit criterion

`https://id.<domain>` serves a hardened Keycloak; the `bas` realm + `cit-web` +
`kindredaccess-web` clients exist; JWKS
(`/realms/bas/protocol/openid-connect/certs`) is reachable. CIT's
`KEYCLOAK_ISSUER` can point at `…/realms/bas`.

## Follow-ups (not blocking the stand-up)

- [x] **`benefits-navigator-web` client scaffolded in the realm-as-code** (2026-07-16) —
  confidential + PKCE, pairwise `sub`, audience, in `bootstrap.sh` as an inert stub (gated on
  `BN_REDIRECT_WEB`); `BN_PAIRWISE_SALT` + `BN_CLIENT_SECRET` added to `gen-secrets.sh`.
- [ ] **Wire BN as an OIDC RP** — the remaining, larger piece: BN is `django-allauth`, not
  yet on the IdP. Full scope (recommended approach, 3 product decisions, app changes,
  migration) in [benefits-navigator-oidc-integration.md](benefits-navigator-oidc-integration.md).
