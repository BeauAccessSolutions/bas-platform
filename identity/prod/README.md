# Prod realm-as-code (`bas`)

How to build the **production** `bas` realm reproducibly, with real per-client secrets.

## Why there's no committed `bas-realm.json` here

A realm export embeds secrets — the pairwise-sub **salts** (ADR-003) and each
confidential client's **secret**. Committing those is a secrets-in-git antipattern, and
the salts are **permanent** (rotating one changes every user's `sub` and orphans every
app's stored identity rows). So the realm-as-code here is:

1. the **shared bootstrap script** ([`../dev/realm/bootstrap.sh`](../dev/realm/bootstrap.sh)) — now parameterised so salts, redirect URIs, and the KA client secret come from env, and
2. a **secret generator** ([`gen-secrets.sh`](gen-secrets.sh)) whose output (`secrets.env`) stays on the host and is gitignored.

The one authoritative bootstrap runs for both dev (placeholder salts) and prod (real
salts from `secrets.env`) — no drift between a dev script and a prod JSON.

## Build the prod realm

Prereq: a hardened Keycloak reachable (see [`../../docs/deploy/keycloak-digitalocean.md`](../../docs/deploy/keycloak-digitalocean.md)) and its admin creds.

```sh
# 1. Generate secrets ONCE. Idempotent: refuses to overwrite (salts must stay stable).
./gen-secrets.sh                      # writes secrets.env (chmod 600, gitignored)

# 2. Host cit-web's SECTOR IDENTIFIER document (required — validated 2026-07-08 against
#    KC 26). cit-web serves web + native, so its redirect URIs span multiple hosts, and
#    Keycloak's pairwise-sub mapper then REQUIRES a reachable HTTPS doc listing them as a
#    JSON array. Keycloak fetches + validates it at mapper-create time; without it the
#    pairwise mapper is rejected and cit-web silently gets a NON-pairwise (correlatable)
#    sub — an ADR-003 breach. Publish this JSON at a stable URL you control, e.g.
#    https://id.<domain>/oidc/cit-web-sector.json :
#      ["https://<cit-host>/api/auth/session*","com.beauaccesssolutions.cit://oauth*"]
#    (the exact strings must match CIT_REDIRECT_WEB + the native redirect below.)

# 3. Copy secrets.env to the Keycloak host, then load it + prod parameters:
set -a
. secrets.env                         # CIT_PAIRWISE_SALT, KA_PAIRWISE_SALT, KA_CLIENT_SECRET
KC_ADMIN=<admin> KC_ADMIN_PASSWORD=<pw>
CIT_REDIRECT_WEB='https://<cit-host>/api/auth/session*'
CIT_SECTOR_URI='https://id.<domain>/oidc/cit-web-sector.json'   # from step 2 — REQUIRED
KA_REDIRECT_WEB='https://kindredaccess.org/oidc/callback/*'
KA_POST_LOGOUT='https://kindredaccess.org/*'
set +a

# 4. Run the shared bootstrap against prod (creates realm bas, both clients, pairwise +
#    audience mappers, optional first/last name profile). It sets the KA client secret
#    from KA_CLIENT_SECRET rather than auto-generating one. The script's end-of-run GUARD
#    aborts if either client is missing its pairwise-sub mapper — so a bad/unreachable
#    CIT_SECTOR_URI fails loudly here instead of shipping a correlatable sub.
bash ../dev/realm/bootstrap.sh

# 5. Finish hardening the realm — token TTLs / RS256 / rotation, 2FA + step-up, the
#    WCAG login theme, backups — per ../../docs/keycloak-setup-and-hardening.md §4–§8.
```

Then wire each app:

- **KindredAccess** — `KEYCLOAK_ISSUER=https://id.<domain>/realms/bas`,
  `OIDC_RP_CLIENT_ID=kindredaccess-web`, `OIDC_RP_CLIENT_SECRET=$KA_CLIENT_SECRET`.
- **CIT** — `KEYCLOAK_ISSUER=…/realms/bas`, `KEYCLOAK_CLIENT_ID=cit-web`.

## Existing-user migration (ADR-004)

Do this **before** flipping an app's OIDC env vars on:

1. In the app, export users to a Keycloak partial-import file. For KindredAccess:
   `python manage.py export_keycloak_users --output ka_users.json`
   (only verified-email accounts; Django PBKDF2 hashes import natively — no reset).
2. Import: `kcadm.sh create partialImport -r bas -f ka_users.json`.
3. Smoke-test one migrated login end-to-end, then enable OIDC on that app.

`export_keycloak_users` reports accounts needing a one-time verified reset (unverified /
duplicate email / non-PBKDF2 hash).

## Exporting a realm snapshot (optional, secrets-stripped)

If you want a JSON snapshot for review/DR, export then **strip the salts and client
secret** before it leaves the host — or keep it only on the host (gitignored here as
`bas-realm.json`):

```sh
kc.sh export --realm bas --file bas-realm.json     # contains secrets — do not commit
```
